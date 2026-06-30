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
   - All block, induction, and material choices remain available in Phase 1; progression gating is deferred.

4. Parameter Tuning
   - Tune compression ratio, boost pressure, valve timing, fuel map, and ignition timing.
   - Preview power, torque, heat risk, mass, and reliability margin in real time.

5. Test Bench
   - Run a short neutral engine test before racing.
   - Display RPM, boost, temperature, projected durability, and warning states.

6. Garage Condition
   - Preview wear from saved race outcomes.
   - Track credits, service cost, and budget repair before committing another run.
   - Show block, induction, and material wear separately so repair risk matches the build.
   - Show service recommendations and recent threshold events.

## Screen Layout Target

- Left rail: step navigation and selected setup summary.
- Center: active configuration controls.
- Right rail: live curves, warnings, and track-fit hints.
- Bottom action row: save setup, compare setup, test bench, repair, budget repair, race.

## Current Prototype Mapping

The current Godot shell maps this flow into interactive Engine Builder controls, plus future-phase prototype screens for Race Sim, Analysis, Roadmap, and Data Smoke Test. Canonical Phase 1 should keep the block x induction x material model stable while prototype systems remain clearly labeled.
