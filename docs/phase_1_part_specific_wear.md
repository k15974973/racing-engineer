# Phase 1 Part-Specific Wear

## Purpose

Part-specific wear makes repair consequences match the build. A risky race no longer creates only one generic damage number; it also says whether the block, induction, or material took the hit.

## Persistence

Part wear is stored inside `user://garage_state.json`:

- `part_damage.block`
- `part_damage.induction`
- `part_damage.material`

Existing garage saves migrate with all part wear set to 0.

## Wear Sources

Race wear is split by stress type:

- Heat stress contributes strongly to material wear and partially to block and induction wear.
- Low reliability contributes strongly to block wear and partially to material wear.
- Tactical push choices contribute strongly to induction wear.
- High-lag forced induction takes slightly more induction wear from tactical stress.
- Better heat ceiling materials reduce material wear from heat.

## Stat Penalties

Part wear changes different setup outputs:

- Block wear reduces torque, reliability, and push margin.
- Induction wear reduces peak power and throttle response, and adds heat.
- Material wear adds heat and lowers reliability/push margin.

Global garage damage still contributes broad degradation, but part wear controls the shape of the penalty.

## Service

Full service clears global damage and part wear when the player can afford it. Budget repair spends limited credits and reduces both global damage and part wear proportionally.

## UI Touchpoints

- Race Result previews block, induction, and material wear before save.
- Race Result previews service events when wear crosses thresholds.
- Race History stores and displays part wear for saved runs.
- Current Setup warns when part wear is degrading output.
- Garage Condition shows current part wear, service recommendations, recent events, and service cost.

## Next Step

Expand content and balancing: more track profiles, more part profiles, and tuned service thresholds.
