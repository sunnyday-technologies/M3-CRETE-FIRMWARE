# M3-CRETE — Klipper firmware

Klipper configuration for the M3-CRETE concrete 3D printer.
Controller: **BigTreeTech Kraken v1.0** (STM32H723, 8× onboard TMC5160).
Host: **Raspberry Pi 5**.

We are bringing the machine up in **stages**. Each stage is a known-good,
testable checkpoint — don't move to the next until the current one passes.

| Stage | File | Scope | Status |
|-------|------|-------|--------|
| **1** | [`printer.cfg`](printer.cfg) | 4× Z motors, sensorless StallGuard homing | **active** |
| 2 | _tbd_ | + X (belt-pinion) and Y (dual, anti-rack) | planned |
| 3 | _tbd_ | + extruder (stepper) + MAI Pictor pump (0–10 V analog cmd) | planned |
| 4 | _tbd_ | + input shaping (ADXL345), print macros, flush/prime | planned |

---

## 0. Raspberry Pi image (do this first)

You need a Klipper host OS on the Pi 5. Easiest path:

1. Install **Raspberry Pi Imager** on your PC.
2. Choose device **Raspberry Pi 5**, then under *Choose OS → Other specific-purpose
   OS → 3D printing*, pick **MainsailOS** (Raspberry Pi OS + Klipper + Moonraker +
   Mainsail, preinstalled). If it's not listed in your Imager version, download the
   MainsailOS `.img.xz` from the MainsailOS releases page and use *Use custom*.
3. Click the gear/edit icon **before writing** and set: hostname, **enable SSH**,
   Wi-Fi/locale, and a username/password. (Saves a headless-setup headache.)
4. Flash the microSD, boot the Pi, then browse to `http://<hostname>.local/`
   — that's Mainsail.

Alternatives: **FluiddPi** (same idea, Fluidd UI) or plain **Raspberry Pi OS Lite**
+ [KIAUH](https://github.com/dw-0/kiauh) if you want to install Klipper/Moonraker
yourself. MainsailOS is the least fuss for a Pi 5.

After the Pi is up, **build + flash Klipper firmware onto the Kraken** (flags are in
the header of `printer.cfg`), then drop `printer.cfg` into
`~/printer_data/config/` and restart Klipper.

### Building the firmware — one critical checkbox

In `make menuconfig`, **first enable `[*] Enable extra low-level configuration
options`.** The "Bootloader offset" and "Clock Reference" menus only exist behind
that checkbox — skip it and the build silently assumes the wrong crystal, producing
firmware that boots dead (no USB device, no error, nothing). Then set: STM32 →
STM32H723 → 128KiB bootloader → **25 MHz crystal** → USB (PA11/PA12).

### Flashing over USB (DFU) — no SD card needed

The STM32's ROM has a built-in USB bootloader that always works, regardless of what
is (or isn't) in flash:

1. Connect the Kraken's **USB-C** port to the Pi. ⚠️ Use a **data** cable — phone
   charge-only cables fit perfectly and carry nothing. ⚠️ The Kraken's **USB-A port
   is a 5 V power output**, not a data port.
2. Hold **BOOT0**, tap **RESET**, release BOOT0 (buttons are in a row:
   RESET · BOOT0 · BOOT1). `lsusb` on the Pi should now show
   `0483:df11 STMicroelectronics STM Device in DFU Mode`.
3. `cd ~/klipper && make flash FLASH_DEVICE=0483:df11`
4. `dfu-util` often ends with `Error during download get_status` — **this is
   harmless**; the flash already succeeded. Tap RESET and check for
   `/dev/serial/by-id/usb-Klipper_stm32h723xx_*`.

### Troubleshooting a board that won't talk

| Symptom | Cause | Fix |
|---|---|---|
| No USB device ever, even in DFU | Charge-only cable, wrong port (USB-A), or no logic power | Data cable into USB-C; check the 24 V **POWER** terminal (separate from MOTOR-POWER) |
| SD flash does nothing — `firmware.bin` never becomes `FIRMWARE.CUR` | Board shipped with **blank flash** (no BTT bootloader) — it happens | Flash via DFU (above), or install BTT's bootloader first ([their repo](https://github.com/bigtreetech/BIGTREETECH-Kraken/tree/master/Firmware), `Kraken_H723_bootloader.bin` + dfu-util to `0x8000000`) |
| DFU works, but after RESET the board is silent | Firmware built without the low-level checkbox (wrong clock), **or** flaky bootloader→app handoff | Rebuild with **25 MHz crystal**. If it still only runs intermittently, build with Bootloader offset = **No bootloader** and DFU-flash to `0x08000000` — the board then boots Klipper directly (SD flashing is dead on such boards anyway; future updates go via DFU) |
| Endless `device not responding to setup address` / `error -71` in `dmesg` | Firmware running with wrong clock — USB bit-timing off | Rebuild with the checkbox + 25 MHz crystal |
| Board enumerates via a "Genesys Logic Hub" you don't recognize | Active/repeater USB extension cable | Fine when it works, but flaky — prefer a short passive cable into a Pi **USB 2.0** port |

---

## 1. Z-axis bring-up (current stage)

Wire the four Z motors to the **first four driver slots, S1–S4**, and install the
**DIAG jumper** on each of those four slots (required for StallGuard sensorless
homing). Then in the Mainsail console, **in this order**:

1. **Confirm connection** — Klipper reports *Ready*. If not, fix the `serial:`
   path in `printer.cfg` (`ls /dev/serial/by-id/` on the Pi).
2. **Energize** — `ZHOLD`. Each motor should hold (resist turning by hand).
   `ZRELEASE` frees them.
3. **Spin + direction, one motor at a time** —
   `ZJOG MOTOR=0 DIST=5 VEL=3` … through `MOTOR=3`.
   `+DIST` should raise that corner. If a motor runs the **wrong way**, add or
   remove the `!` on that stepper's `dir_pin` and `FIRMWARE_RESTART`.
4. **Set current, then tune StallGuard** — raise `run_current` toward your load
   (1.5–1.8 A; never above ~2.0 A RMS for these 2.8 A motors), then tune
   `driver_SGT` per slot. Watch live load with `ZSTATUS`.
   - Stalls early / before the brace → **raise** `driver_SGT` (less sensitive)
   - Crashes the brace without stopping → **lower** `driver_SGT` (more sensitive)
   - `FIRMWARE_RESTART` after each change. Re-tune if you change `run_current`.
5. **Home** — `HOME_Z`. All four corners drive up and each zeroes itself at its
   own stall point against the top brace (coplanar, no probe).

### What the macros do
| Macro | Action |
|-------|--------|
| `ZHOLD` / `ZRELEASE` | energize / free all 4 Z motors |
| `ZJOG MOTOR=n DIST=mm VEL=mm/s` | open-loop jog of one motor (spin/direction check) |
| `ZSTATUS` | dump TMC StallGuard + driver state for SGT tuning |
| `HOME_Z` | sensorless quad-Z home (`G28 Z`) + 5 mm back-off |

> ⚠️ X and Y are **inert stubs** in this stage (no motors, no driver config) — they
> only exist so Klipper's kinematics will load. **Do not jog or home X/Y, and do not
> run a bare `G28`.** Use `HOME_Z` (= `G28 Z`).

---

## Hardware notes / open items

- **Motion motors (X/Y/Z, 7×):** StepperOnline **23HS22-2804S** — NEMA23, 1.24 N·m,
  **2.8 A/phase**, 0.92 Ω, 2.68 mH. ⚠️ *Smaller* than the project BOM part
  (`23HS45-4204S1`, 3 N·m / 4.2 A); this config targets the 2.8 A motor. If the BOM
  is the intended part, currents need to go up.
- **Extruder motor (8th):** StepperOnline **23HS30-2804S** — NEMA23, 1.9 N·m,
  2.8 A/phase (larger body, same current class → same `sense_resistor`/current range).
- **Pressure pump (9th):** **MAI 2PUMP Pictor**, ~0.7–15.5 L/min, **0–10 V** analog
  speed command + a run/enable input — not a Kraken stepper. See Stage 3 below.
- **Kraken specifics that bite people:** onboard drivers use **software SPI**
  (PC6/PC8/PC7) and **`sense_resistor: 0.022`**. Generic TMC5160 configs you find
  online use hardware SPI and 0.075 — those values will set the wrong motor current
  here. Pins in `printer.cfg` come from BTT's official
  `generic-bigtreetech-kraken.cfg`.

### Stage 3 preview — extruder (stepper) + pressure pump (analog command)

Two different devices:

- **8th = extruder** — StepperOnline **23HS30-2804S** (NEMA23, 1.9 N·m, 2.8 A), a
  normal step/dir stepper on an onboard Kraken slot. Configured as `[extruder]`.
- **9th = pressure pump** — **MAI 2PUMP Pictor**, ~0.7–15.5 L/min. **Not** a step/dir
  motor: it takes a **0–10 V** analog speed command plus a run/enable input and runs
  its own drive internally.

Klipper/Kraken have **no analog (DAC) output** — only digital PWM — so an analog
command always needs a small converter. Two ways to generate it:

1. **Frequency→Voltage, auto-tracking (recommended).** Define the pump as
   `[extruder_stepper pump_feed]` synced to `[extruder]` and route its **STEP pulse
   train into an F/V converter** → analog voltage. Pulse frequency ∝ flow, so the
   pump tracks the nozzle in real time. Gains `rotation_distance` (flow→voltage
   scaling) and `pressure_advance` (pump leads the nozzle to pre-pressurize the
   hose). No real motor sits on that signal — only its frequency is used. *(This is
   the current hardware approach and the one to keep.)*
2. **PWM→Analog setpoint.** A Klipper `[output_pin] pump` (PWM off a spare fan port)
   into a PWM-to-0–10 V/0–24 V module, set via `SET_PIN PIN=pump VALUE=…`. Simpler,
   but it's a held level — does not auto-follow extruder velocity unless scripted
   per-move. Use only if the pump self-regulates flow.

**Chosen path:** option 1, using a **spare Kraken step/dir header**. A synced
`[extruder_stepper pump_feed]` drives that header — **STEP → F/V converter → 0–10 V →
Pictor speed input**. The header's **DIR** line is spare and can wire to the Pictor's
forward/reverse input if suck-back is ever wanted.

Two gotchas to design around:

- **0 V ≠ stopped.** The Pictor has a minimum flow and a deadband, so a 0 V command
  does not reliably halt it. Drive its **run/enable input from a separate digital
  `[output_pin] pump_enable`** so START/END/CANCEL and flush can hard-start/stop it.
- **F/V loses sign.** A frequency→voltage converter sees only pulse rate, not
  direction — so a *retract* (E−) still reads as positive flow. Concrete rarely
  retracts, but if you use suck-back, gate it via the DIR line into the Pictor's
  reverse input; don't expect the F/V output to go negative.

Exact spare-header pins get assigned in the Stage 3 config.
