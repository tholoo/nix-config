# ESP32-S3 Codex dashboard and hardware bring-up

Arduino/PlatformIO firmware for an ESP32-S3-N8R2, one SSD1306 OLED, and six
LEDs. The project keeps two independent firmware targets:

- `dashboard` is the normal Codex status display and the default target.
- `bringup` is the original, physically verified hardware self-test in
  `src/main.cpp`.

See [DASHBOARD.md](DASHBOARD.md) for the laptop bridge and Codex hook setup.
See [ARCHITECTURE.md](ARCHITECTURE.md) for the complete protocol, state model,
safety properties, design decisions, and validation record.
See [SECURITY.md](SECURITY.md) for the data-flow and secret-handling audit.
The recorded physical test results remain in
[HARDWARE_BRINGUP_RESULTS.md](HARDWARE_BRINGUP_RESULTS.md).

## One-time tool setup

The directory contains its own pinned Python dependencies. From this directory,
create the local environment with:

```bash
bash setup.sh
```

This creates the ignored `.venv/` used by every command below. PlatformIO keeps
its downloaded board toolchain and libraries in the ignored `.platformio/` and
`.pio/` directories, so no global Python packages are required.

## Wiring

Unplug USB before changing wiring. The selected LED pins avoid GPIO8/GPIO9,
ESP32-S3 strapping pins, native USB, UART0, and flash/PSRAM connections.

| Part | Connection |
|---|---|
| OLED VDD | 3V3 |
| OLED GND | GND |
| OLED SDA | GPIO8 |
| OLED SCL/SCK | GPIO9 |
| LED 1 | GPIO4 -> 220 ohm -> LED anode; cathode -> GND |
| LED 2 | GPIO5 -> 220 ohm -> LED anode; cathode -> GND |
| LED 3 | GPIO6 -> 220 ohm -> LED anode; cathode -> GND |
| LED 4 | GPIO7 -> 220 ohm -> LED anode; cathode -> GND |
| LED 5 | GPIO10 -> 220 ohm -> LED anode; cathode -> GND |
| LED 6 | GPIO11 -> 220 ohm -> LED anode; cathode -> GND |

Every LED needs its own 220-ohm series resistor. The longer LED leg is usually
the anode; the shorter leg and flat edge are usually the cathode. If one does
not light, unplug USB before reversing that LED.

## Target and dependencies

The project uses PlatformIO's `esp32-s3-devkitc-1` target with explicit 8 MB
flash and QSPI 2 MB PSRAM settings for the N8R2 module. Upload and Serial use
the ESP32-S3 hardware USB JTAG/serial interface.
PlatformIO automatically downloads the Arduino ESP32 platform, Adafruit GFX,
and Adafruit SSD1306 libraries.

## Build, flash, and monitor the dashboard

From this directory, build with:

```bash
.venv/bin/pio run -e dashboard
```

Find the connected serial port:

```bash
.venv/bin/pio device list
```

Replace `PORT` with the reported path, such as `/dev/ttyACM0`, then flash:

```bash
.venv/bin/pio run -e dashboard -t upload --upload-port PORT
```

Open the monitor:

```bash
.venv/bin/pio device monitor --port PORT --baud 115200
```

Only one program can own the serial port at a time. After activating the Nix
configuration, stop the background bridge before flashing or monitoring:

```bash
systemctl --user stop codex-board
```

Start it again afterward with `systemctl --user start codex-board`.

Use the native USB-C connector labeled `USB` or `USB-OTG`. For the first upload,
hold **BOOT**, tap **RESET**, then release **BOOT**; `pio device list` should
identify `303A:1001` as `USB JTAG/serial debug unit` before uploading.

## Re-run the original hardware self-test

The original debug firmware has not been replaced. Build and flash it with:

```bash
.venv/bin/pio run -e bringup
.venv/bin/pio run -e bringup -t upload --upload-port PORT
```

When finished, restore the dashboard with:

```bash
.venv/bin/pio run -e dashboard -t upload --upload-port PORT
```

## Expected bring-up sequence

1. Serial prints chip, 8 MB flash, 2 MB PSRAM, reset, and pin information.
2. The firmware scans I2C and prints every address found.
3. It initializes an SSD1306 at `0x3C`, or `0x3D` if `0x3C` is absent.
4. The OLED shows its address and the current test.
5. LED 1 through LED 6 turn on individually for about 700 ms each.
6. A forward chase and backward chase run.
7. All six LEDs turn on for about one second, then turn off.
8. Serial prints `Hardware self-test complete.` and the OLED shows completion.
9. A slow chase repeats forever.

If no supported OLED address is found, the OLED test is skipped, all six LEDs
blink three times as an error indication, and LED testing continues.

## Troubleshooting

### No I2C device

- Confirm VDD is 3V3, both devices share GND, SDA is GPIO8, and SCL is GPIO9.
- Check the OLED module's printed pin order.
- If the module lacks pull-ups, add about 4.7 kohm from SDA to 3V3 and another
  from SCL to 3V3. Most four-pin modules already include them.

### OLED stays black

- Read Serial for the detected address and initialization result.
- Confirm the display is a 128x64 SSD1306 I2C module, not SH1106 or 128x32.
- Check power, ground, SDA/SCL, connector orientation, and protective film.

### One LED does not light

- Unplug USB, reverse that LED, and reconnect.
- Confirm the resistor is in series and the GPIO matches the table.
- Check for a loose breadboard row and try another LED/resistor.

### One LED is always on

- Unplug USB before correcting it.
- Confirm it is connected to a GPIO, not 3V3.
- Check for bridged breadboard rows or a resistor placed in the wrong row.
