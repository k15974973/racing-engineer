# Phase 2 Completion Report

## Scope Closed

Phase 2 is complete for the canonical roadmap target:

`End-to-end build, race, result flow on two tracks.`

The implementation uses the Phase 1 builder output as the race input. It does not add backend systems, online submissions, ghost races, leaderboards, real-time PvP, 3D race cameras, or a physical parts model.

## Progress Since The Last Report

The previous Phase 2 report closed with Race Sim timeline reporting, pre-save preview, and race result traceability. Since then, the following work was completed:

- Added best saved run visibility directly to Race Sim.
- Added current-vs-best comparison before opening Analysis.
- Added a timeline stepper so each tactical window can be inspected one at a time.
- Added `race_overview` to the final race result object.
- Added `setup_notes` to the final race result object.
- Added Race Sim UI panels for Run Overview and Track Setup Notes.
- Added compact full-run summary beside the timeline stepper.
- Extended `tests/race_sim_smoke.gd` to validate `race_overview` and `setup_notes`.
- Added `tests/phase_2_acceptance_smoke.gd` to lock the canonical Phase 2 acceptance criteria.
- Updated README and Phase 2 docs to mark Phase 2 complete.

## Final Phase 2 Data Outputs

Every successful race result now exposes:

- `track`
- `setup`
- `laps`
- `lap_time`
- `total_time`
- `delta_vs_base`
- `fit_score`
- `power_score`
- `technical_score`
- `endurance_score`
- `effective_heat`
- `effective_reliability`
- `decision_effects`
- `sectors`
- `windows`
- `timeline`
- `save_preview`
- `race_overview`
- `setup_notes`
- `summary`

These objects are produced in `GameData` and then rendered by UI/Analysis. This keeps reported values tied to the final simulation object instead of duplicated UI-side calculations.

## Validation Status

The Phase 2 acceptance test verifies:

- a Phase 1 engine setup can be built,
- Power Ring can run and return a full result,
- Technical Loop can run and return a full result,
- the two tracks are distinct,
- lap timing is internally consistent,
- sector, window, timeline, save preview, race overview, setup notes, and decision effects are present,
- each race generates three to four tactical windows,
- timeline count matches tactical window count,
- both race results can be passed into Analysis.

The broader race sim smoke test verifies:

- aggressive decisions trade heat/reliability for time,
- conservative decisions trade time for heat/reliability safety,
- boosted setups produce Boost Spike windows,
- technical tracks produce Corner Map windows,
- invalid track ids name `res://data/tracks.json`,
- race overview counts match the timeline,
- setup notes are readable dictionaries.

## Achieved Goals

- Phase 0: complete.
- Phase 1: complete for canonical 3-slot Engine Builder.
- Phase 2: complete for canonical Race Sim.
- Two track profiles exist and behave differently.
- Tactical choices have visible mechanical consequences.
- Result data is structured enough for Phase 3 Analysis and Rebuild guidance.
- Physics-critical curve tests remain in place.
- Race-critical result tests are now in place.

## Remaining Out Of Scope

- Real-time PvP.
- Async online submissions.
- Leaderboards and ghost races.
- Backend validation.
- 3D race camera.
- Part-level physical component wear.
- Canonical continuous parameter tuning before Phase 5.

## Next Phase

Phase 3 should focus on making the loop teach the player:

`Build -> Race -> Analyze -> Rebuild`

Recommended first Phase 3 task: make Analysis produce one clear rebuild instruction from race result evidence, then verify that changing the builder setup can improve the next race on the same track.
