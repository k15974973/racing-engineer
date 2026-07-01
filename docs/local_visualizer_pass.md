# Local Visualizer Pass

## Decision

Online Async is paused until the local build, race, analyze, and rebuild loop feels clearer and more tactile.

The next visual target is a compact garage-style builder: the car/engine becomes the center of the screen, similar in role to a character model in a loadout screen. Racing Engineer should use an engine model instead of a character model.

## Current Implementation

The Builder now includes a procedural 3D engine visualizer. It is intentionally lightweight and data-driven:

- Block choice changes cylinder count and layout.
- Induction choice adds NA throttle, turbo, twin turbo, or supercharger forms.
- Compression changes chamber/sleeve size.
- Boost changes intake and forced-induction scale.
- Fuel map changes fuel rail scale.
- Ignition timing shifts spark plug placement.
- Pistons, cam rail, crankshaft, pulleys, turbo wheels, and rotary rotors animate while the builder is open.

The visualizer reads from the final calculated setup object, not seed values, so it follows the same source-of-truth rule used for curve physics and report output.

## Scope Boundary

This is not the final art pass. It is the first local UX pass that makes tuning changes visible. The model should keep the character of an engine without requiring detailed production assets yet.

Deferred until the later polish phase:

- Real authored engine meshes.
- Car shell / garage background.
- Sound, turbo spool, exhaust effects, and particles.
- Full CS2-style loadout composition and transitions.
- Online Async.

## Test Standard

- Headless smoke test verifies tuning values alter visual state.
- GUI render smoke exports a PNG and checks that the viewport is not blank.
- Visual review confirms the model is framed, readable, and recognizably engine-like.
