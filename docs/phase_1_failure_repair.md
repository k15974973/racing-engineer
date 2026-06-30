# Phase 1 Failure And Repair

## Purpose

The repair layer gives heat, reliability, and tactical risk a visible consequence before economy, backend, or online systems exist. It remains local-only and intentionally simple.

## Persistence

Garage condition is stored at `user://garage_state.json`.

Tracked fields:

- `version`: save schema version.
- `damage`: current garage damage from 0 to 100.
- `incident_count`: number of saved races that added wear.
- `service_count`: number of full repairs performed.
- `last_message`: latest garage feedback shown in UI.

## Damage Flow

Race Sim calculates projected wear from:

- Final heat above safe thresholds.
- Final reliability below safe thresholds.
- Tactical decisions that add heat or reduce reliability.

Running a race only previews this wear. `Save Race` commits the wear once for that result, records it in race history, and updates garage state. Saving another copy of the same result does not stack damage again.

## Repair Flow

`Repair All` resets garage damage to 0 and increments service count. Repair also clears the current race result because the car state changed and the previous simulation is no longer the current expected outcome.

## Performance Penalty

Garage damage applies lightweight penalties to the current setup:

- Peak power and torque decrease.
- Heat score increases.
- Reliability, throttle response, and push margin decrease.
- Power and torque curves are scaled to match the degraded output.

Saved setups remain clean design blueprints. Race Sim and Test Bench use the current garage condition.

## UI Touchpoints

- Engine Builder shows garage condition and repair action.
- Race Sim shows garage condition, projected wear, and whether wear has already been applied.
- Race History stores and displays wear for saved runs.
- Analysis repeats garage status next to progression and rebuild advice.
- Data Smoke Test shows the garage state file path and current condition.

## Next Step

Add a lightweight local cost model: limited service budget, repair grades, or part-specific wear. Keep it offline until async online infrastructure exists.
