# Patch details — 1.1.0

This release targets FS-UAE with PAL timing, a Blizzard 1260 / 68060, 2 MiB Chip RAM
and 32 MiB accelerator RAM. See the [FS-UAE profile](FS-UAE.md) for configuration.

## Physics and rendering

Practice mode and computer-opponent races use 50 Hz physics with a selectable
20–30 ms simulation step (100–150%) and rendering at 50 FPS.

- Player and opponent movement, suspension, steering and collision calculations
  use integer arithmetic with fractional accumulators.
- Direct yaw correction advances at one sixth of its original per-step amount at 100%,
  retaining signed fractional remainders between simulation steps.
- The severe-impact cooldown advances every sixth physics step, preserving
  its original timing while fresh damage events remain processed at 50 Hz.
- Race clocks, selected event timers, AI decisions and respawn counters
  advance through a pulse every sixth physics step. Time penalties are
  applied separately.
- Rendering waits for the Copper display update before reusing a screen
  buffer. Display graphics, Copper lists and DMA buffers use Chip RAM.

## Speed adjustment

Player and opponent physics scale with the main-menu speed setting, including
yaw correction. Crane movement and legacy timer pulses keep their timing.
The setting stays between races and resets to 100% after boot. Saved records
share the same table across speeds. See [controls](README.md#speed-adjustment).

Five guarded runtime entry overlays dispatch to the speed routines. The yaw
instruction overlay preserves the existing damping continuation.
`src/patches.json` records their expected and replacement bytes.

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
intro. The 4870-byte runtime is stored at ADF offset `0xb720` and copied into
a 8192-byte Chip RAM reservation at `0x181000`. The initial load starts at
ADF offset `0x2c00` and uses a `0xac00`-byte Chip allocation. The loader clears
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

[src/patches.json](src/patches.json) lists the 85 game instruction patches,
boot and loader patches, expected and replacement bytes, address mappings
and payload hashes. Words and longwords use big-endian encoding.
[patch.py](patch.py) embeds the boot, runtime and intro code for standalone use.

| Content | Size | SHA-256 |
| --- | ---: | --- |
| Boot | 320 | `1061e579770d4df6382de633c441e4aaf2df064621a7cb19a4e0d57478fcf325` |
| Runtime | 4870 | `83eff4a42bc5743eef6bc61c3f9756913c33d5fe3308b36322fdfd11644ed1c1` |
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
