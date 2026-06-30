# Prototype Hybrid Slot Condition

## Decision

Use the Hybrid model.

Wear tracking attaches to the three approved Phase 0 entities:

- Block condition from `reliability_factor`.
- Induction condition from `reliability_mult`.
- Material condition from `durability_mult`.

No physical sub-part entities are introduced.

## Purpose

Hybrid slot condition makes repair consequences match the 3-slot build. A risky race no longer creates only one generic damage number; it also says whether the block, induction, or material slot took the hit. This is a future-phase prototype, not canonical Phase 1 scope.

## Persistence

Slot wear is stored inside `user://garage_state.json`:

- `part_damage.block`
- `part_damage.induction`
- `part_damage.material`

Existing garage saves migrate with all slot wear set to 0.

## Wear Sources

Race wear is split by stress type:

- Heat stress contributes strongly to Material condition loss and partially to Block/Induction condition loss.
- Low reliability contributes strongly to Block condition loss and partially to Material condition loss.
- Tactical push choices contribute strongly to Induction condition loss.
- High-lag forced induction takes slightly more Induction condition loss from tactical stress.
- Better `durability_mult` and heat ceiling reduce Material condition loss.
- Higher `reliability_factor` reduces Block condition loss.
- Higher `reliability_mult` reduces Induction condition loss.

## Stat Penalties

Slot condition changes different setup outputs:

- Block wear reduces torque, reliability, and push margin.
- Induction wear reduces peak power and throttle response, and adds heat.
- Material wear adds heat and lowers reliability/push margin.

Global garage damage still contributes broad degradation, but slot condition controls the shape of the penalty.

## Service

Full service clears global damage and slot wear when the player can afford it. Budget repair spends limited credits and reduces both global damage and slot wear proportionally.

## UI Touchpoints

- Race Result previews block, induction, and material wear delta before save.
- Race Result previews service events when wear crosses thresholds.
- Race History stores and displays slot wear for saved runs.
- Current Setup warns when slot condition is degrading output.
- Garage Condition shows current slot condition, service recommendations, recent events, and service cost.

## Next Step

Keep Hybrid slot condition as the approved future direction. Do not introduce sub-part entities without a post-launch migration plan from the 3-slot model.
