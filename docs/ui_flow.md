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

4. Parameter Tuning
   - Tune compression ratio, boost pressure, valve timing, fuel map, and ignition timing.
   - Preview power, torque, heat risk, mass, and reliability margin in real time.

5. Test Bench
   - Run a short neutral engine test before racing.
   - Display RPM, boost, temperature, projected durability, and warning states.

## Screen Layout Target

- Left rail: step navigation and selected setup summary.
- Center: active configuration controls.
- Right rail: live curves, warnings, and track-fit hints.
- Bottom action row: save setup, compare setup, test bench, race.

## Part 1 Placeholder Mapping

The current Godot shell maps this flow into the Engine Builder placeholder screen and the Data Smoke Test screen. Phase 1 should replace the placeholder columns with interactive controls while keeping the data source in `GameData`.
