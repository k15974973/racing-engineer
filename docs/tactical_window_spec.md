# Tactical Window Spec

Tactical windows are short race-engineering decisions. They should appear three to five times per race, last about eight seconds, and immediately affect telemetry and result calculations.

## Window Types

Boost Spike:

- Trigger bias: turbo, twin turbo, and compound builds.
- Choices: cut boost, hold target, push over target.
- Immediate effects: speed gain, heat spike, reliability risk, boost instability.

High Temperature:

- Trigger bias: V8, rotary, compound induction, ceramic stress events.
- Choices: cool, stabilize, push through.
- Immediate effects: lost pace, protected durability, or possible overheat debt.

Corner Map:

- Trigger bias: technical tracks and low-grip sectors.
- Choices: lean map, balanced map, rich map.
- Immediate effects: traction, exhaust temperature, fuel efficiency, corner exit speed.

Straight Attack:

- Trigger bias: long straights and power tracks.
- Choices: conserve, full power, attack mode.
- Immediate effects: top speed, temperature buildup, and reliability margin.

## Trigger Rules

- Turbo setups should receive more boost-related windows.
- V8 and rotary setups should receive more heat windows.
- Technical tracks should produce more corner-map windows.
- Power tracks should produce more straight-attack windows.
- Endurance races should amplify the long-term penalty of repeated push decisions.

## Feedback Requirements

- Telemetry must react immediately: RPM, boost, temperature, speed, and reliability margin.
- Visual feedback should eventually include exhaust color by AFR, smoke, turbo spool, and warning states.
- The post-race analysis must connect each decision to time gained, time lost, or engine damage risk.

## Out Of Scope For Part 1

This slice defines the behavior and creates placeholders. It does not implement live race simulation, particles, audio, backend validation, leaderboards, ghost races, or PvP.
