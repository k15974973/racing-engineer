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

## Validation

`tests/phase_3_rebuild_instruction_smoke.gd` verifies the loop instead of only checking text:

1. Find a real Technical Loop setup that produces an induction rebuild instruction.
2. Rebuild according to the instruction by trying NA or Supercharger.
3. Race again on the same track.
4. Assert `technical_score` improves by at least 5 points.

Current passing case:

- Baseline: `v8/single_turbo/aluminum`
- Improved: `v8/supercharger/aluminum`
- Score gain: `+21.6 technical_score`

## Next Phase 3 Steps

1. Engine report card from existing `power_score`, `technical_score`, and `endurance_score`.
2. Track affinity label such as "Setup fits Power Ring better than Technical Loop."
3. Save and compare two to three race versions side by side with delta highlights.
4. Simple canonical progression unlock: win Technical Loop to unlock Ceramic material.

Visual tutorial and playtest notes stay deferred until the loop can run at least two Build -> Race -> Analyze -> Rebuild cycles without outside explanation.
