# Phase Scope Audit

## Purpose

This audit separates strict roadmap scope from the running vertical prototype. It exists to prevent Phase 1 from absorbing every useful idea just because it is already implemented.

## Strict Roadmap Scope

Phase 0:

- Design docs.
- Engine data matrix.
- Tactical window spec.
- Godot scaffold and data loader for the requested Part 1 slice.

Phase 1:

- Engine Builder.
- 3-slot composable setup model: block x induction x material.
- Engine health from approved reliability and durability fields.
- Test bench and projected setup stats.
- Data-driven UI values through `GameData`.

Phase 2:

- Race Sim.
- Track selection.
- Tactical windows during race.
- Race results.

Phase 3:

- Analysis and suggestion system based on race data.
- Rebuild advice.
- Setup comparison using race outcomes.

Unassigned / Roadmap Extension:

- Currency.
- Repair budget.
- Garage economy.
- Service thresholds.
- Hybrid slot condition.
- Service events.
- Continuous parameter tuning, unless Phase 5 formally pulls it into launch content.

These are valuable systems, but they need an explicit roadmap slot before being treated as production scope.

## Current Running Prototype

The current Godot project includes Phase 0, most of strict Phase 1, and several vertical prototype systems from later phases.

Implemented as canonical or near-canonical Phase 1:

- Engine data loading.
- Engine Builder selectors.
- Engine health.
- Projected stats.
- Curves.
- Test bench.
- Saved setups.

Implemented as canonical Phase 2 start:

- Race Sim.
- Tactical race choices.
- Track contract validation.
- Race result smoke tests.

Implemented as canonical Phase 3 start:

- Structured rebuild instructions from race data.
- `target_field` guidance back to the 3-slot builder.
- Engine report card with power, technical, and endurance bars.
- Dot-product track affinity using `tracks.json` bias fields.
- Saved-run comparison with max three runs per track and FIFO trimming.
- Par-time progression unlocks for Ceramic and Compound through `data/unlocks.json`.
- Rebuild instruction smoke test that races again and verifies the related score improves.

Implemented as future-phase prototype:

- Race history.
- Multi-rule progression metadata outside the canonical par-time unlocks.
- Garage damage and repair.
- Local economy.
- Hybrid slot condition.
- Service recommendations and threshold events.
- Continuous parameter tuning controls.

## Data Model Alignment

The canonical Phase 1 model remains 3-slot composable:

- `block`
- `induction`
- `material`

Approved model decision: Hybrid.

Model definitions:

- 3-slot original: Engine = 1 block + 1 induction + 1 material. These approved records already expose `reliability_factor`, `reliability_mult`, and `durability_mult`.
- Parts-based: Engine = many physical sub-part entities such as turbo, piston, ECU, or radiator. This would require new tables and a new data model.
- Hybrid: keep the 3-slot model and track three independent slot conditions: Block condition, Induction condition, and Material condition.

The running prototype must use the Hybrid model. Wear attaches to the three existing slot entities and scales from the approved reliability/durability fields. It must not introduce physical sub-part entities.

Examples:

- V8 + Naturally Aspirated + Standard Aluminum should keep Induction condition stable longer because naturally aspirated induction has low stress.
- Inline-4 + Twin Turbo + Titanium should lose Induction condition faster because forced induction is the obvious stress point.

Parts-level detail such as pistons, ECU, radiator, or individual turbo units is a post-launch depth target. Do not build it in this roadmap pass.

Phase placement:

- Hybrid slot condition needs race data, so it belongs to Phase 3 or a later explicit Garage/Economy phase.
- Phase 1 should not add new work for wear. The approved fields are already present and ready for later consumption.

## Recommendation

Keep the current GitHub project as the implementation source. Treat the extra systems as a playable vertical prototype, then decide whether the roadmap should formally add a Garage/Economy phase or move those systems behind a feature flag.
