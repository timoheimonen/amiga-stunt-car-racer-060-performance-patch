# Stunt Car Racer Performance patcher

**Version 1.4.5.** This release is primarily intended for emulation. On real
hardware it has been tested working on at least an **Amiga 1200 + PiStorm32 Lite +
Raspberry Pi 4B 1.8 GHz + Emu68 1.1 beta.1**. Other real Amiga configurations
are unconfirmed.
It provides **50 Hz physics and rendering at up to 50 FPS, while lap timers retain their original 8.33 Hz update rate** in PAL.
The achieved frame rate depends on the machine's Chip RAM access speed; game speed stays correct when frames are late.

## Requirements

- Python 3.8+; no additional packages or assembler needed to patch a disk.
- Primarily an emulated Amiga with PAL, MC68060, 2 MiB Chip RAM and at least
  1 MiB Fast RAM ([requirements](PATCH.md#requirements)). Lower frame rates may call
  for adjusting **Game Speed** in [Settings](#settings).
- Your own original Stunt Car Racer ADF matching the
  [supported checksum](PATCH.md#checksums), and your own Kickstart ROM.

## Usage

```sh
python3 patch.py "/path/to/Stunt Car Racer.adf"
```

Creates `StuntCarRacer-Performance-v<version>.adf` beside the original.
Use `--output /path/to/output.adf` to choose a location and `--force` to
replace an existing output. The original disk is never overwritten.
`python3 patch.py --version` prints the package version.

Boot the patched disk in DF0.

## Track Editor (Beta)

Build in the game's 3D view,
with a 16 × 16 ground grid, up to 64 internal pieces and 33 section choices.
**V** toggles an overview of the whole track and building area.

- **Left/Right** (joystick or cursor keys): browse pieces or compatible choices.
- **Fire/Space:** preview, edit or confirm the selected section. After appending
  to an open track, the next press starts another addition.
- **Esc:** cancel a preview or leave the editor. Unsaved changes offer Save,
  Discard or Cancel.
- **Backspace:** remove the selected section. **U:** undo the latest edit.
- **N:** start a new track after confirmation.
- **S / L:** save or load a named track.

The game disk has **32 save slots** on two pages. Draft tracks can be saved
and resumed; only validated **Ready** tracks appear in **Practise**. The original
eight tracks remain available. Custom tracks retain their own best times,
separately for normal and super league. Record eligibility requires Game Speed
at 100%, Infinite Boost No and Disable Damage No.

Save/Load → **Disk** exports or imports tracks using **DF1**. Enable a second
floppy drive and insert a writable ADF for track storage. Initializing that
disk erases its contents after confirmation. It provides another 32 slots;
records are not exported to DF1. DF0 stays the game disk.

Keep the patched game disk writable to retain tracks and records. Back it up
before replacing it with a newly patched image; patching the original creates
a fresh disk and does not transfer saved tracks. Export tracks to DF1 first
and import them into the new game disk through the editor.

## Computer Link (Beta)

Two machines race each other over their serial ports (null-modem link). Both
must run this version.

1. Choose **Computer Link** in the main menu on both machines.
2. Press **H** on one machine (Host) and **J** on the other (Join).
   **Esc** returns to the menu.

The Host's menu choices, including Settings, apply to both machines. Each
machine runs its own 50 Hz physics; car positions are exchanged 20 times per
second and the other car is shown smoothly with a short delay. Cars pass
through each other. Pause, leaving the race, wrecks, results and points are
shared. A tie is awarded to the Host. Link races do not change the records on
either disk.

The link championship runs four seasons through Divisions 4, 3, 2 and 1, the
last one being the FINAL SEASON. Points accumulate over all four seasons and
the driver with the most points after Division 1 wins. Each new link
championship starts in Division 4.

## Settings

**Settings** in the main menu.

- **Game Speed:** 100–150%, in 5% steps.
- **AI Difficulty:** 100–150%, in 5% steps.
- **Infinite Boost:** No/Yes.
- **Disable Damage:** No/Yes,


[Changelog](CHANGELOG.md) · [Checksums](PATCH.md#checksums) ·
[Patch details](PATCH.md) · [Assembly sources](src)

Timo Heimonen (timo.heimonen@proton.me) · [MIT License](LICENSE)

The license covers the patch code and documentation. Original game disks
and Kickstart ROMs are not included.
