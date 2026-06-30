# Engine Builder UI Flow

This is the first UI map for Phase 1. It keeps the player moving left to right from identity choices into tuning and validation.

## Primary Flow

1. Block
   - Choose V4, V6, V8, Boxer-4, Inline-4, or Rotary.
   - Show base mass, RPM range, torque character, heat factor, and reliability factor.

2. Induction
   - Choose NA, Single Turbo, Twin Turbo, Supercharger, or Compound.
   - Show power multiplier, lag, heat multiplier, and reliability multiplier.

3. Material
   - Choose Standard Aluminum, Lightweight Titanium, or Extreme Ceramic.
   - Show mass, heat ceiling, and durability tradeoffs.
   - Locked advanced choices remain visible until clean race progression unlocks them.

4. Parameter Tuning
   - Tune compression ratio, boost pressure, valve timing, fuel map, and ignition timing.
   - Preview power, torque, heat risk, mass, and reliability margin in real time.

5. Test Bench
   - Run a short neutral engine test before racing.
   - Display RPM, boost, temperature, projected durability, and warning states.

6. Garage Condition
   - Preview wear from saved race outcomes.
   - Repair current garage damage before committing another run.

## Screen Layout Target

- Left rail: step navigation and selected setup summary.
- Center: active configuration controls.
- Right rail: live curves, warnings, and track-fit hints.
- Bottom action row: save setup, compare setup, test bench, repair, race.

## Current Part 1 Mapping

The current Godot shell maps this flow into interactive Engine Builder controls, a Race Sim screen, Analysis, Roadmap, and Data Smoke Test. Phase 1 should keep expanding these mechanics while keeping part data and progression state outside hardcoded UI values.
