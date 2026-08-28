#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "esp_arduino_version.h"
#include "esp_chip_info.h"
#include "esp_system.h"

// --------------------------- Pin configuration ---------------------------
constexpr uint8_t I2C_SDA_PIN = 8;
constexpr uint8_t I2C_SCL_PIN = 9;

constexpr uint8_t LED_PINS[] = {4, 5, 6, 7, 10, 11};
constexpr const char *LED_NAMES[] = {
    "LED 1", "LED 2", "LED 3", "LED 4", "LED 5", "LED 6"};
constexpr size_t LED_CHANNEL_COUNT = sizeof(LED_PINS) / sizeof(LED_PINS[0]);

// Each LED is wired GPIO -> 220 ohm -> anode, with its cathode connected to GND.
constexpr uint8_t LED_ON = HIGH;
constexpr uint8_t LED_OFF = LOW;
// -------------------------------------------------------------------------

constexpr int SCREEN_WIDTH = 128;
constexpr int SCREEN_HEIGHT = 64;
constexpr int OLED_RESET = -1;
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

bool oledReady = false;
uint8_t oledAddress = 0;

void setLed(size_t index, bool on) {
  digitalWrite(LED_PINS[index], on ? LED_ON : LED_OFF);
}

void allLedsOff() {
  for (size_t i = 0; i < LED_CHANNEL_COUNT; ++i) {
    setLed(i, false);
  }
}

void allLedsOn() {
  for (size_t i = 0; i < LED_CHANNEL_COUNT; ++i) {
    setLed(i, true);
  }
}

void showStatus(const char *line1, const char *line2 = nullptr,
                const char *line3 = nullptr) {
  if (!oledReady) {
    return;
  }

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("ESP32 TEST");
  display.println();
  display.println(line1);
  if (line2) display.println(line2);
  if (line3) display.println(line3);
  display.display();
}

void printDiagnostics() {
  esp_chip_info_t chipInfo;
  esp_chip_info(&chipInfo);

  Serial.println();
  Serial.println("=== ESP32-S3 hardware bring-up ===");
  Serial.printf("Chip: %s, revision %d, %d core(s)\n", ESP.getChipModel(),
                chipInfo.revision, chipInfo.cores);
  Serial.printf("CPU: %u MHz\n", ESP.getCpuFreqMHz());
  Serial.printf("Flash: %u bytes\n", ESP.getFlashChipSize());
  Serial.printf("PSRAM: %u bytes%s\n", ESP.getPsramSize(),
                psramFound() ? " (detected)" : " (NOT detected)");
  Serial.printf("Arduino core: %d.%d.%d\n", ESP_ARDUINO_VERSION_MAJOR,
                ESP_ARDUINO_VERSION_MINOR, ESP_ARDUINO_VERSION_PATCH);
  Serial.printf("Reset reason: %d\n", static_cast<int>(esp_reset_reason()));
  Serial.printf("I2C: SDA GPIO %u, SCL GPIO %u\n", I2C_SDA_PIN, I2C_SCL_PIN);
  if (!psramFound()) {
    Serial.println("WARNING: N8R2 PSRAM was not detected; check board settings.");
  }
}

uint8_t scanI2c() {
  Serial.println("\nScanning I2C bus...");
  uint8_t deviceCount = 0;
  bool found3c = false;
  bool found3d = false;

  for (uint8_t address = 1; address < 127; ++address) {
    Wire.beginTransmission(address);
    const uint8_t error = Wire.endTransmission();
    if (error == 0) {
      Serial.printf("  Found I2C device at 0x%02X\n", address);
      ++deviceCount;
      found3c |= address == 0x3C;
      found3d |= address == 0x3D;
    } else if (error == 4) {
      Serial.printf("  Unknown I2C error at 0x%02X\n", address);
    }
  }

  if (deviceCount == 0) {
    Serial.println("ERROR: No I2C devices found.");
  } else {
    Serial.printf("I2C scan complete: %u device(s) found.\n", deviceCount);
  }

  // SSD1306 modules normally use 0x3C or 0x3D. Prefer 0x3C when both answer.
  if (found3c) return 0x3C;
  if (found3d) return 0x3D;

  Serial.println("ERROR: No OLED found at supported address 0x3C or 0x3D.");
  return 0;
}

bool testOled(uint8_t address) {
  if (address == 0) {
    Serial.println("Skipping OLED initialization; LED tests will continue.");
    return false;
  }

  Serial.printf("Initializing 128x64 SSD1306 at 0x%02X...\n", address);
  // Wire was already started on GPIO8/GPIO9; do not let the library restart it.
  if (!display.begin(SSD1306_SWITCHCAPVCC, address, true, false)) {
    Serial.println("ERROR: SSD1306 initialization failed; LED tests will continue.");
    return false;
  }

  oledReady = true;
  oledAddress = address;
  char addressLine[16];
  snprintf(addressLine, sizeof(addressLine), "I2C: 0x%02X", oledAddress);
  showStatus("OLED: OK", addressLine, "Starting tests");
  Serial.println("OLED: OK");
  delay(1200);
  return true;
}

void indicateOledFailure() {
  Serial.println("Visible OLED failure indication: blinking all LEDs 3 times.");
  for (int pulse = 0; pulse < 3; ++pulse) {
    allLedsOn();
    delay(180);
    allLedsOff();
    delay(180);
  }
}

void showLedTest(size_t index) {
  char gpioLine[20];
  snprintf(gpioLine, sizeof(gpioLine), "GPIO %u", LED_PINS[index]);
  showStatus("Testing", LED_NAMES[index], gpioLine);
}

void testIndividualLeds() {
  Serial.println("\nTesting individual LEDs...");
  allLedsOff();

  for (size_t i = 0; i < LED_CHANNEL_COUNT; ++i) {
    Serial.printf("Testing %s - GPIO %u\n", LED_NAMES[i], LED_PINS[i]);
    showLedTest(i);
    setLed(i, true);
    delay(700);
    setLed(i, false);
    delay(200);
  }
}

void runChase(bool forward, uint32_t stepMs) {
  allLedsOff();
  for (size_t step = 0; step < LED_CHANNEL_COUNT; ++step) {
    const size_t index = forward ? step : LED_CHANNEL_COUNT - 1 - step;
    setLed(index, true);
    delay(stepMs);
    setLed(index, false);
  }
}

void testLedPatterns() {
  Serial.println("Forward chase: LED 1 -> LED 6");
  showStatus("Forward chase", "LED 1 -> LED 6");
  runChase(true, 300);

  Serial.println("Backward chase: LED 6 -> LED 1");
  showStatus("Backward chase", "LED 6 -> LED 1");
  runChase(false, 300);

  Serial.println("All LEDs on for 1 second");
  showStatus("All LEDs ON", "1 second");
  allLedsOn();
  delay(1000);
  allLedsOff();
  Serial.println("All LEDs off");
}

void showComplete() {
  if (!oledReady) return;
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("HARDWARE TEST");
  display.println("COMPLETE");
  display.display();
}

void setup() {
  // Establish the inactive output level before enabling each GPIO as an output.
  for (size_t i = 0; i < LED_CHANNEL_COUNT; ++i) {
    digitalWrite(LED_PINS[i], LED_OFF);
    pinMode(LED_PINS[i], OUTPUT);
  }
  allLedsOff();

  Serial.begin(115200);
  const uint32_t serialWaitStart = millis();
  while (!Serial && millis() - serialWaitStart < 2000) delay(10);
  printDiagnostics();

  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  Wire.setClock(100000);
  oledAddress = scanI2c();
  if (!testOled(oledAddress)) indicateOledFailure();

  testIndividualLeds();
  testLedPatterns();
  allLedsOff();

  Serial.println("\nHardware self-test complete.");
  showComplete();
  delay(1500);
  Serial.println("Starting continuous slow LED chase.");
}

void loop() {
  showStatus("Continuous chase", "Forward");
  runChase(true, 650);
  showStatus("Continuous chase", "Backward");
  runChase(false, 650);
}
