# Racing Engineer

Mechanics-first Godot 4 scaffold for the Racing Engineer roadmap.

The project currently includes Phase 0, the canonical Phase 1 Engine Builder slice, and future-phase vertical prototype systems:

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
- Persistent progression prototype with clean-race unlock metadata and debug visibility; Phase 1 Builder options stay open.
- Persistent garage condition and economy layer with race payouts, repair costs, budget service, and performance penalties while damaged.
- Hybrid slot-condition prototype for block, induction, and material using approved reliability/durability fields.
- Service recommendations and lightweight service events when slot wear crosses key thresholds.
- Placeholder screens for Roadmap and a data smoke test.
- Phase 0 design docs for the core loop, engine matrix, UI flow, and tactical windows.

Open `project.godot` with Godot 4 and run the main scene.

## Headless Checks

From the project root, run:

```powershell
& 'D:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --scene 'res://scenes/Main.tscn' --quit-after 3
& 'D:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script 'res://tests/data_contract_smoke.gd'
& 'D:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script 'res://tests/curve_differentiation_smoke.gd'
```

## Source Of Truth

This GitHub repository is the primary implementation source of truth. Other scaffold folders or agent outputs should be treated as design input until they are intentionally ported into this repo.

See `docs/implementation_source_of_truth.md` and `docs/phase_scope_audit.md`.

## Current Slice

Strict Part 1 / Phase 0 + Godot Scaffold is complete. Strict Phase 1 Engine Builder is also mostly implemented around the original 3-slot model: block x induction x material.

Race Sim, Analysis, race history, progression unlocks, garage economy, repair, Hybrid slot condition, and service events are running prototype systems for later phases or a possible roadmap extension. They should not be treated as canonical Phase 1 scope until the roadmap is revised.
