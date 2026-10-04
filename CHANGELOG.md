# Changelog

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
