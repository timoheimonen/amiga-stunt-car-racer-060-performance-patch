# Stunt Car Racer Performance patcher

**Version 1.3.0 — emulator only.** This release is intended for FS-UAE / WinUAE etc,
not physical Amiga hardware. It provides **50 Hz physics and rendering at 50 FPS, while lap timers retain their original 8.33 Hz update rate** in PAL.

[Watch the video on YouTube](https://youtu.be/2XVfxuqHn-Q)

## Requirements

- Python 3.8+; no additional packages or assembler needed to patch a disk.
- FS-UAE 3.2.35+ with PAL, Blizzard 1260 / MC68060, 2 MiB Chip RAM
  and 32 MiB accelerator RAM,
  using the [FS-UAE profile](FS-UAE.md).
- Your own original Stunt Car Racer ADF matching the
  [supported checksum](FS-UAE.md#checksums), and your own Kickstart and
  Blizzard 1260 ROMs.

## Usage

```sh
python3 patch.py "/path/to/Stunt Car Racer.adf"
```

Creates `StuntCarRacer-Performance-v<version>.adf` beside the original.
Use `--output /path/to/output.adf` to choose a location and `--force` to
replace an existing output. The original disk is never overwritten.
`python3 patch.py --version` prints the package version.

Boot the patched disk in DF0 using the [FS-UAE settings](FS-UAE.md).

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

## Settings

**Settings** in the main menu.

- **Game Speed:** 100–150%, in 5% steps.
- **AI Difficulty:** 100–150%, in 5% steps.
- **Infinite Boost:** No/Yes.
- **Disable Damage:** No/Yes,
- **Return:** returns to the main menu.


[Changelog](CHANGELOG.md) · [Checksums](FS-UAE.md#checksums) ·
[Patch details](PATCH.md) · [Assembly sources](src)

Timo Heimonen (timo.heimonen@proton.me) · [MIT License](LICENSE)

The license covers the patch code and documentation. Original game disks
and Kickstart ROMs are not included.
