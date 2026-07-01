# Phase 2 Race Sim Complete

## Canonical Phase 2 Implementation

- Race Sim consumes the final Engine Builder setup from `GameData`.
- Track data now has a contract report covering id, name, laps, length, base lap time, straight bias, corner bias, endurance bias, heat stress, and description.
- Invalid non-empty track ids return an explicit error naming `res://data/tracks.json` instead of silently falling back to the first track.
- Every race result reports track, setup, laps, lap time, total time, delta versus base, sector scores, final heat, final reliability, decision effects, tactical windows, and summary.
- Tactical windows are generated from the approved boost, heat, corner, and straight decision groups.
- Each race generates three to four tactical windows so the player has a real engineering sequence instead of a single isolated prompt.
- Race results now include a lap-ordered `timeline` object that shows each tactical decision, cumulative time delta, projected heat, projected reliability, and risk label.
- Race results now include a `save_preview` object that summarizes final heat, final reliability, decision deltas, and save risk before the player commits the race to history/garage effects.
- Race results now include a `race_overview` object summarizing pace, attack count, recovery count, risk count, and final run interpretation.
- Race results now include `setup_notes` derived from track demands and setup scores without adding new track data fields.
- Race Sim now shows the best saved run for the selected track and compares the current total time before the player opens Analysis.
- Race Sim now uses a timeline stepper so the player can inspect each tactical decision in sequence.
- `tests/race_sim_smoke.gd` verifies timing consistency, sector output, window count, timeline consistency, save preview consistency, race overview consistency, setup note readability, decision-effect totals, aggressive/conservative tradeoffs, track-specific windows, and the invalid-track error path.
- `tests/phase_2_acceptance_smoke.gd` verifies the roadmap deliverable: build -> race -> result on Power Ring and Technical Loop, distinct tactical window mixes, non-empty result objects, and analyzable race results.

## Completion Criteria

- End-to-end build, race, and result flow works on two tracks.
- Tactical windows visibly change time, heat, and reliability.
- Race results expose enough trace data for Analysis and later Core Loop work.
- Track data is validated and invalid ids fail loudly.
- Phase 2 remains offline/local and does not add backend, PvP, ghost races, or leaderboards.

## Still Out Of Scope

- No 3D race camera.
- No ghost races, leaderboards, backend validation, or real-time PvP.
- No physical part-level wear model. Wear remains attached to the approved block, induction, and material slots in the later Hybrid prototype.
- No canonical continuous parameter tuning until Phase 5.

## Next Canonical Step

Move to Phase 3 Core Loop: make Build -> Race -> Analyze -> Rebuild produce a clear learning moment using the Phase 2 race result objects.
