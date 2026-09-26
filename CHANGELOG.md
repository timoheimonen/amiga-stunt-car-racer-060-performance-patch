# Changelog

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
