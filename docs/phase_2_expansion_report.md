# Phase 2 Expansion Report

## Current Status

Phase 0 is complete: design docs, data matrix, tactical window spec, Godot scaffold, and `GameData` loading are in place.

Phase 1 is complete for the canonical builder scope: block x induction x material, readable selector output, curve differentiation, curve physics consistency, engine health, test bench, saved setup workflow, and smoke tests. Continuous parameter tuning remains prototype-only and is deferred to Phase 5.

Phase 2 is now active. The current slice turns the earlier Race Sim prototype into a more testable canonical race layer.

## Phase 2 Additions

- Track data now has contract validation through `GameData`.
- Non-empty invalid track ids return a clear error naming `res://data/tracks.json`; only an empty id may use the default track.
- Race Sim produces deterministic race results from the final engine setup object.
- Tactical windows generate from the approved boost, heat, corner, and straight groups.
- Each race produces three to four windows, giving the player a sequence of engineering decisions instead of one isolated prompt.
- Boost windows are tied to forced-induction setups, so naturally aspirated builds do not receive fake boost events.
- Race results now include a lap-ordered `timeline` object.
- Race results now include a `save_preview` object before committing a race to history or garage effects.
- The Race Sim UI shows pre-save risk, a timeline stepper, and decision totals.
- The Race Sim UI shows the best saved run for the selected track and compares the current run against it before Analysis.
- Analysis now reads the timeline when explaining tactical decisions.

## Data Objects

`decision_effects` remains the aggregate source for tactical deltas:

- `time_delta`
- `heat_delta`
- `reliability_delta`
- `log`

`timeline` is the readable sequence derived from the same decision log:

- `sequence`
- `lap`
- `marker`
- `window`
- `choice`
- `choice_id`
- `time_delta`
- `heat_delta`
- `reliability_delta`
- `cumulative_time_delta`
- `projected_heat`
- `projected_reliability`
- `risk`

`save_preview` is the pre-commit summary:

- `final_heat`
- `final_reliability`
- `decision_time_delta`
- `decision_heat_delta`
- `decision_reliability_delta`
- `risk`
- `summary`

## Test Coverage

`tests/race_sim_smoke.gd` now verifies:

- valid race result timing,
- total time versus lap time consistency,
- lap delta consistency,
- exactly three sector scores,
- three to four tactical windows,
- decision log count matching window count,
- decision-effect totals matching the log sum,
- timeline count matching window count,
- timeline lap ordering,
- timeline cumulative time matching decision effects,
- timeline final heat/reliability matching the race result,
- save preview final heat/reliability matching the race result,
- save preview decision deltas matching decision effects,
- aggressive decisions trading heat/reliability for faster total time,
- conservative decisions trading time for safer heat/reliability,
- boosted setups producing Boost Spike windows,
- technical tracks producing Corner Map windows,
- invalid track ids returning a clear `tracks.json` error.

## Important Design Choices

The race layer still consumes the final setup object produced by the builder. UI/report values should continue to come from the final simulation object, not seed values or duplicate calculations.

The timeline is derived from `decision_effects.log` so Analysis and Race Sim explain the exact same decisions the simulation used.

Heat penalty was tuned so a cool setup can gain time by pushing, while hot or fragile setups can still lose time through thermal/reliability risk. This keeps tactical decisions meaningful instead of making every push either always correct or always wrong.

## Not In This Slice

- No 3D race camera.
- No particles, audio, or animated race view.
- No backend validation.
- No leaderboards, ghost races, or async submissions.
- No real-time PvP.
- No physical parts model such as pistons, ECU, radiator, or individual turbo wear.
- No canonical continuous tuning until Phase 5.

## Next Recommended Phase 2 Work

- Add a compact full-run summary beside the timeline stepper.
- Add per-track setup notes without expanding the data model.
- Add simple comparison filters for saved runs on the same track.
- Add one more track only after the two current tracks keep producing distinct tactical decisions.
