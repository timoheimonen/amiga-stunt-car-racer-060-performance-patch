# Changelog

## 0.3.0 — 2026-09-07

- Optimize geometry processing for the 68060 using scaled index addressing.
- Process point groups in a single loop, removing per-point subroutine calls.

## 0.2.0 — 2026-09-07

- Designate this version as emulator only, targeting FS-UAE.
- Add 50 Hz physics and 50 FPS rendering to races against computer drivers.
- Adapt opponent suspension, acceleration, movement, steering and collision
  effects to the fixed 20 ms step with fractional accumulation.
- Preserve the timing of race clocks, AI decisions and contact events.
- Fix the time-penalty call that could cause a Guru Meditation after leaving
  the track.
- Retain 50 Hz Practice physics and synchronized display-buffer reuse.

## 0.1.1 — 2026-09-07

- Fix display-buffer synchronization and flickering in opponent races.
- Keep Practice physics at 50 Hz and opponent physics at its original cadence.

## 0.1.0 — 2026-09-07

- Introduce 50 Hz physics and 50 FPS rendering in Practice mode.
- Install the runtime at boot in a reserved 4 KiB Chip-memory area.
- Supply a standalone Python patcher, assembly sources and a patch manifest.
- Provide `--output`, `--force` and `--version`, with original-file protection.
