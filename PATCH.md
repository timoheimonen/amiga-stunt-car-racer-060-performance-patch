# Patch details — 1.0.0

This release targets FS-UAE with PAL timing, a 68060, 2 MiB Chip RAM and
8 MiB Fast RAM. See the [FS-UAE profile](FS-UAE.md) for configuration.

## Physics and rendering

Practice mode and computer-opponent races use 50 Hz physics with a fixed
20 ms step and rendering at 50 FPS.

- Player and opponent movement, suspension, steering and collision calculations
  use integer arithmetic with fractional accumulators.
- Race clocks, selected event timers, AI decisions and respawn counters
  advance through a pulse every sixth physics step. Time penalties are
  applied separately.
- Rendering waits for the Copper display update before reusing a screen
  buffer. Display graphics, Copper lists and DMA buffers use Chip RAM.

## Rendering optimizations

- Object and track points are transformed in batches using scaled index addressing.
- Polygon filling uses aligned 32-bit writes for long spans and word writes
  for short spans and edges.
- Coefficients are calculated with unrolled integer loops.
- Two 65,536-entry angle lookup tables use 256 KiB of Fast RAM. If that
  allocation fails, angles are calculated directly.
- Color selection uses a 16-color mask table and data pointers to pixel
  and word drawing routines.

## Loader and memory

The patcher modifies the game's raw-loader ADF at fixed offsets.

A 320-byte boot extension at `0x200` installs the game runtime and loads the
intro. The 4004-byte runtime is stored at ADF offset `0xb720` and copied into
a 4096-byte Chip RAM reservation at `0x181000`. The initial load starts at
ADF offset `0x2c00` and uses a `0x9c00`-byte Chip allocation. The loader clears
the CPU caches before executing copied code.

The runtime and optional 256 KiB Fast angle tables remain allocated for the
session. Failure of a required game Chip allocation halts boot with a red
screen. Restart with the documented memory configuration.

The code uses integer instructions and requires neither an FPU nor an MMU.

## Boot intro

Press Space or click the mouse to continue to the game.

## Address mapping and patches

The main game block loads from ADF `0xdc00` to address `0xe700`.

```text
runtime address = ADF offset + 0xb00
runtime address = extracted game-block offset + 0xe700
```

[src/patches.json](src/patches.json) lists the 75 game instruction patches,
boot and loader patches, expected and replacement bytes, address mappings
and payload hashes. Words and longwords use big-endian encoding.
[patch.py](patch.py) embeds the boot, runtime and intro code for standalone use.

| Content | Size | SHA-256 |
| --- | ---: | --- |
| Boot | 320 | `6357139095452c4ecfc31e931bfe8eb8587867dd48ad9ba7f69b91a41683f879` |
| Runtime | 4004 | `ab92db5f86e2e7dcaf05fffc7ffcba5141ddf6affd750fc519011635397b4071` |
| Intro | 5496 | `1e529a65557ae685581a1f76d3dac9821ef6dc3487b089ee2cc223c4fec2f920` |

Disk and ROM identifiers are in [FS-UAE.md](FS-UAE.md#checksums).

## Building from source

Using the patcher requires Python and the supported original ADF. Rebuilding
its embedded code also requires `vasmm68k_mot` with Motorola syntax support.

```sh
python3 -B scripts/build_patch.py "/path/to/Stunt Car Racer.adf" --check
```

The builder generates the intro tables, assembles the sources and checks
the resulting bytes and hashes against [src/patches.json](src/patches.json).
Build files go under `work/adf-patch-build/`. Use `--write` to regenerate the
embedded data after updating the manifest and package version.

## Output protection and rollback

The patcher verifies the source disk, replacement locations, embedded code,
boot checksum and complete output hash. It reads back a temporary output
before publishing it atomically. Existing output requires `--force` to replace.
The source file and its aliases are protected; symbolic-link output paths
are rejected.

To restore the original game, quit the patched session and boot the untouched
original ADF with fresh emulator state. A save state containing patched RAM
continues to use the patch regardless of the inserted floppy.
