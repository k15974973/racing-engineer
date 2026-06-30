# Phase 1 Garage Economy

## Purpose

Garage economy adds a small local tradeoff loop on top of repair. It is not a monetization system, not online-authoritative, and not balanced for long-term play yet.

## State

Credits live inside `user://garage_state.json` with the rest of garage condition:

- `credits`: spendable local repair budget.
- `total_earned`: lifetime credits from committed race results.
- `total_spent`: lifetime credits spent on service.

Existing garage saves migrate by receiving the starter balance.

## Payout Rules

`Save Race` pays credits once for the current race result. Loading a race from history or saving another copy does not pay again.

Payout considers:

- Base participation payout.
- Track fit bonus.
- Pace bonus for beating baseline lap time.
- Clean race bonus.
- Risk penalty from projected damage, excess heat, and low reliability.

The current payout is clamped to stay useful in early prototype testing.

## Repair Costs

Full repair cost is `damage * 42` credits. If the player lacks enough credits, full service is disabled and the garage reports the missing service requirement.

Budget repair spends up to 650 credits and removes proportional damage. This gives the player a way to recover from risky runs without soft-locking the loop.

## UI Touchpoints

- Race Result previews payout and risk penalty before saving.
- Race Result marks payout as applied after save.
- Race History shows credits earned per saved run.
- Garage Condition shows credits, full service cost, budget repair estimate, lifetime earned, and lifetime spent.

## Next Step

Move from one global damage pool to part-specific wear. Blocks, inductions, and materials should influence both damage generation and service cost.
