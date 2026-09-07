# Patch details — 0.3.0

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

## Loader and memory

The patcher edits fixed offsets in the original raw-loader ADF. It does not
add an AmigaDOS executable or a startup-sequence.

The 118-byte boot extension starts at boot-relative `0x200`. It reserves
4096 bytes of Chip RAM at `0x181000` using Exec AllocAbs, then performs the
original `0x9800`-byte Chip allocation for the initial load. The 2738-byte
runtime is stored at ADF offset `0xb720` and copied to the reserved area.
CacheClearU runs before the copied code is executed.
This call requires Exec V37 or later.

The initial load begins at ADF offset `0x2c00`. Its original copier moves
relative bytes `0x78..0x8abb` to `0x4000`; the runtime starts beyond the copier
at relative `0x8b20` and ends within the initial-load allocation.

Allocation failure enters supervisor mode, disables DMA, displays a red
background and halts. Restart with the documented memory configuration.
The runtime allocation lasts for the session.

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

[src/patches.json](src/patches.json) contains all 40 instruction patches,
expected and replacement bytes, address mappings, dispatch symbols and
payload hashes. All instruction addresses are even-aligned; words and
longwords use big-endian encoding. `BOOT_HEX` and `RUNTIME_HEX` in
[patch.py](patch.py) embed the helper code for standalone use.

| Content | Size | SHA-256 |
| --- | ---: | --- |
| Boot | 118 | `5914198f75b76891ad43cc5b60111971c6337b22de3f94257350b92a46d94703` |
| Runtime | 2738 | `526c05b3894ec650f1529df7d9214c80caa81b7f46a7d48b70bdc1626bc70eb3` |

Full disk and ROM identifiers are in [FS-UAE.md](FS-UAE.md#checksums).

## Building from source

Running the patcher needs only Python and the original ADF. Rebuilding the
embedded assembly requires `vasmm68k_mot` with Motorola syntax and the
`-m68000 -Fbin` options. The geometry sources select the 68060 locally.

From this directory:

```sh
python3 -B scripts/build_patch.py "/path/to/Stunt Car Racer.adf" --check
```

The builder assembles `SCR_Boot.s` and `SCR_Runtime50Hz.s`, which includes
`SCR_Player20ms.s`, `SCR_Opponent20ms.s`, `SCR_ObjectSetup060.s` and
`SCR_TransformPoints060.s`. It checks source bytes, sizes,
hashes and the boot-copy contract against the manifest. Build files are
written under `work/adf-patch-build/`. The `--check` option compares the
result with the embedded patch data without changing source files.
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
