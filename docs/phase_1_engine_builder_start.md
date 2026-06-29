# Phase 1 Engine Builder Start

## Implemented In This Slice

- Engine Builder now has interactive selectors for block, induction, and material.
- Selection changes immediately rebuild the projected setup card.
- Projection uses structured data through `GameData`, not hardcoded UI values.
- Basic tuning sliders update projected stats in real time.
- Power and torque curves redraw from the current setup and tuning values.
- Test Bench runs for 30 seconds with live RPM, boost, heat, reliability, and status telemetry.
- Setups can be saved, loaded, deleted, persisted to `user://saved_setups.json`, and compared side by side.
- Race Sim can project lap time from the current setup on two track profiles.
- Tactical windows are interactive and affect race time, heat, and reliability.
- Analysis explains the latest race with a scorecard, findings, tactical review, and rebuild direction.
- Race history persists to `user://race_history.json` and lets Analysis compare against the best saved run on the same track.
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

## Next Phase 1 Step

Add a simple progression layer that unlocks parts after clean race results.
