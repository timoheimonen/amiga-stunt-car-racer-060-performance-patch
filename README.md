# Stunt Car Racer 50 FPS — KS3.1 / AGA / 68060 patcher

**Version 0.3.0 — emulator only.** This release is intended for FS-UAE,
not physical Amiga hardware. It provides **50 Hz physics and 50 FPS rendering** in PAL
Practice mode and races against computer drivers, with timing corrections.

[Watch the video on YouTube](https://youtu.be/FqTMDyNoEq0)

## Requirements

- Python 3.8+; no additional packages or assembler needed to patch a disk.
- FS-UAE 3.2.35 emulating PAL A1200/AGA, MC68060, Kickstart 3.1 A1200 rev 40.68,
  2 MiB Chip RAM and 8 MiB Fast RAM.
- Your own original Stunt Car Racer ADF matching the
  [supported checksum](FS-UAE.md#checksums), and your own Kickstart ROM.

## Usage

```sh
python3 patch.py "/path/to/Stunt Car Racer.adf"
```

Creates `StuntCarRacer-KS31-AGA-060-50FPS.adf` beside the original.
Use `--output /path/to/output.adf` to choose a location and `--force` to
replace an existing output. The original disk is never overwritten.
`python3 patch.py --version` prints the package version.

Boot the patched disk in DF0 using the [FS-UAE settings](FS-UAE.md), then
choose Practice or a single-player race. Start with a fresh boot so the
loader installs the patch. Do not restore an older emulator save state.
The single `patch.py` file can be copied and used independently.

[Changelog](CHANGELOG.md) · [Checksums](FS-UAE.md#checksums) ·
[Patch details](PATCH.md) · [Assembly sources](src)

Timo Heimonen (timo.heimonen@proton.me) · [MIT License](LICENSE)

The license covers the patch code and documentation. Original game disks
and Kickstart ROMs are not included.

Tools: Amitools, FS-UAE, Ghidra, OpenAI, vasm.
