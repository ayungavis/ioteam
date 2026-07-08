# Controller Firmware

This directory contains the ESP-IDF firmware for the DoseLatch controller in `controller/doselatch-firmware`.

## Prerequisites

- ESP-IDF installed locally
- `idf.py` available in your shell
- An ESP32 board connected over USB
- The board's serial port path, such as `/dev/cu.usbserial-0001`

If `idf.py` is not available yet, source your ESP-IDF environment first:

```bash
. "$HOME/esp-idf/export.sh"
```

The local `build.sh` script also tries to source that file automatically before failing.

## Build

From the repository root:

```bash
cd controller/doselatch-firmware
./build.sh
```

This firmware is configured for:

- `esp32` target
- `115200` serial monitor baud rate
- `GPIO 4` for the status LED
- `GPIO 17` for the reed switch

## Flash

Replace `<PORT>` with your board's serial port.

```bash
cd controller/doselatch-firmware
idf.py -p <PORT> flash
```

Example:

```bash
idf.py -p /dev/cu.usbserial-0001 flash
```

## Monitor Logs

```bash
cd controller/doselatch-firmware
idf.py -p <PORT> monitor
```

The configured monitor baud rate is `115200`.

If you want the shortest path, flash and start the monitor in one command:

```bash
cd controller/doselatch-firmware
idf.py -p <PORT> flash monitor
```

While the monitor is open, type `log-level D` to enable the extra connection trace
and `status` to print the current pairing and Wi-Fi state.

## Reset Provisioning State

If the controller log shows old values such as `paired=true`, `backendMode=mock`,
or the wrong `ssid`, clear NVS before testing the Xcode add-device flow again:

```text
log-level D
status
factory-reset
```

After the board reboots, run `status` again. A clean provisioning run should start
from `paired=false` and `provisioningState=unpaired`, then the next Xcode pairing
attempt should log `Pair command received ... backendMode=http backendBaseURLSet=true`.

## What to Expect

On boot, the firmware should:

- start normally on the ESP32 target
- initialize BLE with NimBLE
- advertise over BLE for provisioning
- persist pairing and Wi-Fi state in NVS
- publish reed switch open/close events when the sensor changes state

## Troubleshooting

`idf.py not found`

Source the ESP-IDF environment first:

```bash
. "$HOME/esp-idf/export.sh"
```

Wrong or busy serial port

Use the correct device path for your board and retry the flash or monitor command.

Unreadable serial output

Keep the monitor baud at `115200`, which matches the checked-in firmware config.
