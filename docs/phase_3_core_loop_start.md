# Phase 3 Core Loop Start

## Canonical Phase 3 Step 1

Phase 3 starts by making Analysis teach one concrete rebuild move from race evidence.

Implemented:

- `GameData.analyze_race_result()` now returns `rebuild_instructions`.
- Each instruction includes:
  - `issue`
  - `direction`
  - `target_field`
  - `related_score`
  - `evidence`
- `target_field` points to one of the existing 3-slot builder fields: `block`, `induction`, or `material`.
- Analysis keeps legacy text `suggestions`, but structured instructions are now the primary rebuild contract.
- Analysis UI renders instruction cards with the target slot and evidence.

## Canonical Phase 3 Step 2

Analysis now returns a structured `report_card`:

- `scores.power`
- `scores.technical`
- `scores.endurance`
- `weakest`
- `track_affinity.best_fit`
- `track_affinity.reason`

Report card scores are clamped to 0-100 for UI bars. `weakest` uses the same priority as the first rebuild instruction when an instruction exists, so the report card and rebuild direction cannot point at different builder slots.

Track affinity is calculated from existing track bias data:

`affinity = power * straight_bias + technical * corner_bias + endurance * endurance_bias`

This uses `tracks.json` and does not hardcode Power Ring or Technical Loop, so Track 3/4 can be added later without changing the affinity logic.

## Canonical Phase 3 Step 3

Saved race comparison now keeps the latest three saved runs per track.

Data behavior:

- Persistent race history remains stored as a flat list for backward compatibility.
- `GameData.group_saved_runs_by_track()` exposes the Phase 3 `saved_runs[track_id]` shape.
- `GameData.trim_saved_runs_for_track()` applies FIFO when a fourth run is saved on the same track.
- Existing history is normalized on load so old files cannot show more than three runs for one track.

Comparison behavior:

- Best run is the saved run with the lowest `total_time`.
- Compare UI renders two or three saved runs side by side.
- Each run shows setup summary, total time, and power/technical/endurance scores.
- Best run shows `BEST` instead of deltas.
- Non-best total delta uses `current.total_time - best.total_time`.
- Score deltas use `best_score - current_score`, so positive means the compared run is weaker than best on that score.
- The weakest score row in each run is marked in the compare card.
- Timeline and tactical windows stay out of this compare view.

## Canonical Phase 3 Step 4

Progression unlocks now use data-driven par-time goals.

Calibration:

- `v8/na/aluminum` on Power Ring baseline: `250.36`
- Power Ring `par_time`: `232.83`
- `v8/na/aluminum` on Technical Loop baseline: `307.39`
- Technical Loop `par_time`: `285.87`

Both par times are `baseline * 0.93`, requiring about 7 percent improvement over the baseline setup.

Data behavior:

- `tracks.json` now includes `par_time`.
- `data/unlocks.json` defines unlock rules.
- `GameData` loads and validates unlock contracts.
- Unlock state persists to `user://unlock_state.json`.
- Parts without an unlock rule remain always available.

Current rules:

- Beat Technical Loop par time to unlock Ceramic material.
- Beat Power Ring par time to unlock Compound induction.

Builder behavior:

- Locked options are still visible.
- Locked options render with `[LOCK]`, grey styling, and a tooltip.
- Clicking a locked option is a no-op.
- Unlocked options render normally.

Save behavior:

- `Save Race` calls `GameData.check_and_apply_unlocks()`.
- New unlocks show a non-modal banner for about three seconds.
- `Save Copy` does not re-trigger the same race unlock.

## Current Rule Set

The first rule set intentionally uses existing Phase 2 data only:

- If `technical_score < 60` and the race has a `Corner Map` window:
  - target `induction`
  - recommend reducing lag with NA or Supercharger.
- If heat is above 85 percent of the heat scale and `endurance_score < 50`:
  - target `material`
  - recommend Titanium or Ceramic.
- If `power_score < 50` on Power Ring:
  - target `block`
  - recommend V8 or V6.

Analysis returns at most two rebuild instructions per race and prioritizes the lowest related score first.

## Simulation Adjustment

Technical score now applies an induction-lag penalty scaled by track `corner_bias`.

Reason: before this change, the lowest real Technical Loop setup still scored `70.2`, so the approved `technical_score < 60` instruction condition could never fire. The penalty makes lag matter where it should matter: corner-heavy tracks.

Flag check:

- `v8/na/aluminum` on Technical Loop: `technical_score 78.4`
- `v8/twin_turbo/aluminum` on Technical Loop: `technical_score 71.3`

NA has zero lag and stays above the instruction threshold. Twin Turbo keeps more power but loses technical score on a corner-heavy track, which is the intended behavior.

Power score was also reweighted toward horsepower and torque, with mass reduced to a smaller modifier. This keeps V8 NA classified as a power-biased setup instead of being mislabeled by endurance.

## Validation

`tests/phase_3_rebuild_instruction_smoke.gd` verifies the loop instead of only checking text:

1. Find a real Technical Loop setup that produces an induction rebuild instruction.
2. Rebuild according to the instruction by trying NA or Supercharger.
3. Race again on the same track.
4. Assert `technical_score` improves by at least 5 points.
5. Assert V8 NA favors Power Ring through dot-product track affinity.
6. Assert Inline-4 Supercharger favors Technical Loop through dot-product track affinity.
7. Assert `report_card.weakest` matches the first rebuild instruction `target_field`.

`tests/phase_3_saved_run_compare_smoke.gd` verifies saved-run comparison:

1. Build four real race results on the same track.
2. Save them in slow, slower, slower, fastest order.
3. Assert FIFO keeps only the latest three runs.
4. Assert best run is the lowest `total_time`.
5. Assert total delta equals `current.total_time - best.total_time`.
6. Assert older kept runs have positive slower deltas when the newest run is best.

`tests/phase_3_unlock_progression_smoke.gd` verifies unlock progression:

1. Assert stored par times equal `v8/na/aluminum` baseline `* 0.93`.
2. Assert Ceramic and Compound start locked after reset.
3. Assert block options without unlock rules are always open.
4. Force a Technical Loop result below par and assert Ceramic unlocks.
5. Reload unlock state and assert Ceramic remains unlocked.
6. Force a Technical Loop result above par and assert Ceramic stays locked.

Current passing case:

- Baseline: `v8/single_turbo/aluminum`
- Improved: `v8/supercharger/aluminum`
- Score gain: `+21.6 technical_score`
- Lag check: `NA 78.4`, `Twin Turbo 71.3`
- Affinity check: `V8 NA -> power_ring`, `Inline-4 SC -> technical_loop`
- Saved run compare: kept `Race 2`, `Race 3`, `Race 4`; best `Race 4`; best total `288.94`
- Unlock progression: Power Ring `250.36 -> 232.83`, Technical Loop `307.39 -> 285.87`, one Ceramic unlock.

## Next Phase 3 Steps

1. Visual tutorial after the loop runs two rebuild cycles without outside explanation.
2. Playtest with 5 outside players and record where the loop needs less explanation.
