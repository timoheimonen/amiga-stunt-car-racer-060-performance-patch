# Patch details - 2.3.2

This release is a [WHDLoad install](#whdload-install), primarily intended for emulation
with PAL or NTSC timing, a 68060 CPU, 2 MiB Chip RAM and at least 2 MiB Fast RAM.

## Requirements

- Primarily for emulation: PAL or NTSC, a 68060 CPU, 2 MiB Chip RAM, at least 2 MiB Fast RAM
  and WHDLoad 17 or later. Computer Link needs PAL on both machines.
- Adjust Game Speed in Settings if the frame rate drops.
- On real hardware, earlier releases have been tested working on at least an
  Amiga 1200 + PiStorm32 Lite + Raspberry Pi 4B 1.8 GHz + Emu68 1.1 beta.1.
- The patcher checks the disk image, not the machine configuration. WHDLoad
  provides the memory and stops if it cannot. See
  [Loader and memory](#loader-and-memory).
- Keep the install directory on a writable volume for the season saves and
  for the `tracks` drawer, which holds the editor's 512 track slots and the
  custom-track records.

## Physics and rendering

Practice mode, computer-opponent and linked races use 50 Hz physics with a
selectable 20-30 ms simulation step (100-150%) and rendering at up to 50 FPS.
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

With **Timing Original** a race uses the original game loop instead; see
[Timing](#timing).

## Late frames

Each race step is the same fixed physics step. When a drawn frame covers two
or more vertical blanks, the following loop passes run up to three extra
steps without 3D drawing, pacing or display swap, so race time stays real.
Input, physics, the opponent, link service, lap clock, effects, sound and end
checks run on every step. On extra steps, smoke and particles advance their
motion, renewal and random numbers but are not drawn; the next drawn frame
shows them. The HUD and cockpit images are not drawn on extra steps either;
wheel heights and the turbo animation still advance, and the next drawn frame
draws the images before its display swap. The crane chains are skipped in the
same way: their length still advances, and the next drawn frame draws them
again. Crane lifts are caught up the same way with their
fixed 20 ms step; race setup drawing is complete and does not add steps to
catch up. Time spent paused is not caught up. The vertical blank count is kept by
the editor module's interrupt call.

The race loop does not wait for the vertical blank after it requests the
display swap. The next frame's game logic and geometry do not draw, so they run
meanwhile, and the wait is made before the first drawing of that frame, the
background fill. Frames are therefore shown as soon as they are ready, one or
more vertical blanks apart. Every other display swap waits as before.

## PAL and NTSC

The boot measures the length of a display field from the beam counter once:
PAL fields end at line 311/312, NTSC fields at 261/262. The game keeps the
video standard the machine was started in.

- On PAL the display windows are unchanged: the loading screen and the game
  screens (menus, track preview, race, editor) use lines 60-259.
- On NTSC the same 200 lines are shown at lines 44-243, the standard NTSC
  area. The editor bootstrap sets the loading screen's window in the loader
  before it runs; a module hook at `0xedfc` sets the window and the sprite
  origin (`0x69ec4`) of the game screens. The Copper list is unchanged.
- The game clock counts vertical blanks. On NTSC it runs 60 physics steps per
  second, about 20% faster than PAL in real time. The lap clock still
  advances once every six steps, so lap times and records stay in PAL game
  time and are comparable with PAL.
- Computer Link timing requires PAL on both machines.

## Smoke and particles

Smoke and small particles move and renew on the original 120 ms simulation
step, with interpolated positions for drawing. Their clock, including smoke
animation, advances by the selected 20-30 ms Game Speed step. At 50 physics
steps per second, effects update every 120 ms at 100% and every 80 ms at 150%.

## Settings

Game Speed scales both cars' physics, including yaw correction. Crane movement
and legacy timer pulses keep their timing. AI Difficulty independently raises
ordinary opponent target speeds, retaining flagged special-piece targets and
moving-bridge targets. Positive signed speed overflow saturates at 32767 when
AI Difficulty exceeds 100%. The engine, braking and track still determine
achieved pace. Practice has no opponent; a custom track's Race uses the
opponent setup of the Little Ramp.

Infinite Boost at Yes bypasses the player's reserve check and consumption,
while preserving turbo power and input conditions. It neither refills the
reserve nor advances its consumption counter. No resumes normal consumption.

Disable Damage at Yes prevents new player damage, crack growth and damage
holes. Existing damage remains; No restores normal damage handling.

Settings persist between races and reset on boot. Original-track records share
the same table across settings; Timing Original sets none. Custom-track records
require Game Speed 100%, Infinite Boost No, Disable Damage No and Timing
Performance. See [controls](README.md#settings).
Five guarded runtime entry overlays dispatch to the speed routines. The yaw
instruction overlay preserves the existing damping continuation. Six menu
hooks, two AI hooks, one boost hook and five damage hooks install the Settings
features. Two player-name hooks add the default name and the name-screen text.
`src/patches.json` records their expected and replacement bytes.

## Timing

Settings row 5 selects **Timing Performance** (default) or **Timing Original**
for the session. Original keeps the 50 Hz runtime inactive for the whole race:

- A runtime overlay at `frame_gate` in the first race frame calls
  `original_gate` ([src/SCR_Timing.s](src/SCR_Timing.s)). In Original it
  selects the original 120 ms frame: every gated hook runs its displaced
  original instructions, the loop waits six vertical blanks, and the impact
  cooldown and smoke phase advance once per loop as in the original game.
- The yaw correction hook at `0x611ce` tests the runtime state first: active
  races use the 20 ms correction, Original adds the whole original correction
  once per loop. Apart from this test, Performance runs the new code only when
  the runtime starts a race or a crane restart, and when a time is compared
  with the records.
- Two hooks at `0x5f18c` and `0x5f1f6`, where a lap and a race time are
  compared with the track records, answer "not faster" in Original, so the
  original tracks keep their records. Custom tracks keep session times.
- Game Speed shows 100% and cannot be changed in Original; the stored Game
  Speed is unchanged.
- A Computer Link role keeps the race on Performance, with the stored Game
  Speed.

The new code is appended to the runtime, so no earlier runtime address moves.
The setting is the former padding byte of the speed settings at `0x182447`.

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

In races the projection keeps the bits the game drops before it takes a
point's two view angles. Six module hooks (`0x601f0`, `0x6249c`, `0x624c2`,
`0x65f90`, `0x65fb4`, `0x66044`) replace that step for near and far points:

- The point's X/Z distance to the camera includes four bits of the camera
  position's fraction, 1/16 of a unit; the game uses whole units.
- The vertical angle comes from the whole height difference and a distance in
  1/16 units; the game drops the two low bits of the difference, three for far
  points.
- Each angle is rounded to its quarter pixel instead of truncated.

The code is in [src/editor/projection.s](src/editor/projection.s) and runs in
Fast RAM with copies of the game's two projection tables, 4,098 and 4,096
bytes inside the module's Fast RAM allocation. The values the game keeps
have their meaning unchanged: the stored distance is still in whole units, half
units for far points. The track preview's projection runs the game's own code;
it shares the edge clipper below.

Where an edge crosses the screen border, the clipper at `0x668a8` computes the
crossing point as distance * other / this. The game divides first and
multiplies by the truncated quotient; eight 36-byte patches multiply first and
round. The module checks the game's code at each of the eight places and
writes the patches in memory, so the disk bytes there are unchanged.
`editor.projection` in `src/patches.json` lists them.

## Loader and memory

The patcher modifies the game's raw-loader ADF at fixed offsets. The result is
the disk image of the [WHDLoad install](#whdload-install), and the slave runs
its boot block.

Boot retains the operating system's boot-task stack for OS calls, avoiding
the small stack area inside the bootblock. The game's own stack is 1,024 bytes
in the Track Editor module's Fast RAM allocation instead of Chip RAM; the module
checks the game's two stack loads before it redirects them.

A 320-byte boot extension at `0x200` installs the game runtime. The 7142-byte
runtime is stored at ADF offset `0xb720` and copied into
a 8192-byte Chip RAM reservation at `0x181000`. The editor extends the initial load at ADF offset `0x2c00` to a
`0xb000`-byte Chip allocation. The loader clears
the CPU caches before executing copied code.

The runtime and optional 256 KiB Fast angle tables remain allocated for the
session. The Track Editor and Computer Link modules need 416 KiB and 32 KiB of
Fast RAM. All Fast RAM is allocated at boot, 704 KiB in total, from WHDLoad's
expansion memory. Failure of a required game Chip allocation halts boot with a
red screen. Restart with the documented memory configuration.

The code uses integer instructions and requires neither an FPU nor an MMU.

## In-game track editor

The editor is a separate relocatable module: 110,738 bytes of code and data,
loaded from ADF offset `0x76000` in a 127,488-byte transfer that also carries
the link module. Its bootstrap is 766 bytes at ADF offset `0xd800`. It reserves
416 KiB of Fast RAM and 135,680 bytes of persistent Chip RAM for loading, file
I/O and display support. It runs relocated in Fast RAM and addresses game memory
with absolute operands only. The track preview marks the finish row with a small
arrow. Use: [Track Editor manual](docs/track-editor.md).

Custom tracks are files in the install's `tracks` drawer, 512 slots:
`tracks/Track001.sct` to `tracks/Track512.sct`, and the records of a track in
the `.rec` file of the same name. A track file is an IFF `FORM SCTF` with the
chunks `TRAK` (the track model), `STAT` (the stored Draft/Ready class) and
`CRC `; a records file is a `FORM SCTT` with `RKEY`, `NORM`, `SUPR` and `CRC `.
A file has at most 4096 bytes, and a Save keeps chunks it does not know. The
[Track File Format](docs/track-format.md) describes both byte by byte. The
editor reads and writes each file whole through the slave's
[file service](#whdload-install). One listing of `tracks` per session builds
the slot list in Fast RAM, and only the listed files are read; a Save updates
its row. Before the first write of a session the editor checks that `tracks`
is a directory.

The module carries the Ready tracks BUILD, BUILD 2 and BUILD 3 as track files
(548, 724 and 676 bytes). Without a file in `tracks`, slots 1-3 hold them.

Before the first title menu of a session one listing of the install directory
looks for the files of versions 1.6.0 to 2.2.0: `Track01.sct` to
`Track32.sct` (`SCES` versions 1 and 2, 1024 bytes), `Track01.rec` to
`Track32.rec` (`SCER` version 1, 1024 bytes) and `TrackIndex`. Only this
import reads them. Unless `tracks/Imported` says the question was answered,
the game asks in its own menu; Practise offers the row Import Old Tracks while
old files remain. An old track keeps its number unless its slot holds a track
or records file, and then goes to the first free slot; a track already in
`tracks` with the same identity and records key is not written again, and
into existing records of the same track only the better old times go. Every
written file is read back and compared, and a difference stops the import
without the deletion question. The marker is written before a deletion, which
takes only the old files whose tracks or records are now in `tracks`, and
`TrackIndex`, and leaves delete-protected files.
Practise shows Custom Tracks and Track Editor only in single-player games:
with more drivers (`0x5eb76`) or a Computer Link role (`0x57c3c`) the original
division menu remains.

After a custom track a menu offers Practise, Race and Cancel. Race runs the
game's own race against a computer driver 0-10, chosen with the game's random
byte. The original opponent setup runs with track 0 (`0x1ca33` is 0 on custom
tracks), so the opponent gets the Little Ramp's speed limits, and the AI
Difficulty hooks apply as on the original tracks. A module hook at `0x5cfee`,
Practise's race call, saves the race mode `0x1ca22`, the opponent driver
`0x1ca29`, the player index `0x5eb79` and the damage holes `0x1c9cf`, starts a
race with all ten damage holes left, as at a new game, and restores the four
bytes after the race. The lap hook adds each lap to the race time as the
original race does, without the season's own best times. A won race is
compared with the track's race record, which the record file already holds
next to the lap record.

A track has up to 78 road pieces. Tracks of up to 64 pieces are stored
exactly as in 2.0.0. A record's track identity has 32 bytes and 4 per piece:
the first 288 bytes keep their place, and the rest uses bytes 2.0.0 kept zero,
so the records of a track of up to 64 pieces are unchanged.

The 3D view shows rows 32-175 of its surface at the top of the screen. Below it
a Copper tail shows the bar, a bitmap of its own in Chip RAM. Three moves at the
end of the game's list jump to the tail, and they change only between frames.
The bar is one table of pages and rows, and a paint draws only the rows that
changed.

The vertical blank keeps the mouse pointer and records one left press. The main
loop acts on the press, so a click runs the same handlers as its key, and it
cannot overtake a key that is already queued. A click during a long redraw is
dropped.

The camera is an eye and two angles, 512 steps a turn, and only the player moves
it. While it moves, the view is drawn as road edges and the map outline. A
piece with every vertex outside one side of the view is skipped. A 2048-byte
field, built from the start piece or the far side of a gap, holds a distance to
that goal for every heading and cell, and the choice lines read it. A test drive
runs a Practise race on the track in memory, without its menus, and writes no
file and no lap record.

Del in the middle of a track removes one section and leaves a gap, which the
choices then lead to. Finish searches from the open end, then from ends with
one, two and more sections taken off, with a weighted A* search over the same
choices: map, height limits, the piece limit and the road already built. Its
search state borrows the depth buffer, which the next full render clears. The
sections taken off and added are one undo step.

The bootstrap stores Exec `AttnFlags` and the measured video standard in the
module. After installing its game hooks and after each file access, the module
pushes and invalidates the CPU caches with the instructions of the detected
processor. After each access it runs the game's CIA setup at `0xee8a` again
and queues the key changes its own input layer has not seen, so a key marked
up while WHDLoad showed the system (see [WHDLoad install](#whdload-install))
ends its hold and its next press counts.


## Boot intro

The disk image still holds the boot intro of the performance layer, but the
WHDLoad slave does not call it: the game starts at its loading picture.

## Player-name screen

The prompt reads `NAME? OR FIRE/RETURN TO PROCEED`, and its edition line names
the version: `PERFORMANCE EDITION 2.3.2`. Fire, Return or the keypad Enter
supplies `racer` when the name is empty and preserves a typed name.

## Keyboard acknowledge

The game acknowledges each key from the CIA-A serial interrupt: it holds the
acknowledge line, starts CIA-B timer B and marks the acknowledge busy at
`0xf0a8`; the timer interrupt releases the line and clears the mark. The
game's CIA setup at `0xee8a` releases the line and stops timer B. A key
pressed while the game loads is acknowledged as soon as interrupts are
enabled, just before that setup runs, so the mark stayed set and no later
key was acknowledged: the keyboard no longer responded in the menus. A module
hook at `0xee8a` runs the original setup unchanged and then clears the mark.
The disk bytes at `0xee8a` are unchanged.

## WHDLoad install

`patch.py ORIGINAL [DIRECTORY]` (default: `StuntCarRacerPerf` beside the
original ADF) writes the patched game as the disk image
`StuntCarRacerPerf.disk` together with a WHDLoad slave, a Workbench project
icon, a drawer icon for the directory and the empty `tracks` drawer with its
icon. Use: [WHDLoad install](WHDLOAD.md). Slave source:
[src/SCR_WHDLoad.s](src/SCR_WHDLoad.s).

| File | Size | SHA-256 |
| --- | ---: | --- |
| `StuntCarRacerPerf.slave` | 3796 | `ff3e1a96e73d18684237d9e6e41f0f56f59388ff25ac091f368e0450ab4f1a0b` |
| `StuntCarRacerPerf.info` (project, default tool `WHDLoad`) | 299 | `ebeebfc42d86895c9ce954cf39e3329e99b191e2d4e501158bd6b81f19c31e5e` |
| `<directory>.info` (drawer) | 264 | `c6695dc18210c72a672c2e20f1fba7b8f5036e6c2513e7f84772d7cd84072e88` |
| `tracks` | | empty drawer |
| `tracks.info` (drawer, window lists all files by name) | 264 | `dd3f7cb84a7aa483d9f9ea1d38db77b407f320c3fba70c1235576f9e68ee3809` |
| `StuntCarRacerPerf.disk` | 901,120 | see [Checksums](#checksums) |

The names differ from other WHDLoad installs of the game (`StuntCarRacer.slave`,
`StuntCarRacer.info`, `Disk.1`; AmigaDOS names ignore case), so both can share
one directory. `resload_DiskLoad` reads only images named `Disk.N`, so the
slave reads its image with `resload_LoadFileOffset`.

The slave (WHDLoad slave version 17, base memory `0x200000`, expansion memory
`0xb2000`, quit key F10, flag `WHDLF_Examine`) runs the disk's own boot block on a minimal
`exec.library` and `trackdisk.device`. The boot code, the runtime installer
and the editor bootstrap run unchanged: `Forbid`, `Permit`, `SuperState`,
`AllocMem`, `AllocAbs`, `FreeMem`, `DoIO` (`CMD_READ`, `TD_MOTOR`) and
`CacheClearU` are provided, and `AttnFlags` comes from WHDLoad. Any other
call ends WHDLoad with an operating system emulation error naming the call.
WHDLoad's start window shows the slave's text `Performance Patch 2.3.2` and
`by Timo Heimonen`. At start the slave calls `resload_SetCPU`: the base memory,
which holds the game's code and data, becomes cacheable in write-through mode,
and the instruction and data caches are enabled. Only the CPU writes to the
base memory, and write-through keeps the display memory current.

- Chip memory comes from the base memory: ordinary allocations from
  `0x80000` below the boot block at `0x8c000`, `MEMF_REVERSE` allocations from
  the top down to `0x190000`, and `AllocAbs` reserves the runtime at
  `0x181000`. Fast memory comes from the expansion memory: 256 KiB angle
  tables, the 416 KiB Track Editor and the 32 KiB Computer Link module. Its
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
| `0x62754` | request for a formatted season save disk and a key, whose wait first takes the keys still held | the same taking of the keys (`JSR 0x5985c` / `BCC.S` back), then `BRA.S` over the request and the key |
| `0x62c88` | warning that a new save disk has not been used for saving, and a key | `BRA.S` to the game's empty save index, as after the key |

The slave driver keeps the original interface: D0 drive (bits 0-1) and
format (bit 15), D1 first sector, D2 sector count, D3 read or write, A0 data;
D0 returns 0 or error 28 (write-protected), 29 (no disk) or 30 (range). Only the game disk in DF0 in the standard format
exists; DF1 returns 29. Reads of the image go through `resload_LoadFileOffset`.

The loader shows the game's loading picture while it reads the main program.
After that read the slave keeps the picture for 3 seconds with
`resload_Delay`, which a mouse button, fire or a key ends early. With the
ButtonWait option (`WHDLTAG_BUTTONWAIT_GET`; `ws_config` offers it in
WHDLoad's start window) it waits for the left mouse button or the joystick
fire (CIA-A `0xbfe001` bits 6 and 7) and their release.

The disk areas of the season saves are files in the install directory.

| Disk area (sectors) | File | Size | Without the file |
| --- | --- | ---: | --- |
| Season save index: `22` | `SaveIndex` | 512 | empty sectors |
| Season save *k* = 0-29: `23+k` | `SaveNN` (NN = *k*+1) | 512 | empty sectors |

A write builds the whole file from its current contents, or from empty sectors
without a file, and saves it with `resload_SaveFile`; an unchanged file is not
written again. Writes elsewhere return error 28, so the image is never written.
The season saves were on a separate formatted disk on floppy, so without a
file they read as a new, empty save disk; a season save file of the wrong
size reads as empty too. The game's request for that disk and its warning
about a new save disk are skipped. Menus read keys without taking them, so
the request's taking of the keys still held stays: otherwise the Return or
fire that chose Load or Save would choose in the save list at once.

The Track Editor's files go through the slave's file service by name: size,
load, save, list (the file names of a directory), delete and examine, with
`resload_GetFileSize`, `resload_LoadFile`, `resload_SaveFile`,
`resload_ListFiles`, `resload_DeleteFile` and `resload_Examine`. The editor
finds the service from the jump the slave installs for the game's driver:
the tag `SCFS`, the service version (2) and the service's offset stand just
before the driver. Names are paths in the install directory, such as
`tracks/Track007.sct`. WHDLoad does not create a missing directory, so the
patcher writes the empty `tracks` drawer, and the editor examines it before
its first write.

A write, or a read of a file WHDLoad has not cached, shows the system for a
moment, and a key released meanwhile goes to the system. On each return to
the game WHDLoad calls a slave function (`WHDLTAG_CBSWITCH_SET`), installed
once the main program is checked, that marks all 128 key states of the game
at `0xead6` up. Otherwise the game would see such a key held until it is
pressed again.

## Address mapping and patches

The main game block loads from ADF `0xdc00` to address `0xe700`.

```text
runtime address = ADF offset + 0xb00
runtime address = extracted game-block offset + 0xe700
```

[src/patches.json](src/patches.json) lists the 110 game instruction patches,
boot and loader patches, expected and replacement bytes, address mappings
and payload hashes. The `editor.changes` list is applied after the guarded
performance layer; its expected bytes refer to that intermediate disk. The
`whdload` section describes the WHDLoad install. Words and longwords use big-endian encoding.
[patch.py](patch.py) embeds the boot, runtime, intro, editor/link overlay and
the WHDLoad slave and icons for standalone use.

| Content | Size | SHA-256 |
| --- | ---: | --- |
| Boot | 320 | `b7dd1acfd78c2629292208bb286b27bea963534dac03c22649c397d25e9298e7` |
| Runtime | 7142 | `735a1d6e35d87ccd1898a5cb7ebb0e7523fb6330c0bdae0c92f9d796dce31b67` |
| Intro | 5922 | `b7ad19f33e1debe3a5c231df6742479c01aecab0ab3b588c26b776a9e918f7ca` |

## Checksums

The original ADF and the disk image are 901,120 bytes. The identified source dump shows QUARTEX text in
the track introduction; support is limited to the exact checksum below.

| File | SHA-256 |
| --- | --- |
| Supported Stunt Car Racer ADF (Quartex-crack) | `548fd106cd62f2d80159d48ddd5293d8b22b6b17f80c17a84a61d75f5c8a9e06` |
| `StuntCarRacerPerf.disk` (2.3.2, up to 50 FPS Practice, computer-opponent and linked races) | `74d2799f61395866254f9e5d9dbb7a72d3c1e52020cb00157c12d73aee2e8093` |

The patcher verifies the whole original disk, displaced instructions,
embedded payloads, loader-tail contents, boot checksum and the whole disk
image. A different dump, modified save disk, truncated image or already-patched
disk is rejected.

## Included sources

`src/` contains the assembly sources, including the WHDLoad slave, and the
patch manifest. Writing the install requires only `patch.py`, Python 3.8+ and
the supported original ADF; no assembler is needed.

## Output protection and rollback

The patcher verifies the source disk, replacement locations, embedded code,
boot checksum and complete disk image hash. It only reads the source.

An install is written only to a new directory and a new drawer icon: both are
created exclusively, never replacing an existing file or directory, and a
failed install removes what it created.

To restore the original game, quit WHDLoad and boot the untouched
original ADF with fresh emulator state. A save state containing patched RAM
continues to use the patch regardless of the inserted floppy.
