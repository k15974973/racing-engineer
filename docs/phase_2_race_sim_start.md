# Phase 2 Race Sim Start

## Canonical Phase 2 Implementation

- Race Sim consumes the final Engine Builder setup from `GameData`.
- Track data now has a contract report covering id, name, laps, length, base lap time, straight bias, corner bias, endurance bias, heat stress, and description.
- Invalid non-empty track ids return an explicit error naming `res://data/tracks.json` instead of silently falling back to the first track.
- Every race result reports track, setup, laps, lap time, total time, delta versus base, sector scores, final heat, final reliability, decision effects, tactical windows, and summary.
- Tactical windows are generated from the approved boost, heat, corner, and straight decision groups.
- Each race generates three to four tactical windows so the player has a real engineering sequence instead of a single isolated prompt.
- `tests/race_sim_smoke.gd` verifies timing consistency, sector output, window count, decision-effect totals, aggressive/conservative tradeoffs, track-specific windows, and the invalid-track error path.

## Still Out Of Scope

- No 3D race camera.
- No ghost races, leaderboards, backend validation, or real-time PvP.
- No physical part-level wear model. Wear remains attached to the approved block, induction, and material slots in the later Hybrid prototype.
- No canonical continuous parameter tuning until Phase 5.

## Next Phase 2 Step

Improve the Race Sim screen around a readable race timeline: show the tactical windows in lap order, preview final heat/reliability before saving, and make the result explain which decision created each time gain or risk.
