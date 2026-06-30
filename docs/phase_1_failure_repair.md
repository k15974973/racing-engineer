# Phase 1 Failure And Repair

## Purpose

The repair layer gives heat, reliability, and tactical risk a visible consequence before economy, backend, or online systems exist. It remains local-only and intentionally simple.

## Persistence

Garage condition is stored at `user://garage_state.json`.

Tracked fields:

- `version`: save schema version.
- `damage`: current garage damage from 0 to 100.
- `credits`: current local service budget.
- `total_earned`: lifetime credits from saved race payouts.
- `total_spent`: lifetime credits spent on service.
- `incident_count`: number of saved races that added wear.
- `service_count`: number of full repairs performed.
- `last_message`: latest garage feedback shown in UI.

## Damage Flow

Race Sim calculates projected wear from:

- Final heat above safe thresholds.
- Final reliability below safe thresholds.
- Tactical decisions that add heat or reduce reliability.

Running a race only previews this wear. `Save Race` commits the wear once for that result, records it in race history, pays local credits, and updates garage state. Saving another copy of the same result does not stack damage or payout again.

## Local Economy

The garage starts with 2500 credits. Saved race payouts are based on:

- Baseline participation payout.
- Track fit.
- Pace versus baseline lap time.
- Clean race bonus.
- Risk penalty from projected damage and extreme heat/reliability outcomes.

Payouts are local-only and are not server-authoritative.

## Repair Flow

`Repair All` resets garage damage to 0 if the player can afford the full service cost. `Budget Repair` spends up to 650 credits and removes proportional damage when full service is too expensive or not desired. Repair clears the current race result because the car state changed and the previous simulation is no longer the current expected outcome.

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
- Race Sim also previews race payout, risk penalty, and whether the payout has already been added.
- Race History stores and displays wear plus credits for saved runs.
- Analysis repeats garage status next to progression and rebuild advice.
- Data Smoke Test shows the garage state file path and current condition.

## Next Step

Add part-specific wear: blocks, induction systems, and materials should produce different failure risks, repair costs, and service recommendations. Keep it offline until async online infrastructure exists.
