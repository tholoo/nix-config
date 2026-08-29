# ESP32-S3 hardware bring-up results

Date: 2026-08-28

## Hardware

- Development board: DevKit-style ESP32-S3 board with two USB-C connectors
- Module: ESP32-S3-N8R2
  - 8 MB quad-SPI flash
  - 2 MB quad-SPI PSRAM
- Display: 0.96-inch 128x64 SSD1306 I2C OLED
  - Fixed yellow top 16-pixel zone and blue lower 48-pixel zone
- LEDs:
  - Five ordinary two-pin LEDs
  - One two-pin self-cycling seven-color LED
  - One 220-ohm series resistor per LED

## Final wiring

| Component | ESP32-S3 connection |
|---|---|
| OLED VDD | 3V3 |
| OLED GND | GND |
| OLED SDA | GPIO8 |
| OLED SCL/SCK | GPIO9 |
| LED 1 — green | GPIO4 through 220 ohms; cathode to GND |
| LED 2 — yellow | GPIO5 through 220 ohms; cathode to GND |
| LED 3 — red | GPIO6 through 220 ohms; cathode to GND |
| LED 4 — blue | GPIO7 through 220 ohms; cathode to GND |
| LED 5 — “harder blue” | GPIO10 through 220 ohms; cathode to GND |
| LED 6 — self-cycling/strobing seven-color | GPIO11 through 220 ohms; cathode to GND |

The reported physical LED order is: **green, yellow, red, blue, “harder
blue,” then the self-cycling/strobing light**. “Harder blue” is preserved as
the user's description; it has not been reinterpreted as darker or brighter.

LED 6 initially did not illuminate because its polarity was reversed. It worked
after power was disconnected and the LED legs were swapped. Its colors are
controlled internally; GPIO11 can only turn the package on or off.

## Firmware configuration

- Framework: Arduino for ESP32
- Build system: PlatformIO
- Environment: `bringup`
- Board target: `esp32-s3-devkitc-1` with explicit N8R2 overrides
- Flash: 8 MB
- Memory type: `qio_qspi`
- PSRAM enabled with `BOARD_HAS_PSRAM`
- Serial monitor speed: 115200 baud
- USB CDC enabled on boot

## Observed test results

The following physical results were reported by the user:

- ESP32-S3 powered and ran the firmware: **PASS**
- I2C scan and OLED detection: **PASS**
- SSD1306 initialization and visible OLED status: **PASS**
- Individual LED tests on GPIO4, GPIO5, GPIO6, GPIO7, GPIO10, and GPIO11:
  **PASS**
- Forward LED chase: **PASS**
- Backward LED chase: **PASS**
- All-six-LED test: **PASS**
- Continuous slow chase: **PASS**
- LED 6 internal color cycling: **PASS**

The exact OLED address and complete Serial transcript were not captured in this
record. The firmware supports `0x3C` and `0x3D`, preferring `0x3C` when both are
present.

## Build and upload record

The final firmware compiled successfully with:

```bash
.venv/bin/pio run
```

The connected native USB device initially appeared as software TinyUSB CDC:

```text
VID:PID 303A:4001 — Espressif CDC Device
```

It did not respond to esptool until the board was manually placed in download
mode by holding **BOOT**, pressing and releasing **RESET**, then releasing
**BOOT**. The correct downloader/debug interface then appeared as:

```text
VID:PID 303A:1001 — USB JTAG/serial debug unit
```

On the NixOS host, temporary device ownership was required:

```bash
sudo chown "$USER" /dev/ttyACM0
```

The successful upload command was:

```bash
.venv/bin/pio run -e bringup -t upload --upload-port /dev/ttyACM0
```

The monitor command was:

```bash
.venv/bin/pio device monitor --port /dev/ttyACM0 --baud 115200
```

`/dev/ttyACM0` is host-specific and may change after reconnecting. Run
`.venv/bin/pio device list` before future uploads if necessary.

## Electrical safety notes

- The OLED is powered from 3.3 V, not 5 V.
- GPIO8/GPIO9 are reserved for I2C and are not used for LEDs.
- The LED pins avoid ESP32-S3 strapping, native USB, UART0, and module
  flash/PSRAM connections.
- Each LED has its own 220-ohm resistor.
- At 3.3 V, a 220-ohm resistor limits even a zero-forward-voltage fault model
  to 15 mA per GPIO; actual LED current is lower.
- The firmware establishes LOW as the inactive output level before enabling
  each LED GPIO as an output.
- The continuous chase drives one LED at a time. The all-on test lasts about
  one second.
- USB may be unplugged while the normal test firmware is running. The firmware
  is not writing flash or files during the test; reconnecting power restarts
  the self-test.

## Outcome

The minimal hardware bring-up passed based on the user's reported physical
observations. The verified wiring and firmware are a suitable baseline before
adding application-specific hardware or behavior.

The original dashboard demo was also physically observed: the OLED displayed
three simultaneous `INPUT`, `RUN`, and `DONE` rows with `L:OK N:+`; green,
yellow, blue, and harder-blue link LEDs were on; red and the delayed strobe
were off. Real Codex hook transitions remained a separate application test. A
later real session successfully generated a title, displayed `DONE`, and
illuminated green; session-close removal was then added and remains to be
physically confirmed after activation. The later usage-focused firmware
removed the independent network indicator and reachability probe.
