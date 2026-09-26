# Patch details — 1.4.8

This release is primarily intended for emulation with PAL or NTSC timing, a 68060 CPU,
2 MiB Chip RAM and at least 1 MiB Fast RAM.

## Requirements

- Primarily for emulation: PAL or NTSC, a 68060 CPU, 2 MiB Chip RAM and at least 1 MiB Fast RAM.
  Computer Link needs PAL on both machines.
- Adjust Game Speed in Settings if the frame rate drops.
- On real hardware the release has been tested working on at least an
  Amiga 1200 + PiStorm32 Lite + Raspberry Pi 4B 1.8 GHz + Emu68 1.1 beta.1.
- The patcher checks the disk, not the machine configuration. The runtime
  needs its fixed 8 KiB Chip allocation at `0x181000`; allocation failure
  halts boot with a red screen. The Track Editor and Computer Link need
  416 KiB of Fast RAM; the angle tables use another 256 KiB when available.
  See [Loader and memory](#loader-and-memory).
- Keep DF0 writable for the editor's 32 track slots and custom-track records.
  For Save/Load → Disk, enable a second floppy drive and insert a separate
  writable ADF in DF1. The editor initializes a track disk only after
  confirmation; initialization erases that disk. Keep the game disk in DF0.

## Physics and rendering

Practice mode, computer-opponent and linked races use 50 Hz physics with a
selectable 20–30 ms simulation step (100–150%) and rendering at up to 50 FPS.
The achieved frame rate depends on the machine's Chip RAM access speed; see
[Late frames](#late-frames).

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

## Late frames

Each race step is the same fixed physics step. When a drawn frame covers two
or more vertical blanks, the following loop passes run up to three extra
steps without 3D drawing, pacing or display swap, so race time stays real.
Input, physics, the opponent, link service, lap clock, effects, sound and end
checks run on every step. On extra steps, smoke and particles advance their
motion, renewal and random numbers but are not drawn; the next drawn frame
shows them. The HUD and cockpit images are not drawn on extra steps either;
wheel heights and the turbo animation still advance, and the next drawn frame
draws the images before its display swap. Crane lifts are caught up the same way with their
fixed 20 ms step; race setup drawing is complete and does not add steps to
catch up. Time spent paused is not caught up. The vertical blank count is kept by
the editor module's interrupt call.

## PAL and NTSC

The boot measures the length of a display field from the beam counter once:
PAL fields end at line 311/312, NTSC fields at 261/262. The game keeps the
video standard the machine was started in.

- On PAL the display windows are unchanged: the loading screen and the game
  screens (menus, track preview, race, editor) use lines 60–259.
- On NTSC the same 200 lines are shown at lines 44–243, the standard NTSC
  area. The editor bootstrap sets the loading screen's window in the loader
  before it runs; a module hook at `0xedfc` sets the window and the sprite
  origin (`0x69ec4`) of the game screens. The Copper list is unchanged.
- The game clock counts vertical blanks. On NTSC it runs 60 physics steps per
  second, about 20% faster than PAL in real time. The lap clock still
  advances once every six steps, so lap times and records stay in PAL game
  time and are comparable with PAL.
- The boot intro is a 320 × 200 screen shown the same way in both standards.
- Computer Link timing requires PAL on both machines.

## Smoke and particles

Smoke and small particles move and renew on the original 120 ms simulation
step, with interpolated positions for drawing. Their clock, including smoke
animation, advances by the selected 20–30 ms Game Speed step. At 50 physics
steps per second, effects update every 120 ms at 100% and every 80 ms at 150%.

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

## Computer Link

The link module is a separate relocatable 68000 module, 16,384 bytes on disk
(8,414 bytes of code), loaded with the editor into its own 32 KiB Fast RAM
block. It checks the game code it hooks before installing anything.

- The Computer Link menu offers an explicit Host/Join choice and a bounded
  connection attempt. The serial interrupt owns the port while linked.
- Each machine sends a 32-byte frame with a CRC every 50 ms: its car state,
  a service time stamp and numbered reliable events (lap, race end, pause,
  resume, wreck, leave). Events are retransmitted until acknowledged.
- The remote car is interpolated between received samples using a 70 ms
  playback delay, including across track-piece boundaries. A gap of at least
  two seconds between samples decoded for presentation, such as during a long
  pause, resets the presentation timing and history.
- If no valid frame arrives for 2000 ms, or a reliable event remains
  unacknowledged for that long, the link closes and the race returns to the
  title screen. The serial connection remains serviced during a pause.
- At race start both machines exchange a settings contract and a session
  generation, then open the race together. At the end both wait, up to 30
  seconds, for the other's result; the Host settles the finishing order from
  the finish times, excluding paused time. Results and points then use the
  game's own link result transfer. Link races skip record saving.
- Car-to-car contact is disabled in linked races; three game hooks and a
  runtime routine clear the transient contact state.
- The link league selects the season's division from the season number, so
  the four seasons run Divisions 4 to 1. The solo league division is not
  changed.

## Rendering optimizations

- Object and track points are transformed in batches using scaled index addressing.
- Polygon filling uses aligned 32-bit writes for long spans and word writes
  for short spans and edges.
- Coefficients are calculated with unrolled integer loops.
- Two 65,536-entry angle lookup tables use 256 KiB of Fast RAM. If that
  allocation fails, angles are calculated directly.
- Color selection uses a 16-color mask table and data pointers to pixel
  and word drawing routines.
- HUD and cockpit images are converted once into a Fast RAM cache and drawn
  as 32-bit pairs: fully transparent pairs are skipped and fully opaque pairs
  are written without reading the screen. The screen result is the same as
  the original drawing; images that do not match the cache use the original
  routine.

## Rendering precision

Screen-point transforms retain full 32-bit products and round once to the
nearest pixel. Projection angles and distances interpolate between lookup-table
entries. Projection distances are rounded and saturate at 32767. The shared
physics angle and distance routines keep their existing arithmetic.

## Loader and memory

The patcher modifies the game's raw-loader ADF at fixed offsets.

Boot retains the operating system's boot-task stack for OS calls, avoiding
the small stack area inside the bootblock. The intro uses its own stack
and restores the boot-task stack when it returns; the game's later stack
switches are unchanged.

A 320-byte boot extension at `0x200` installs the game runtime and loads the
intro. The 6734-byte runtime is stored at ADF offset `0xb720` and copied into
a 8192-byte Chip RAM reservation at `0x181000`. The editor extends the initial load at ADF offset `0x2c00` to a
`0xb000`-byte Chip allocation. The loader clears
the CPU caches before executing copied code.

The runtime and optional 256 KiB Fast angle tables remain allocated for the
session. The Track Editor and Computer Link modules need 384 KiB and 32 KiB of
Fast RAM; without them the game runs without the editor and the link. All
Fast RAM is allocated at boot, 672 KiB in total. Failure of a required game
Chip allocation halts boot with a red screen. Restart with the documented
memory configuration.

The code uses integer instructions and requires neither an FPU nor an MMU.

## In-game track editor

The editor is a separate relocatable module: 74,854 bytes of code and data,
loaded from ADF offset `0x76000` in a 91,648-byte transfer that also carries
the link module. Its bootstrap is 762 bytes at ADF offset `0xd800`. It reserves
384 KiB of Fast RAM and 99,840 bytes of persistent Chip RAM for loading, disk
I/O and display support. The track preview marks the finish row with a small
arrow.
Track projects use two guarded storage banks with 32 slots each. Draft/Ready
state, names and custom-track records persist on the game disk. A separate
DF1 track disk supports import/export. See [editor controls](README.md#track-editor-beta).

The bootstrap stores Exec `AttnFlags` and the measured video standard in the module. After installing its game
hooks and around each editor disk transfer, the module pushes and invalidates
the CPU caches with the instructions of the detected processor.


## Boot intro

The intro uses a 320 × 200 screen that fits both PAL and NTSC displays. The
flag is drawn with edge markers and 32-bit fills, and only the changed
areas are copied to the screen, so the wave and scroller update every frame.
The flagpole is a shaded white Finnish pole with a gilded knob.
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

[src/patches.json](src/patches.json) lists the 108 game instruction patches,
boot and loader patches, expected and replacement bytes, address mappings
and payload hashes. The `editor.changes` list is applied after the guarded
performance layer; its expected bytes refer to that intermediate disk. Words and longwords use big-endian encoding.
[patch.py](patch.py) embeds the boot, runtime, intro and editor/link overlay for standalone use.

| Content | Size | SHA-256 |
| --- | ---: | --- |
| Boot | 320 | `b178776797c59302dd0f5afcdaf69ac3041b8641bcee4f07d7717fd3b971d9e7` |
| Runtime | 6734 | `95ccd057ccbdd4edf0f83d74f8c15a44044948c0f56c97b42c348acd4bfeef44` |
| Intro | 5818 | `02c83ae864acf7bde125d14d37026fa23d1b158edbb305aee29f653afa02f550` |

## Checksums

Both ADFs are 901,120 bytes. The identified source dump shows QUARTEX text in
the track introduction; support is limited to the exact checksum below.

| File | SHA-256 |
| --- | --- |
| Supported Stunt Car Racer ADF (Quartex-crack) | `548fd106cd62f2d80159d48ddd5293d8b22b6b17f80c17a84a61d75f5c8a9e06` |
| Patched ADF (1.4.8, up to 50 FPS Practice, computer-opponent and linked races) | `284891af5536001f8bae2584cd792cc42adbad2be13983658fd4476ba8cd416c` |

The patcher verifies the whole original disk, displaced instructions,
embedded payloads, loader-tail contents, boot checksum and whole output.
It reads back the complete temporary file before publishing it. A different
dump, modified save disk, truncated image or already-patched disk is rejected.

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
