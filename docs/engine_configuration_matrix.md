# Engine Configuration Matrix

The first playable matrix is `block x induction x material`. Each axis must create a real tradeoff, not just a bigger number.

## Block Axis

| Block | Strength | Weakness | Track Fit |
| --- | --- | --- | --- |
| V4 | Light, responsive, efficient | Lower peak power | Technical tracks and reliability races |
| V6 | Balanced torque and mass | Less identity at extremes | Mixed tracks |
| V8 | Strong torque and simple power delivery | Heavy and hot | Power tracks with long straights |
| Boxer-4 | Low center of mass and stable heat | Limited peak output | Corner-heavy tracks |
| Inline-4 | Great turbo candidate and low mass | Narrower torque band | Boost-focused builds |
| Rotary | High RPM and compact mass | Heat and durability risk | Short attack runs and high-speed sections |

## Induction Axis

| Induction | Strength | Weakness | Player Question |
| --- | --- | --- | --- |
| NA | Immediate response and reliability | Lower peak power | Can clean delivery beat peak power? |
| Single Turbo | Strong top-end efficiency | Noticeable lag and heat | Can the track tolerate spool delay? |
| Twin Turbo | Wider boosted range | More heat and complexity | Is extra response worth reliability loss? |
| Supercharger | Instant boost | Constant parasitic load | Is predictable power worth efficiency loss? |
| Compound | Extreme output ceiling | High heat and reliability risk | Can the player manage overpush? |

## Material Axis

| Material | Strength | Weakness | Player Question |
| --- | --- | --- | --- |
| Standard Aluminum | Cheap, predictable, durable baseline | Average mass and heat ceiling | Is the safe baseline enough? |
| Lightweight Titanium | Lower mass and better heat tolerance | Lower durability margin | Is pace worth extra fragility? |
| Extreme Ceramic | Highest heat ceiling | Brittle and risky under spikes | Can the setup avoid shock failures? |

## Required Data Interface

Engine block fields:

- `id`
- `name`
- `rpm_range`
- `torque_profile`
- `mass`
- `heat_factor`
- `reliability_factor`

Induction fields:

- `id`
- `name`
- `power_mult`
- `lag`
- `heat_mult`
- `reliability_mult`

Material fields:

- `id`
- `name`
- `mass_mult`
- `max_heat_mult`
- `durability_mult`
