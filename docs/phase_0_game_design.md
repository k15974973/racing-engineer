# Racing Engineer - Phase 0 Game Design

## Product Intent

Racing Engineer is a solo-friendly engineering game about designing an engine, racing it against track demands, reading the data, and rebuilding smarter. The player is not just picking upgrades; they are making tradeoffs between power delivery, thermal stress, reliability, mass, and tactical decisions during the race.

The target first experience is:

1. Build an engine from a clear configuration space.
2. Race on a track with different performance demands.
3. React to a few tactical windows during the race.
4. Review data that explains why the setup won or lost time.
5. Rebuild and feel the next setup behave differently.

## Core Loop

`Build -> Race -> Analyze -> Rebuild`

Build: The player chooses an engine block, induction system, and material, then tunes parameters such as compression ratio, boost pressure, valve timing, fuel map, and ignition timing. Every choice should visibly affect projected power, torque, heat, weight, and durability.

Race: The simulation converts the engine setup plus track profile into lap-time behavior. The player does not drive corner by corner. Instead, they act as race engineer during short tactical windows that ask whether to push, cut, cool, conserve, or adjust mapping.

Analyze: The post-race screen highlights where time was gained or lost. It should explain causes using engine data: heat saturation, boost lag, weak low-end torque, poor reliability margin, or wrong tactical calls.

Rebuild: The player returns to the builder with useful direction, not a perfect answer. The fun comes from forming a hypothesis and testing it.

## Screen Flow

- Engine Builder: block selection, induction selection, material selection, parameter tuning, and test bench.
- Race Sim: track selection, race camera placeholder, tactical windows, and live telemetry.
- Analysis: lap timeline, engine report card, setup comparison, and suggested adjustment direction.
- Roadmap: phase checklist for development visibility.

## Phase 0 Success Criteria

- The engine configuration matrix is explicit and data-driven.
- Tactical windows are defined before race code begins.
- The Godot project opens to a readable navigation shell.
- Phase 1 can consume engine data through `GameData` instead of hardcoded UI values.

## Roadmap Fit

The project keeps six near-term phases: System, Engine Builder, Race Sim, Core Loop, Online Async, and Content + Launch. Real-time PvP is deliberately deferred until the async layer proves there is enough player base and enough race data to justify it.
