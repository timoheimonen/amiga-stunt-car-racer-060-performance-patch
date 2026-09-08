# Patch details — 0.4.0

This is an **emulator-only release** for FS-UAE. Physical Amiga hardware
is outside this version's scope.

## Physics and rendering

Practice mode and races against computer drivers use a fixed 20 ms physics
step and one PAL field per rendered frame. Each frame draws a new simulation
state; there are no interpolated intermediate frames.

- Player integration uses twelve fractional accumulators and a 238/1536
  coefficient. External changes to position or velocity reset the affected
  accumulator.
- Player and opponent suspension use a spring-difference coefficient of
  1656/256, signed 32-bit intermediate arithmetic and signed-word saturation.
- Opponent vertical velocity and road speed use 238/1536. Vertical position
  uses 238/3072, incorporating the original height-unit conversion.
- Opponent steering, airborne corrections and collision effects retain
  fractional increments when converted to the shorter step.
- Race clocks, selected event timers, AI decisions and respawn counters
  retain their original cadence through a pulse every sixth physics step.
- One-off time penalties use a separate clock entry, preserving the full
  penalty amount and preventing execution inside a replaced instruction.
- Rendering waits for Copper publication before reusing the previous
  display buffer. Graphics, Copper lists and DMA buffers remain in Chip RAM.

## Rendering optimizations

- Object and track points are transformed in batches using scaled index
  addressing, reducing repeated setup and per-point calls.
- Long polygon row interiors use aligned 32-bit writes, with the original
  word loop handling short spans and trailing words.
- Coefficient calculation uses unrolled loops with the original integer
  arithmetic and operation order.
- Two exact 65,536-entry angle tables use 256 KiB of Fast RAM. They are
  initialized once from the original integer routines. Seven coefficient
  calls use table lookups; the final call retains the original side results.
  If Fast allocation fails, the original angle calculation remains available.
- A 16-color mask table and fixed pixel routines replace instruction rewriting
  in the color-selection and pixel/word drawing paths. Color selection is
  stored in data pointers.

The 20 ms physics step, race timing and display-buffer synchronization remain
unchanged.

## Loader and memory

The patcher edits fixed offsets in the original raw-loader ADF. It does not
add an AmigaDOS executable or a startup-sequence.

The 134-byte boot extension starts at boot-relative `0x200`. It reserves
4096 bytes of Chip RAM at `0x181000` using Exec AllocAbs, then performs the
expanded `0x9c00`-byte Chip allocation for the initial load. The 4004-byte
runtime is stored at ADF offset `0xb720` and copied to the reserved area.
The boot extension also requests 256 KiB of Fast RAM for the angle tables.
CacheClearU runs before the copied code is executed.
This call requires Exec V37 or later.

The initial load begins at ADF offset `0x2c00`. The initial read and allocation
are both `0x9c00` bytes. Its original copier moves
relative bytes `0x78..0x8abb` to `0x4000`; the runtime starts beyond the copier
at relative `0x8b20` and ends within the initial-load allocation.

Failure of either required Chip allocation enters supervisor mode, disables DMA, displays a red
background and halts. Restart with the documented memory configuration.
The runtime and optional Fast table allocations last for the session.
The 4004-byte runtime leaves 92 bytes free in its 4096-byte reservation.

The source uses integer instructions, including 68020+ scaled index addressing
for 68060 geometry processing, with no FPU or MMU requirement.
The target is FS-UAE with PAL timing and a 68060; the fixed memory placement
and 20 ms frame budget form part of that configuration. See the
[FS-UAE profile](FS-UAE.md) for the emulator settings.

## Address mapping and patches

The main game block loads from ADF `0xdc00` to address `0xe700`.

```text
runtime address = ADF offset + 0xb00
runtime address = extracted game-block offset + 0xe700
```

[src/patches.json](src/patches.json) contains all 75 instruction patches,
expected and replacement bytes, address mappings, dispatch symbols and
payload hashes. All instruction addresses are even-aligned; words and
longwords use big-endian encoding. `BOOT_HEX` and `RUNTIME_HEX` in
[patch.py](patch.py) embed the helper code for standalone use.

| Content | Size | SHA-256 |
| --- | ---: | --- |
| Boot | 134 | `daf5903700c519d8785257dca9574a05af4974308fcc436cb57833ceac828492` |
| Runtime | 4004 | `ab92db5f86e2e7dcaf05fffc7ffcba5141ddf6affd750fc519011635397b4071` |

Full disk and ROM identifiers are in [FS-UAE.md](FS-UAE.md#checksums).

## Building from source

Running the patcher needs only Python and the original ADF. Rebuilding the
embedded assembly requires `vasmm68k_mot` with Motorola syntax and the
`-m68000 -Fbin` options. The geometry sources select the 68060 locally.

From this directory:

```sh
python3 -B scripts/build_patch.py "/path/to/Stunt Car Racer.adf" --check
```

The builder assembles `SCR_Boot.s` and `SCR_Runtime50Hz.s`, including the
player, opponent, geometry, span-fill, coefficient, angle and color routines.
It also assembles the five in-place replacements listed under
`assembly_patches` in [src/patches.json](src/patches.json), checking their
instruction bytes and preserved continuation against the original disk.

The builder checks payload sizes, hashes and the boot-copy contract. Build
files are written under `work/adf-patch-build/`. The `--check` option compares
the result with the embedded patch data without changing source files.
Use `--write` to regenerate that data after updating the manifest and
package version.

## Output protection and rollback

The patcher checks the original disk's SHA-256, each displaced instruction,
embedded payloads, loader-tail contents, boot checksum and output SHA-256.
It writes a temporary file and reads it back before publishing it atomically.
An existing destination is preserved unless `--force` is supplied. The
original file and its hard-link or symbolic-link aliases remain protected,
and symbolic-link output paths are rejected.

To restore the original game, quit the patched session and boot the untouched
original ADF with fresh emulator state. Loading a save state containing
patched RAM retains that patch, even after inserting a different floppy.
