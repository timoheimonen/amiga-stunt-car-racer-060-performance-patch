# Patch details — 1.6.1

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
- The [WHDLoad install](#whdload-install) needs a 68060, 2 MiB Chip RAM, at
  least 2 MiB Fast RAM and WHDLoad 17 or later.
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

The editor is a separate relocatable module: 77,190 bytes of code and data,
loaded from ADF offset `0x76000` in a 93,696-byte transfer that also carries
the link module. Its bootstrap is 762 bytes at ADF offset `0xd800`. It reserves
384 KiB of Fast RAM and 101,888 bytes of persistent Chip RAM for loading, disk
I/O and display support. The track preview marks the finish row with a small
arrow.
Track projects use two guarded storage banks with 32 slots each. Draft/Ready
state, names and custom-track records persist on the game disk. A separate
DF1 track disk supports import/export. See [editor controls](README.md#track-editor).

The patched disk contains the Ready track BUILD in save slot 01, written as a
first save (one record and both directory copies) without lap records.
Append previews of straight sections with a height profile place the camera
at the side. Q/W turn the endpoint view around the endpoint and the preview
around its section in 45-degree steps; A/Z scale the endpoint camera's
distance or the preview's focal length in five steps. The preview camera's
height search ends on a narrow bracket and is bounded, so no view can stall
the editor.

The bootstrap stores Exec `AttnFlags` and the measured video standard in the module. After installing its game
hooks and around each editor disk transfer, the module pushes and invalidates
the CPU caches with the instructions of the detected processor.


## Boot intro

The intro uses a 320 × 200 screen that fits both PAL and NTSC displays. The
flag is drawn with edge markers and 32-bit fills, and only the changed
areas are copied to the screen, so the wave and scroller update every frame.
The flagpole is a shaded white Finnish pole with a gilded knob.
Click a mouse button to continue to the game.

On a 68060 whose FPU is enabled at boot, the intro is skipped and the game
loads directly. Kickstart 3.1 cannot run the 68060 FPU safely without
68060.library, which a floppy boot does not load; 68060 boards therefore
disable the FPU at reset. The intro reads the processor configuration
register and returns before any operating system call when the FPU is
enabled. With the FPU disabled, and on processors without that register, the
intro is shown as before.

## Player-name screen

The prompt reads `NAME? OR PRESS FIRE TO CONTINUE`. Fire supplies `racer`
when the name is empty and preserves a typed name.

## WHDLoad install

`patch.py --whdload [DIRECTORY]` (default: `StuntCarRacerPerf` beside the
original ADF) writes the patched ADF as the disk image
`StuntCarRacerPerf.disk` together with a WHDLoad slave, a Workbench project
icon and a drawer icon for the directory. Use: [WHDLoad install](WHDLOAD.md). Slave source:
[src/SCR_WHDLoad.s](src/SCR_WHDLoad.s).

| File | Size | SHA-256 |
| --- | ---: | --- |
| `StuntCarRacerPerf.slave` | 4500 | `edcc0f6f3980758c3e01c1590f3e179430a820fff37ac09498c882ca5a26767c` |
| `StuntCarRacerPerf.info` (project, default tool `WHDLoad`) | 301 | `f4ecc86b29c2f349b47ead1038b0662a33016dae1fa683785a28f8452e0a08ca` |
| `<directory>.info` (drawer) | 264 | `58b65ed8043f8bea23264176586f8023d27c9c0b413c657fcb1222b93512b636` |
| `StuntCarRacerPerf.disk` | 901,120 | the patched ADF, see [Checksums](#checksums) |

The names differ from other WHDLoad installs of the game (`StuntCarRacer.slave`,
`StuntCarRacer.info`, `Disk.1`; AmigaDOS names ignore case), so both can share
one directory. `resload_DiskLoad` reads only images named `Disk.N`, so the
slave reads its image with `resload_LoadFileOffset`.

The slave (WHDLoad slave version 17, base memory `0x200000`, expansion memory
`0xaa000`, quit key F10) runs the disk's own boot block on a minimal
`exec.library` and `trackdisk.device`. The boot code, the runtime installer
and the editor bootstrap run unchanged: `Forbid`, `Permit`, `SuperState`,
`AllocMem`, `AllocAbs`, `FreeMem`, `DoIO` (`CMD_READ`, `TD_MOTOR`) and
`CacheClearU` are provided, and `AttnFlags` comes from WHDLoad. Any other
call ends WHDLoad with an operating system emulation error naming the call.

- Chip memory comes from the base memory: ordinary allocations from
  `0x80000` below the boot block at `0x8c000`, `MEMF_REVERSE` allocations from
  the top down to `0x190000`, and `AllocAbs` reserves the runtime at
  `0x181000`. Fast memory comes from the expansion memory: 256 KiB angle
  tables, the 384 KiB Track Editor and the 32 KiB Computer Link module. Its
  last 8 KiB are the slave's stack during the boot, as the editor's Chip
  buffer takes the top of the base memory.
- The slave checks the long-word sums of the boot block, the first load
  (`0x2c00`, `0xb000` bytes) and the main program (`0xdc00`, `0x64a00` bytes)
  and the bytes at each place it patches. Any other image ends with
  WHDLoad's message about damaged files or an unsupported version.

| Place | Original | WHDLoad |
| --- | --- | --- |
| Boot block `+0x340` | call of the intro (`+0x286`) | call of the runtime installer (`+0x24c`); the intro is skipped |
| Boot block `+0x7c` | `LEA +0x200,SP` / `JMP (A3)` | jump to the slave, which replaces the loader's driver and then sets the same stack and jumps |
| First load `+0x570` (loader `0x44f8`) | loader floppy driver | slave driver |
| `0x62e86` | game floppy driver | slave driver, installed after the loader has read and checked the main program |

The slave driver keeps the original interface: D0 drive (bits 0–1) and
format (bit 15), D1 first sector, D2 sector count, D3 read or write, A0 data;
D0 returns 0 or error 28 (write-protected), 29 (no disk) or 30 (range, or a
save file of the wrong size). Only the game disk in DF0 in the standard format
exists; DF1 returns 29. Reads of the image go through `resload_LoadFileOffset`.

The disk areas the game and the Track Editor write are files in the install
directory. The editor's two copies of each area are one file.

| Disk area (sectors) | File | Size | Without the file |
| --- | --- | ---: | --- |
| Editor slot *n* = 0–31: track `1210+4n`, copy `1342+4n` | `TrackNN.sct` (NN = *n*+1) | 1024 | game disk sectors |
| Records of slot *n*: `1212+4n`, copy `1344+4n` | `TrackNN.rec` | 1024 | game disk sectors |
| Editor slot index: `1474`, copy `1485` | `TrackIndex` | 1536 | game disk sectors |
| Season save index: `22` | `SaveIndex` | 512 | empty sectors |
| Season save *k* = 0–29: `23+k` | `SaveNN` (NN = *k*+1) | 512 | empty sectors |

A write builds the whole file from its current contents, or from the disk
without a file, and saves it with `resload_SaveFile`; an unchanged file is not
written again. Writes elsewhere return error 28, so the image is never written.
The season saves were on a separate formatted disk on floppy, so without a
file they read as a new, empty save disk.

## Address mapping and patches

The main game block loads from ADF `0xdc00` to address `0xe700`.

```text
runtime address = ADF offset + 0xb00
runtime address = extracted game-block offset + 0xe700
```

[src/patches.json](src/patches.json) lists the 108 game instruction patches,
boot and loader patches, expected and replacement bytes, address mappings
and payload hashes. The `editor.changes` list is applied after the guarded
performance layer; its expected bytes refer to that intermediate disk. The
`whdload` section describes the WHDLoad install. Words and longwords use big-endian encoding.
[patch.py](patch.py) embeds the boot, runtime, intro, editor/link overlay and
the WHDLoad slave and icons for standalone use.

| Content | Size | SHA-256 |
| --- | ---: | --- |
| Boot | 320 | `10f67db818b945e70ebc2ed173584f016ca19e2cb5a253a5a83fed0c9457e453` |
| Runtime | 6734 | `95ccd057ccbdd4edf0f83d74f8c15a44044948c0f56c97b42c348acd4bfeef44` |
| Intro | 5922 | `b7ad19f33e1debe3a5c231df6742479c01aecab0ab3b588c26b776a9e918f7ca` |

## Checksums

Both ADFs are 901,120 bytes. The identified source dump shows QUARTEX text in
the track introduction; support is limited to the exact checksum below.

| File | SHA-256 |
| --- | --- |
| Supported Stunt Car Racer ADF (Quartex-crack) | `548fd106cd62f2d80159d48ddd5293d8b22b6b17f80c17a84a61d75f5c8a9e06` |
| Patched ADF (1.6.1, up to 50 FPS Practice, computer-opponent and linked races) | `42c6e282926e785453d05bef51b71c0baf9b6c167e3fcb7296e1afe99f426ac3` |

The patched ADF is the same as in 1.5.0; the WHDLoad install uses it as
`StuntCarRacerPerf.disk`.

The patcher verifies the whole original disk, displaced instructions,
embedded payloads, loader-tail contents, boot checksum and whole output.
It reads back the complete temporary file before publishing it. A different
dump, modified save disk, truncated image or already-patched disk is rejected.

## Included sources

`src/` contains the assembly sources, including the WHDLoad slave, and the
patch manifest. Applying the patch or writing the WHDLoad install requires
only `patch.py`, Python 3.8+ and the supported original ADF; no assembler is
needed.

## Output protection and rollback

The patcher verifies the source disk, replacement locations, embedded code,
boot checksum and complete output hash. It reads back a temporary output
before publishing it atomically. Existing output requires `--force` to replace.
The source file and its aliases are protected; symbolic-link output paths
are rejected.

A WHDLoad install is written only to a new directory and a new drawer icon:
both are created exclusively, never replacing an existing file or directory,
and a failed install removes what it created. `--force` does not apply.

To restore the original game, quit the patched session and boot the untouched
original ADF with fresh emulator state. A save state containing patched RAM
continues to use the patch regardless of the inserted floppy.
