# Stunt Car Racer 50 HZ / 50 FPS — 68060 patcher

**Version 1.1.0 — emulator only.** This release is intended for FS-UAE / WinUAE etc,
not physical Amiga hardware. It provides **50 Hz physics and rendering at 50 FPS, while lap timers retain their original 8.33 Hz update rate** in PAL.

[Watch the video on YouTube](https://youtu.be/FqTMDyNoEq0)

## Requirements

- Python 3.8+; no additional packages or assembler needed to patch a disk.
- FS-UAE 3.2.35 with PAL, Blizzard 1260 / MC68060, 2 MiB Chip RAM
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

## Speed adjustment

Select **5: SPEED ADJUST** in the main menu and confirm with Space, Return
or joystick fire. Each confirmation advances by 5%, from 100% to 150%,
then returns to 100%. The default after boot is 100%.

The setting affects player and opponent simulation speed. Crane movement,
lap timers and rendering frequency remain unchanged. The setting lasts for
the current session; saved records do not distinguish speed settings.

[Changelog](CHANGELOG.md) · [Checksums](FS-UAE.md#checksums) ·
[Patch details](PATCH.md) · [Assembly sources](src)

Timo Heimonen (timo.heimonen@proton.me) · [MIT License](LICENSE)

The license covers the patch code and documentation. Original game disks
and Kickstart ROMs are not included.
