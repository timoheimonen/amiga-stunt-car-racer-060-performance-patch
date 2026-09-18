# Stunt Car Racer Performance patcher

**Version 1.2.1 — emulator only.** This release is intended for FS-UAE / WinUAE etc,
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

Creates `StuntCarRacer-060-50FPS.adf` beside the original.
Use `--output /path/to/output.adf` to choose a location and `--force` to
replace an existing output. The original disk is never overwritten.
`python3 patch.py --version` prints the package version.

Boot the patched disk in DF0 using the [FS-UAE settings](FS-UAE.md).

## Settings

Choose **5. Settings** in the main menu.

- **Game Speed:** 100–150%, in 5% steps. Changes both cars' simulation speed.
- **AI Difficulty:** 100–150%, in 5% steps. Raises the opponent's target pace
  without changing the simulation step.
- **Infinite Boost:** No/Yes. Yes allows turbo without consuming the reserve,
  even when it is empty.
- **Disable Damage:** No/Yes (default No). Yes prevents new player damage,
  crack growth and damage holes; existing damage remains.
- **Return:** returns to the main menu.


[Changelog](CHANGELOG.md) · [Checksums](FS-UAE.md#checksums) ·
[Patch details](PATCH.md) · [Assembly sources](src)

Timo Heimonen (timo.heimonen@proton.me) · [MIT License](LICENSE)

The license covers the patch code and documentation. Original game disks
and Kickstart ROMs are not included.
