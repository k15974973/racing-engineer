# Implementation Source Of Truth

## Decision

The GitHub repository `k15974973/racing-engineer` is the primary implementation source of truth.

Role split:

- Claude: design advisor and roadmap reviewer.
- Codex: implementation owner for this repository.

Codex should make implementation decisions directly from approved roadmap/design guidance instead of asking the user to arbitrate routine technical choices.

The local Godot project in this repository is the canonical running prototype because it has:

- Runnable Godot 4 project files.
- Structured data files.
- GDScript implementation.
- Headless Godot validation.
- Git history pushed to GitHub.

Other scaffolds, notes, or agent-generated folders are design input until intentionally merged into this repository.

## Working Rule

New implementation should land here first or be ported here through a reviewed merge. Avoid developing parallel codebases for the same gameplay loop.

When another tool or agent produces useful work:

- Treat it as reference material.
- Compare it against the roadmap and current data model.
- Port only the parts that fit the canonical architecture.
- Add migration notes when it changes data contracts.

## Current Alignment Risk

The running prototype intentionally went beyond the initial Part 1 request. That extra work is useful for discovering the engineering fantasy, but it should not be labeled as canonical Phase 1 scope.

The strict Phase 1 source should remain the 3-slot engine builder:

- Block.
- Induction.
- Material.

Race simulation, analysis, race history, progression unlocks, repair economy, service events, and Hybrid slot condition are vertical prototype systems for later phases unless the roadmap is revised.

## Merge Guidance

Before expanding gameplay further, keep this repo as the working implementation and use docs to mark whether a feature is:

- `Canonical`: belongs to the current roadmap phase.
- `Prototype`: running code used to test a future phase.
- `Deferred`: designed but intentionally not implemented.
