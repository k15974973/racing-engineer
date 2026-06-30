# Phase 1 Engine Builder Start

## Canonical Phase 1 Implementation

- Engine Builder now has interactive selectors for block, induction, and material.
- All Phase 1 Builder combinations are selectable; progression gating is deferred.
- Selection changes immediately rebuild the projected setup card.
- Projection uses structured data through `GameData`, not hardcoded UI values.
- `GameData` validates required fields, value types, numeric ranges, rpm ordering, and duplicate ids for the Phase 1 data contracts.
- `tests/data_contract_smoke.gd` verifies the block, induction, and material contracts through Godot headless mode.
- `tests/curve_differentiation_smoke.gd` verifies that V8 NA, Rotary Twin Turbo, and Inline-4 Supercharger curves remain clearly separated and internally consistent with `P = T * RPM / 7121`.
- Power and torque curves redraw from the current setup.
- Test Bench runs for 30 seconds with live RPM, boost, heat, reliability, and status telemetry.
- Setups can be saved, loaded, deleted, persisted to `user://saved_setups.json`, and compared side by side.
- Current projected stats:
  - Peak power
  - Torque
  - Mass
  - RPM range
  - Engine health
  - Heat load
  - Reliability
  - Throttle response
  - Push margin
- Test Bench can start, pause, reset, and auto-complete at 30 seconds.

## Future-Phase Prototype Systems

The following systems are implemented in the running prototype, but they are not canonical Phase 1 scope:

- Race Sim can project lap time from the current setup on two track profiles.
- Tactical windows are interactive and affect race time, heat, and reliability.
- Analysis explains the latest race with a scorecard, findings, tactical review, and rebuild direction.
- Race history persists to `user://race_history.json` and lets Analysis compare against the best saved run on the same track.
- Progression persists to `user://progression.json` as future-phase prototype metadata; Phase 1 Builder does not gate block, induction, or material options.
- Garage condition and local credits persist to `user://garage_state.json`; saved race wear can degrade current performance until repaired.
- Hybrid slot condition tracks block, induction, and material damage separately and applies different stat penalties.
- Service recommendations and threshold events explain which slot group needs attention.
- Continuous parameter tuning controls exist in the prototype, but are deferred from canonical Phase 1 to Phase 5 because the validated 3-slot curve model should stay stable while Phase 2 tests tactical race decisions.

## Next Canonical Step

Move to Phase 2 Race Sim using the validated 3-slot builder as input. Race, analysis, economy, and wear should be treated as prototype learnings until the roadmap is revised.
