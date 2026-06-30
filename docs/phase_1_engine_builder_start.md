# Phase 1 Engine Builder Start

## Canonical Phase 1 Implementation

- Engine Builder now has interactive selectors for block, induction, and material.
- Selection changes immediately rebuild the projected setup card.
- Projection uses structured data through `GameData`, not hardcoded UI values.
- Basic tuning sliders update projected stats in real time.
- Power and torque curves redraw from the current setup and tuning values.
- Test Bench runs for 30 seconds with live RPM, boost, heat, reliability, and status telemetry.
- Setups can be saved, loaded, deleted, persisted to `user://saved_setups.json`, and compared side by side.
- Current projected stats:
  - Peak power
  - Torque
  - Mass
  - RPM range
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
- Progression persists to `user://progression.json`, gates advanced parts, and unlocks parts from clean race results.
- Garage condition and local credits persist to `user://garage_state.json`; saved race wear can degrade current performance until repaired.
- Hybrid slot condition tracks block, induction, and material damage separately and applies different stat penalties.
- Service recommendations and threshold events explain which slot group needs attention.

## Next Canonical Phase 1 Step

Harden the Engine Builder data contracts and UI polish before expanding later-phase systems. Race, analysis, economy, and wear should be treated as prototype learnings until the roadmap is revised.
