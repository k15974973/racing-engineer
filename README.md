# Racing Engineer

Mechanics-first Godot 4 scaffold for the Racing Engineer roadmap.

The project currently includes Phase 0 plus the first Phase 1 Engine Builder slice:

- Structured engine data for blocks, induction systems, and materials.
- `GameData` autoload for loading and validating data.
- Interactive Engine Builder selection for block, induction, and material.
- Basic parameter tuning for compression, boost, valve timing, fuel map, and ignition timing.
- Realtime power and torque curve visualization.
- Projected setup stats for power, torque, mass, RPM range, heat, reliability, response, and push margin.
- Timed 30-second test bench with RPM, boost, heat, reliability, and warning telemetry.
- Persistent named setup saving, loading, deleting, and side-by-side comparison.
- Race Sim prototype with track selection, projected lap time, sector fit, and interactive tactical windows.
- Analysis screen with scorecard, findings, tactical review, and rebuild suggestions from the latest race.
- Persistent race history with saved race loading, deletion, and best-run comparison in Analysis.
- Placeholder screens for Roadmap and a data smoke test.
- Phase 0 design docs for the core loop, engine matrix, UI flow, and tactical windows.

Open `project.godot` with Godot 4 and run the main scene.

## Current Slice

The current implementation starts Phase 1 and the first Race Sim slice without full gameplay. It intentionally avoids backend work, 3D race cameras, leaderboards, sound, particles, and PvP. The next build step is a simple progression layer that unlocks parts after clean race results.
