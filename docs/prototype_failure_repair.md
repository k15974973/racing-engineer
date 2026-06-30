# Prototype Failure, Repair, And Service Events

## Purpose

The repair layer is a future-phase prototype. It gives heat, reliability, and tactical risk a visible consequence before backend or online systems exist. It is not canonical Phase 1 scope unless the roadmap is revised.

## Persistence

Garage condition is stored at `user://garage_state.json`.

Tracked fields:

- `version`: save schema version.
- `damage`: current garage damage from 0 to 100.
- `part_damage`: legacy save key for Hybrid slot wear: block, induction, and material wear from 0 to 100 each.
- `credits`: current local service budget.
- `total_earned`: lifetime credits from saved race payouts.
- `total_spent`: lifetime credits spent on service.
- `incident_count`: number of saved races that added wear.
- `service_count`: number of full repairs performed.
- `failure_event_count`: number of service threshold events recorded.
- `failure_events`: recent service threshold events.
- `last_message`: latest garage feedback shown in UI.

## Damage Flow

Race Sim calculates projected wear from:

- Final heat above safe thresholds.
- Final reliability below safe thresholds.
- Tactical decisions that add heat or reduce reliability.
- The current setup's block, induction, and material stress profile using `reliability_factor`, `reliability_mult`, and `durability_mult`.

Running a race only previews this wear. `Save Race` commits the wear once for that result, records it in race history, pays local credits, and updates garage state. Saving another copy of the same result does not stack damage or payout again.

## Local Economy

The garage starts with 2500 credits. Saved race payouts are based on:

- Baseline participation payout.
- Track fit.
- Pace versus baseline lap time.
- Clean race bonus.
- Risk penalty from projected damage and extreme heat/reliability outcomes.

Payouts are local-only and are not server-authoritative.

## Service Events

When a saved race pushes a slot across a wear threshold, the garage records a lightweight service event:

- Minor threshold: 45 wear.
- Major threshold: 70 wear.
- Critical threshold: 90 wear.

Events are stored in `failure_events` and shown in Race Result, Race History, and Garage Condition. They do not hard-fail a race yet; they explain why service should be prioritized. These are slot-level events, not physical sub-part failures.

## Repair Flow

`Repair All` resets garage damage to 0 if the player can afford the full service cost. `Budget Repair` spends up to 650 credits and removes proportional damage when full service is too expensive or not desired. Repair clears the current race result because the car state changed and the previous simulation is no longer the current expected outcome.

## Performance Penalty

Garage damage applies lightweight penalties to the current setup:

- Peak power and torque decrease.
- Heat score increases.
- Reliability, throttle response, and push margin decrease.
- Power and torque curves are scaled to match the degraded output.

Hybrid slot condition modifies the penalty shape:

- Block wear reduces torque, reliability, and push margin.
- Induction wear reduces power, response, and adds heat.
- Material wear increases heat and reduces durability margin.

Saved setups remain clean design blueprints. Race Sim and Test Bench use the current garage condition.

## UI Touchpoints

- Engine Builder shows garage condition and repair action.
- Race Sim shows garage condition, projected wear, and whether wear has already been applied.
- Race Sim also previews race payout, risk penalty, and whether the payout has already been added.
- Race History stores and displays global wear, slot wear, and credits for saved runs.
- Garage Condition shows service recommendations and recent service events.
- Analysis repeats garage status next to progression and rebuild advice.
- Data Smoke Test shows the garage state file path and current condition.

## Next Step

Decide whether Garage/Economy becomes an explicit roadmap phase or remains a prototype. Do not expand content until the roadmap slot and data contract are approved.
