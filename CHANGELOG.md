# Changelog

## 2.2.0 - 2026-11-08

- **Race the computer on custom tracks.** After a track in **Practise →
  Custom Tracks**, a menu offers **Practise**, **Race** and **Cancel**.
  **Race** is a single race against a computer driver chosen at random, at the
  pace of the Little Ramp's opponent; **AI Difficulty** makes it faster.
  ([manual](docs/track-editor.md#driving-and-racing-your-tracks))
  - The car starts every race undamaged. The race leaves the league, its
    damage, points and season times as they were.
  - A won race can set the track's best race time next to its best lap, with
    the same settings as lap records.
  - The menu starts on the choice made last.

## 2.1.0 - 2026-11-08

- **Timing** in Settings: **Performance** (default) is the 50 Hz game.
  **Original** races with the original 120 ms game loop and physics, with the
  faster drawing still on. In Original, Game Speed shows 100% and cannot be
  changed; the value set for Performance returns with it. Original races do not
  set records on the original tracks, and custom tracks keep their times for the
  session only. Computer Link races always use Performance.
- **Track Editor** ([manual](docs/track-editor.md)):
  - **Finish**, or the F key, builds the rest of an open track. If the end as it
    is leads nowhere, it first takes off sections as **Del** would. With a gap it
    fills the gap. All of it is one **Undo** step.
  - **Del** with a section in the middle selected removes only that section and
    leaves a gap, which **Add** and **Finish** fill. **Cut** is gone. **Save** and
    **Test** wait until the gap is filled.
  - A track can have up to 78 road pieces instead of 64, as many as the longest
    original tracks. Tracks and records of up to 64 pieces are saved exactly as
    before; a longer track does not open in 2.0.0.
  - Four more sections from the original tracks: **Bumps** from Big Ramp, **Dip**
    from Stepping Stones, the straight **Large** jump from High Jump and the
    whole diagonal **Ramp** of Little Ramp. The diagonal **Small** jump, which
    began with a landing, is gone. There are 36 sections.
  - Every section climbs or drops by whole quarter levels, so the height alone
    never stops a track from closing. Tracks built with older versions keep
    their shape.
  - Slots 02 and 03 hold two more ready-to-drive example tracks, **BUILD 2** and
    **BUILD 3**. A track file in the install takes the place of the example
    track in its slot.
- The player-name screen and WHDLoad's start window show the version.

## 2.0.0 - 2026-11-06

- **WHDLoad only.** `patch.py` writes the WHDLoad install and nothing else:
  `python3 patch.py ORIGINAL [DIRECTORY]`. There is no patched ADF any more,
  and `--whdload`, `--output` and `--force` are gone. Releases from now on are
  WHDLoad installs only; [1.6.3](https://github.com/timoheimonen/amiga-stunt-car-racer-060-performance-patch/tree/Release/1.6.3) still includes the disk version.
- The requirements are now those of the install: a 68060, 2 MiB Chip RAM, at
  least 2 MiB Fast RAM and WHDLoad 17 or later.
- **Track Editor overhaul**, with a new [manual](docs/track-editor.md):
  - A bar of buttons below the 3D view shows every command, and a dimmed button
    says why on the line below. A mouse in port 1 clicks them; the keyboard and
    the joystick still work.
  - The camera is free and only the player moves it: hold the right mouse button
    and drag to look around, **W A S D** move it, **Q Z** raise and lower it. A
    track opens on its start piece. While the camera moves the view is drawn as
    road edges. The old **Q/W** view turns and **A/Z** zoom are gone.
  - A new track starts on the map, where the start line takes a square and a
    heading.
  - Sections are chosen by turn, slope and kind. Buttons that close the track
    are green, and line 2 says how many sections the start is away.
  - A map of the whole track sits at the right edge of the bar.
  - **Test** drives the track in memory without writing anything.
  - **New** offers three ready-made tracks: Banked Loop, Small Hills and Ramp
    and Hills.
  - **Undo** and the new **Redo** reach back 16 steps. **Cut** removes a section
    in the middle and everything after it. **F1** saves, as **S** now moves the
    camera.
  - Rejections are plain sentences, the rise is shown in eighths of a level, and
    the first Save selects the first free row and offers the name `TRACK nn`.
  - The editor responds about three times faster on a long track, and quick taps
    are read before it draws.
- A Return or Fire pressed while the track list opens no longer changes a save
  or closes the list. Left now moves in the editor on tracks built from whole
  sections.
- The track disk in DF1 is gone. Tracks are files: copy them. Save files from an
  earlier WHDLoad install work as they are. Tracks saved on a patched ADF or a
  DF1 track disk stay on that disk.

## 1.6.3 — 2026-10-04

- WHDLoad install: season Load no longer loads a save by itself. The Return
  or fire that chose Load or Save was taken as the choice in the list; the
  keys still held are now cleared first, as on floppy. The same applied to
  the save name.
- WHDLoad install: a key released while the display is blanked for a save no
  longer stays held for the game. The Track Editor left with Esc only after
  Return was pressed again, and its first key press after a save was ignored.
- WHDLoad install: a season save file of the wrong size reads as empty
  instead of stopping every season Load and Save with a disk error; the next
  save replaces it.
- Practise keeps Custom Tracks and Track Editor after a season save or load.
  The original menu remains for multiplayer and Computer Link games. Applies
  to both the ADF and the WHDLoad install.

## 1.6.2 — 2026-10-04

- WHDLoad install: season Load and Save no longer ask for a formatted save
  disk or warn that a new save disk has not been used for saving; season
  saves are files.
- WHDLoad install: the loading picture stays on the screen for 3 seconds, or
  with WHDLoad's ButtonWait option until the left mouse button or fire is
  pressed. See [WHDLoad install](WHDLOAD.md#loading-picture).
- Player name: an empty Return or keypad Enter gives the name `racer` like
  Fire. The prompt reads `NAME? OR FIRE/RETURN TO PROCEED`.
- **Experimental:** keyboard CIA fix. A key pressed while the game was
  loading could stop the keyboard from responding in the menus. A hook after
  the game's CIA setup clears the keyboard acknowledge state; the setup itself
  is unchanged. Applies to both the ADF and the WHDLoad install.

## 1.6.1 — 2026-10-03

- WHDLoad install: the slave, its icon and the disk image are now
  `StuntCarRacerPerf.slave`, `StuntCarRacerPerf.info` and
  `StuntCarRacerPerf.disk`, so the install can share a directory with other
  WHDLoad installs of the game, which use `StuntCarRacer.slave`,
  `StuntCarRacer.info` and `Disk.1`. Save files keep their names: copy them
  from a 1.6.0 install into the new one.
- `--whdload` without a directory creates `StuntCarRacerPerf` and its drawer
  icon `StuntCarRacerPerf.info` beside the original ADF.
- The patched ADF is unchanged.

## 1.6.0 — 2026-10-03

- WHDLoad install: `patch.py --whdload DIRECTORY` writes the slave, the
  patched disk as `Disk.1`, a Workbench icon and a drawer icon for starting
  the game from a hard disk without the intro. Custom tracks, records and
  season saves are files in the install directory. See [WHDLoad install](WHDLOAD.md).
- The patched ADF is unchanged from 1.5.0.

## 1.5.0 — 2026-09-29

- The boot intro is skipped on a 68060 whose FPU is enabled at boot

## 1.4.9 — 2026-09-28

- Track Editor is no longer marked beta.
- Editor: straight hills, ramps and crests are previewed from the side.
- Editor: Q/W turn the view and A/Z zoom.
- Editor: the building lines show the section's rise, the choice number, the
  piece count, why a red section does not fit, and where the start line is
  from the open end; a section that closes the track is marked.
- Editor: fix a freeze of the append preview camera in some views.
- The game disk includes the ready-to-drive track BUILD in save slot 01.

## 1.4.8 — 2026-09-26

- PAL and NTSC

## 1.4.7 — 2026-09-26

- Faster frame rate when frames are late: the extra physics steps no longer
  redraw the HUD and cockpit images, which the next drawn frame draws anyway.
  The images are drawn once per displayed frame, as in the original game.

## 1.4.5 — 2026-09-25

- Smoke and particles keep real time when frames are late.
- Boot intro rendering updated.

## 1.4.4 — 2026-09-25

- Crane lifts keep real time when frames are late: like racing, the crane
  runs extra fixed physics steps without drawing.
- HUD and cockpit images are drawn from a Fast RAM cache with fewer Chip RAM
  accesses.
- Track preview: the finish arrow is placed from a single hook after each
  completed track piece and no longer writes into the editor module's code
  while the game runs.

## 1.4.3 — 2026-09-25

- Fix boot failures on PiStorm / Emu68 by retaining the operating system's
  boot-task stack during startup.

## 1.4.2 — 2026-09-24

- Track Editor module: cache flushing now matches the detected CPU. Earlier
  versions used an instruction that stopped some processors with a Line-F
  error (8000 000B) after the intro.
- Requirements: 2 MiB Chip RAM and at least 1 MiB Fast RAM.

## 1.4.1 — 2026-09-24

- Computer Link: if the other machine stops responding while a race is being
  set up, the game returns to the title screen after about 5 seconds instead
  of about 5 minutes.
- Computer Link: when both cars finish, the winner is also decided correctly
  after 10 min 55 s of racing. Finish times from 655.35 s upwards count as
  equal, and a tie goes to the Host.

## 1.4.0 — 2026-09-24

- Add a two-player Computer Link: 50 Hz local physics, 20 Hz position
  exchange with a smoothed opponent, cars pass through each other, shared
  pause, results and points. Choose Host (H) or Join (J).
- The link championship runs through Divisions 4 to 1 with cumulative points;
  the winner is decided after the FINAL SEASON in Division 1.
- Frametime corrections
- Finish row is marked with a small arrow in the track preview.

## 1.3.1 — 2026-09-22

- Restore the original CIA startup initialization.

## 1.3.0 — 2026-09-21

- Add in-game Track Editor: 33 section choices, a 16 × 16 building
  grid.
- Add 32 named Draft/Ready save slots, custom tracks in Practise, persistent
  custom-track records, and DF1 track-disk import/export with 32 slots.
- Initialize the keyboard before enabling game interrupts, preventing startup
  key presses from leaving input locked.
- Smoke / particles framerate fixed.

## 1.2.2 — 2026-09-18

- Retain 32-bit precision in screen-point transforms and round to the nearest pixel.
- Interpolate projection angle and distance lookup tables for smoother geometry.
- Round projection distances and saturate values above 32767.

## 1.2.1 — 2026-09-18

- Add Disable Damage (No/Yes, default No) to Settings.
- Allow Fire to continue past player-name entry, using `racer` for an empty name.

## 1.2.0 — 2026-09-16

- Added a Settings menu with independent Game Speed, AI Difficulty controls and Infinite Boost (No/Yes)

## 1.1.0 — 2026-09-16

- Add main-menu speed adjustment from 100% to 150% in 5% increments.

## 1.0.2 — 2026-09-15

- Correct direct yaw correction timing for the 20 ms physics step.
- Restore the severe-impact cooldown to its original 120 ms tick rate.

## 1.0.1 — 2026-09-15

- Fix crane lift

## 1.0.0 — 2026-09-09

- Add a boot intro

## 0.4.0 — 2026-09-08

- Optimize rendering for the 68060.

## 0.3.0 — 2026-09-07

- Optimize geometry processing for the 68060.

## 0.2.0 — 2026-09-07

- Change the target platform to emulation only.
- Add 50 Hz physics and 50 FPS rendering to computer-opponent races.
- Fix a Guru Meditation caused by time penalties after leaving the track.

## 0.1.1 — 2026-09-07

- Fix display flickering in opponent races.

## 0.1.0 — 2026-09-07

- Add 50 Hz physics and 50 FPS rendering to Practice mode.
- Add a standalone Python patcher.
