# Patch details — 1.3.0

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

## Smoke and particles

Smoke and small particles move and renew on the original 120 ms step, with
interpolated positions for 50 Hz drawing. Smoke animation keeps its original
frame clock. This prevents effects from advancing six times too quickly.

## Settings

Game Speed scales both cars' physics, including yaw correction. Crane movement
and legacy timer pulses keep their timing. AI Difficulty independently raises
ordinary opponent target speeds, retaining flagged special-piece targets and
moving-bridge targets. Positive signed speed overflow saturates at 32767 when
AI Difficulty exceeds 100%. The engine, braking and track still determine
achieved pace; Practice has no opponent.

Infinite Boost at Yes bypasses the player's reserve check and consumption,
while preserving turbo power and input conditions. It neither refills the
reserve nor advances its consumption counter. No resumes normal consumption.

Disable Damage at Yes prevents new player damage, crack growth and damage
holes. Existing damage remains; No restores normal damage handling.

Settings persist between races and reset on boot. Original-track records share
the same table across settings. Custom-track records require Game Speed 100%,
Infinite Boost No and Disable Damage No. See [controls](README.md#settings).
Five guarded runtime entry overlays dispatch to the speed routines. The yaw
instruction overlay preserves the existing damping continuation. Six menu
hooks, two AI hooks, one boost hook and five damage hooks install the Settings
features. Two player-name hooks add Fire continuation and the name-screen text.
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

## Rendering precision

Screen-point transforms retain full 32-bit products and round once to the
nearest pixel. Projection angles and distances interpolate between lookup-table
entries. Projection distances are rounded and saturate at 32767. The shared
physics angle and distance routines keep their existing arithmetic.

## Loader and memory

The patcher modifies the game's raw-loader ADF at fixed offsets.

A 320-byte boot extension at `0x200` installs the game runtime and loads the
intro. The 6528-byte runtime is stored at ADF offset `0xb720` and copied into
a 8192-byte Chip RAM reservation at `0x181000`. The editor extends the initial load at ADF offset `0x2c00` to a
`0xb000`-byte Chip allocation. The loader clears
the CPU caches before executing copied code.

The runtime and optional 256 KiB Fast angle tables remain allocated for the
session. Failure of a required game Chip allocation halts boot with a red
screen. Restart with the documented memory configuration.

The code uses integer instructions and requires neither an FPU nor an MMU.

## In-game track editor

The editor is a separate relocatable module: 72,858 bytes of code and data,
loaded from ADF offset `0x76000` in a 73,216-byte transfer. Its bootstrap is
436 bytes at ADF offset `0xd800`. It reserves 384 KiB of Fast RAM and 81,408
bytes of persistent Chip RAM for loading, disk I/O and display support.
Track projects use two guarded storage banks with 32 slots each. Draft/Ready
state, names and custom-track records persist on the game disk. A separate
DF1 track disk supports import/export. See [editor controls](README.md#track-editor).

The loader installs the editor hooks only after checking their expected bytes.
CIA initialization runs before game interrupts are enabled, preventing an early
key event from interrupting initialization and leaving its acknowledgement stuck.
The normal keyboard acknowledgement routine remains in use.


## Boot intro

Click a mouse button to continue to the game.

## Player-name screen

The prompt reads `NAME? OR PRESS FIRE TO CONTINUE`. Fire supplies `racer`
when the name is empty and preserves a typed name.

## Address mapping and patches

The main game block loads from ADF `0xdc00` to address `0xe700`.

```text
runtime address = ADF offset + 0xb00
runtime address = extracted game-block offset + 0xe700
```

[src/patches.json](src/patches.json) lists the 105 game instruction patches,
boot and loader patches, expected and replacement bytes, address mappings
and payload hashes. The `editor.changes` list is applied after the guarded
performance layer; its expected bytes refer to that intermediate disk. Words and longwords use big-endian encoding.
[patch.py](patch.py) embeds the boot, runtime, intro and editor overlay for standalone use.

| Content | Size | SHA-256 |
| --- | ---: | --- |
| Boot | 320 | `041c4528304e2905a50150acdb0f910fcdbab6086993a1154a78e35704bb923f` |
| Runtime | 6528 | `200aef229ae49838e93ef44984daa9e1887af081bd264b79315bd9f992d1052d` |
| Intro | 5480 | `843c61b14e467a8922a611578f8ba06a159d40612dfba72c9a3c0968976f4bf8` |

Disk and ROM identifiers are in [FS-UAE.md](FS-UAE.md#checksums).

## Included sources

`src/` contains the assembly sources and patch manifest. Applying the patch
requires only `patch.py`, Python 3.8+ and the supported original ADF;
no assembler is needed.

## Output protection and rollback

The patcher verifies the source disk, replacement locations, embedded code,
boot checksum and complete output hash. It reads back a temporary output
before publishing it atomically. Existing output requires `--force` to replace.
The source file and its aliases are protected; symbolic-link output paths
are rejected.

To restore the original game, quit the patched session and boot the untouched
original ADF with fresh emulator state. A save state containing patched RAM
continues to use the patch regardless of the inserted floppy.
