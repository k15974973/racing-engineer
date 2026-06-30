# Phase 2 Race Sim Start

## Canonical Phase 2 Implementation

- Race Sim consumes the final Engine Builder setup from `GameData`.
- Track data now has a contract report covering id, name, laps, length, base lap time, straight bias, corner bias, endurance bias, heat stress, and description.
- Invalid non-empty track ids return an explicit error naming `res://data/tracks.json` instead of silently falling back to the first track.
- Every race result reports track, setup, laps, lap time, total time, delta versus base, sector scores, final heat, final reliability, decision effects, tactical windows, and summary.
- Tactical windows are generated from the approved boost, heat, corner, and straight decision groups.
- Each race generates three to four tactical windows so the player has a real engineering sequence instead of a single isolated prompt.
- Race results now include a lap-ordered `timeline` object that shows each tactical decision, cumulative time delta, projected heat, projected reliability, and risk label.
- Race results now include a `save_preview` object that summarizes final heat, final reliability, decision deltas, and save risk before the player commits the race to history/garage effects.
- `tests/race_sim_smoke.gd` verifies timing consistency, sector output, window count, timeline consistency, save preview consistency, decision-effect totals, aggressive/conservative tradeoffs, track-specific windows, and the invalid-track error path.

## Still Out Of Scope

- No 3D race camera.
- No ghost races, leaderboards, backend validation, or real-time PvP.
- No physical part-level wear model. Wear remains attached to the approved block, induction, and material slots in the later Hybrid prototype.
- No canonical continuous parameter tuning until Phase 5.

## Next Phase 2 Step

Improve the Race Sim screen around comparison and replay clarity: add saved-run overlay, show best run deltas on the Race Sim screen, and make tactical choices easier to compare without opening Analysis.
