# M3-CRETE Firmware

This repository contains firmware configuration files and optional patches
for operating the M3-CRETE open hardware platform.

Supported firmware:
- Marlin (GPLv3)
- Klipper (GPLv3)

This repository does not redistribute firmware source code.
Users must obtain firmware from the original upstream projects.

## Install (Klipper)

On a Raspberry Pi that already runs Klipper + Moonraker (e.g. flashed with
MainsailOS), in an SSH session:

```bash
cd ~
git clone https://github.com/sunnyday-technologies/M3-CRETE-FIRMWARE.git
cd M3-CRETE-FIRMWARE
bash install.sh
```

`install.sh` drops the M3-CRETE config into `~/printer_data/config` (backing up
any existing `printer.cfg`), adds the M3-CRETE + KlipperScreen blocks to
`moonraker.conf` without clobbering it, auto-detects the Kraken's serial path,
and restarts Klipper + Moonraker. Flags: `--no-screen` (skip KlipperScreen),
`--force`, `--help`.

We **track** upstream Klipper/Moonraker/Mainsail/KlipperScreen (they self-update
via Moonraker's update manager) and never fork them — the only thing this repo
publishes is the M3-CRETE config, which also registers as a click-to-update
component in Mainsail.

- Per-stage config + commissioning notes: [`klipper/README.md`](klipper/README.md)
- Beginner, step-by-step software guide: https://m3-crete.com/build-guide/software/

## License

All files in this repository are licensed under GNU GPL v3.0,
consistent with the upstream firmware projects.

## Hardware Platform

Mechanical design files and documentation:

https://github.com/sunnyday-technologies/M3-CRETE
