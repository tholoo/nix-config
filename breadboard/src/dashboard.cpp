#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// --------------------------- Pin configuration ---------------------------
constexpr uint8_t I2C_SDA_PIN = 8;
constexpr uint8_t I2C_SCL_PIN = 9;

constexpr uint8_t LED_GREEN_PIN = 4;       // A completed Codex task exists.
constexpr uint8_t LED_YELLOW_PIN = 5;      // A Codex task is working.
constexpr uint8_t LED_RED_PIN = 6;         // Task error, network loss, or host loss.
constexpr uint8_t LED_BLUE_PIN = 7;        // Codex needs user input/approval.
constexpr uint8_t LED_LINK_PIN = 10;       // Laptop bridge and network are online.
constexpr uint8_t LED_STROBE_PIN = 11;     // An alert has waited too long.

// Verified wiring: GPIO -> 220 ohm -> LED anode; LED cathode -> GND.
constexpr uint8_t LED_ON = HIGH;
constexpr uint8_t LED_OFF = LOW;
// -------------------------------------------------------------------------

constexpr int SCREEN_WIDTH = 128;
constexpr int SCREEN_HEIGHT = 64;
constexpr int OLED_RESET = -1;
constexpr size_t MAX_TASKS = 6;
constexpr size_t MAX_FIELD_LENGTH = 21;
constexpr size_t MAX_SERIAL_LINE = 160;
constexpr uint32_t HOST_TIMEOUT_MS = 15000;
constexpr uint32_t PAGE_INTERVAL_MS = 5000;
constexpr uint32_t ALERT_AFTER_SECONDS = 180;

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

enum class TaskState : uint8_t {
  Working,
  Complete,
  Input,
  Error,
  Unknown,
};

struct TaskItem {
  char project[MAX_FIELD_LENGTH + 1];
  char title[MAX_FIELD_LENGTH + 1];
  TaskState state;
  uint32_t elapsedSeconds;
  uint32_t stateAgeSeconds;
};

TaskItem tasks[MAX_TASKS];
TaskItem pendingTasks[MAX_TASKS];
size_t taskCount = 0;
size_t pendingTaskCount = 0;

bool oledReady = false;
bool receivingSnapshot = false;
bool linkSeen = false;
int8_t networkState = -1;        // -1 unknown, 0 offline, 1 online
int8_t pendingNetworkState = -1;
uint32_t lastHeartbeatMs = 0;
uint32_t networkOfflineSinceMs = 0;

char serialLine[MAX_SERIAL_LINE];
size_t serialLineLength = 0;

void setOutput(uint8_t pin, bool on) {
  digitalWrite(pin, on ? LED_ON : LED_OFF);
}

void allLedsOff() {
  setOutput(LED_GREEN_PIN, false);
  setOutput(LED_YELLOW_PIN, false);
  setOutput(LED_RED_PIN, false);
  setOutput(LED_BLUE_PIN, false);
  setOutput(LED_LINK_PIN, false);
  setOutput(LED_STROBE_PIN, false);
}

void copyField(char *destination, const char *source) {
  strncpy(destination, source ? source : "", MAX_FIELD_LENGTH);
  destination[MAX_FIELD_LENGTH] = '\0';
}

TaskState parseState(const char *value) {
  if (!strcmp(value, "W")) return TaskState::Working;
  if (!strcmp(value, "D")) return TaskState::Complete;
  if (!strcmp(value, "I")) return TaskState::Input;
  if (!strcmp(value, "E")) return TaskState::Error;
  return TaskState::Unknown;
}

const char *stateLabel(TaskState state) {
  switch (state) {
    case TaskState::Working: return "RUN";
    case TaskState::Complete: return "DONE";
    case TaskState::Input: return "INPUT";
    case TaskState::Error: return "ERROR";
    default: return "?";
  }
}

char *nextField(char *&cursor) {
  if (!cursor) return nullptr;
  char *field = cursor;
  char *separator = strchr(cursor, '|');
  if (separator) {
    *separator = '\0';
    cursor = separator + 1;
  } else {
    cursor = nullptr;
  }
  return field;
}

void addPendingTask(char *cursor) {
  if (pendingTaskCount >= MAX_TASKS) return;

  char *project = nextField(cursor);
  char *title = nextField(cursor);
  char *state = nextField(cursor);
  char *elapsed = nextField(cursor);
  char *stateAge = nextField(cursor);
  if (!project || !title || !state || !elapsed || !stateAge) return;

  TaskItem &task = pendingTasks[pendingTaskCount++];
  copyField(task.project, project);
  copyField(task.title, title);
  task.state = parseState(state);
  task.elapsedSeconds = strtoul(elapsed, nullptr, 10);
  task.stateAgeSeconds = strtoul(stateAge, nullptr, 10);
}

void commitSnapshot() {
  const int8_t previousNetworkState = networkState;
  taskCount = pendingTaskCount;
  for (size_t i = 0; i < taskCount; ++i) tasks[i] = pendingTasks[i];
  networkState = pendingNetworkState;
  receivingSnapshot = false;
  linkSeen = true;
  lastHeartbeatMs = millis();

  if (networkState == 0 && previousNetworkState != 0) {
    networkOfflineSinceMs = millis();
  } else if (networkState != 0) {
    networkOfflineSinceMs = 0;
  }

  Serial.printf("Dashboard snapshot: %u task(s), network=%s\n",
                static_cast<unsigned>(taskCount),
                networkState == 1 ? "online" :
                networkState == 0 ? "offline" : "unknown");
}

void processSerialLine(char *line) {
  if (!strcmp(line, "BEGIN")) {
    pendingTaskCount = 0;
    pendingNetworkState = -1;
    receivingSnapshot = true;
    return;
  }

  if (!strcmp(line, "PING")) {
    linkSeen = true;
    lastHeartbeatMs = millis();
    return;
  }

  if (!receivingSnapshot) return;

  if (!strncmp(line, "NET|", 4)) {
    pendingNetworkState = line[4] == '1' ? 1 : line[4] == '0' ? 0 : -1;
  } else if (!strncmp(line, "TASK|", 5)) {
    char *cursor = line + 5;
    addPendingTask(cursor);
  } else if (!strcmp(line, "END")) {
    commitSnapshot();
  }
}

void readSerialProtocol() {
  while (Serial.available()) {
    const char value = static_cast<char>(Serial.read());
    if (value == '\n') {
      serialLine[serialLineLength] = '\0';
      if (serialLineLength > 0) processSerialLine(serialLine);
      serialLineLength = 0;
    } else if (value != '\r' && serialLineLength < MAX_SERIAL_LINE - 1) {
      serialLine[serialLineLength++] = value;
    }
  }
}

uint8_t scanForOled() {
  Serial.println("Scanning I2C for SSD1306...");
  bool found3c = false;
  bool found3d = false;

  for (uint8_t address = 1; address < 127; ++address) {
    Wire.beginTransmission(address);
    if (Wire.endTransmission() == 0) {
      Serial.printf("  I2C device: 0x%02X\n", address);
      found3c |= address == 0x3C;
      found3d |= address == 0x3D;
    }
  }

  if (found3c) return 0x3C;
  if (found3d) return 0x3D;
  return 0;
}

void initializeOled() {
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  Wire.setClock(100000);
  const uint8_t address = scanForOled();
  if (!address) {
    Serial.println("ERROR: no OLED at 0x3C or 0x3D; LEDs remain active.");
    return;
  }

  if (!display.begin(SSD1306_SWITCHCAPVCC, address, true, false)) {
    Serial.println("ERROR: SSD1306 initialization failed; LEDs remain active.");
    return;
  }

  oledReady = true;
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("CODEX DASHBOARD");
  display.println();
  display.println("Waiting for bridge");
  display.display();
  Serial.printf("OLED ready at 0x%02X\n", address);
}

void formatDuration(uint32_t seconds, char *output, size_t outputSize) {
  if (seconds >= 3600) {
    snprintf(output, outputSize, "%luh%02lu",
             static_cast<unsigned long>(seconds / 3600),
             static_cast<unsigned long>((seconds / 60) % 60));
  } else if (seconds >= 60) {
    snprintf(output, outputSize, "%lum%02lu",
             static_cast<unsigned long>(seconds / 60),
             static_cast<unsigned long>(seconds % 60));
  } else {
    snprintf(output, outputSize, "%lus",
             static_cast<unsigned long>(seconds));
  }
}

void printAligned(const char *left, const char *right) {
  constexpr size_t columns = 21;
  char line[columns + 1];
  memset(line, ' ', columns);
  line[columns] = '\0';

  const size_t rightLength = min(strlen(right), columns);
  const size_t leftLimit = columns > rightLength ? columns - rightLength - 1 : 0;
  const size_t leftLength = min(strlen(left), leftLimit);
  memcpy(line, left, leftLength);
  memcpy(line + columns - rightLength, right, rightLength);
  display.println(line);
}

bool hostTimedOut() {
  if (!linkSeen) return millis() > HOST_TIMEOUT_MS;
  return millis() - lastHeartbeatMs > HOST_TIMEOUT_MS;
}

void updateLeds() {
  bool hasWorking = false;
  bool hasComplete = false;
  bool hasInput = false;
  bool hasError = false;
  bool overdueInput = false;

  for (size_t i = 0; i < taskCount; ++i) {
    hasWorking |= tasks[i].state == TaskState::Working;
    hasComplete |= tasks[i].state == TaskState::Complete;
    hasInput |= tasks[i].state == TaskState::Input;
    hasError |= tasks[i].state == TaskState::Error;
    overdueInput |= tasks[i].state == TaskState::Input &&
                    tasks[i].stateAgeSeconds >= ALERT_AFTER_SECONDS;
  }

  const bool lostHost = hostTimedOut();
  const bool offline = linkSeen && !lostHost && networkState == 0;
  const bool online = linkSeen && !lostHost && networkState == 1;
  const bool overdueOffline = offline && networkOfflineSinceMs != 0 &&
      millis() - networkOfflineSinceMs >= ALERT_AFTER_SECONDS * 1000UL;

  setOutput(LED_GREEN_PIN, hasComplete);
  setOutput(LED_YELLOW_PIN, hasWorking);
  setOutput(LED_RED_PIN, hasError || lostHost || offline);
  setOutput(LED_BLUE_PIN, hasInput);
  setOutput(LED_LINK_PIN, online);
  setOutput(LED_STROBE_PIN, overdueInput || overdueOffline);
}

void drawDashboard() {
  if (!oledReady) return;

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);

  const bool lostHost = hostTimedOut();
  if (lostHost) {
    display.println("CODEX DASHBOARD");
    display.println("HOST LINK LOST");
    display.println();
    display.println("Start laptop bridge");
    display.println("or check USB port");
    display.display();
    return;
  }

  char header[22];
  snprintf(header, sizeof(header), "CODEX %u L:%s N:%s",
           static_cast<unsigned>(taskCount), linkSeen ? "OK" : "--",
           networkState == 1 ? "+" : networkState == 0 ? "X" : "?");
  display.println(header);

  if (taskCount == 0) {
    display.println();
    display.println(linkSeen ? "No tracked agents" : "Waiting for bridge");
    display.println(linkSeen ? "Start a Codex task" : "Host not connected");
    display.display();
    return;
  }

  const size_t pageCount = (taskCount + 2) / 3;
  const size_t page = pageCount > 1 ? (millis() / PAGE_INTERVAL_MS) % pageCount : 0;
  const size_t first = page * 3;
  const size_t last = min(first + 3, taskCount);

  for (size_t i = first; i < last; ++i) {
    char duration[12];
    formatDuration(tasks[i].elapsedSeconds, duration, sizeof(duration));
    printAligned(tasks[i].project, duration);
    printAligned(tasks[i].title[0] ? tasks[i].title : "_",
                 stateLabel(tasks[i].state));
  }

  display.display();
}

void setup() {
  const uint8_t outputPins[] = {LED_GREEN_PIN, LED_YELLOW_PIN, LED_RED_PIN,
                                LED_BLUE_PIN, LED_LINK_PIN, LED_STROBE_PIN};
  for (uint8_t pin : outputPins) {
    digitalWrite(pin, LED_OFF);
    pinMode(pin, OUTPUT);
  }
  allLedsOff();

  Serial.begin(115200);
  const uint32_t waitStart = millis();
  while (!Serial && millis() - waitStart < 2000) delay(10);

  Serial.println();
  Serial.println("=== Codex status dashboard ===");
  Serial.println("Protocol: BEGIN / NET / TASK / END at 115200 baud");
  Serial.printf("I2C: SDA GPIO %u, SCL GPIO %u\n", I2C_SDA_PIN, I2C_SCL_PIN);
  initializeOled();
  lastHeartbeatMs = millis();
}

void loop() {
  readSerialProtocol();
  updateLeds();

  static uint32_t lastDrawMs = 0;
  if (millis() - lastDrawMs >= 250) {
    lastDrawMs = millis();
    drawDashboard();
  }
}
