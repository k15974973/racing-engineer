# Phase 1 Progression Unlocks

## Purpose

The progression layer turns the current prototype into a clearer `Build -> Race -> Analyze -> Rebuild` loop. It is intentionally lightweight: no currency, repair timers, backend, account state, or online validation yet.

## Persistence

Progression is stored at `user://progression.json`.

Tracked fields:

- `version`: save schema version.
- `unlocked`: unlocked part ids grouped by `blocks`, `inductions`, and `materials`.
- `completed_rules`: one-time unlock rule ids.
- `clean_race_count`: saved clean race count for the experimental license.
- `last_message`: latest progression feedback shown in UI.

## Starter Garage

Default unlocked parts:

- Blocks: `v4`, `v6`, `inline_4`.
- Induction: `na`, `single_turbo`.
- Material: `aluminum`.

Locked parts still appear in Engine Builder selectors with a locked label, but cannot be selected until progression unlocks them.

## Unlock Rules

- Power Ring Clean Finish: fit 74+, heat 125 or lower, reliability 55+ on Power Ring. Unlocks `titanium`.
- Technical Loop Clean Finish: fit 74+, heat 125 or lower, reliability 55+ on Technical Loop. Unlocks `boxer_4`.
- B-Class Track Fit: fit 86+, heat 126 or lower, reliability 55+ on any track. Unlocks `twin_turbo`.
- Cool Fast Package: beat baseline lap time with heat 105 or lower and reliability 70+. Unlocks `supercharger`.
- Heavy Power Brief: reach 390 hp with fit 80+ and reliability 50+. Unlocks `v8`.
- Thermal Mastery: fit 82+, heat 95 or lower, reliability 75+. Unlocks `ceramic`.
- Experimental License: save three clean races. Unlocks `rotary` and `compound`.

## UI Touchpoints

- Engine Builder shows current progression, locked counts, and next unlock targets.
- Race Result shows new unlock messages immediately after a qualifying run.
- Analysis repeats progression state next to rebuild suggestions.
- Data Smoke Test shows the progression file path and current unlock summary.

## Next Step

The first failure and repair layer now exists in `user://garage_state.json`. The next progression-adjacent step is to connect repair decisions to a lightweight local cost model, without adding backend or online validation yet.
