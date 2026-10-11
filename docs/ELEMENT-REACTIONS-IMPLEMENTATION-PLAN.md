# Element reaction implementation reference

Status: Historical-plan entry; the single active queue owns further implementation.

This former plan is historical, not an active queue. Its C5/C6 status and disabled
world-mutation instructions predate the integrated whole-hex game.

Use the [current chemistry contract](../SPECIFICATION.md#elements-and-chemistry),
[balance contract](HEX-BALANCE-CONTRACT.md) and the active batch in the
[single implementation queue](../.agent/OVERHAUL-IMPLEMENTATION.md).
Current live policy is `src/sim/hex/hex_recipe_policy.gd`; its 63 definitions cover
all six same-element reactions and 57 distinct two-through-six-element subsets.
Their competitive balance and independent usefulness remain acceptance work.
The [active refinement contract](SIX-ELEMENT-DYNAMIC-REFINEMENT.md) defines bounded
fusion and shared damage funding. Earlier Water cooling repairs are documented in
[the M2 evidence](core-m2-evidence-20261007/README.md).

The [complete original plan](archive/core-docs-20261007/ELEMENT-REACTIONS-IMPLEMENTATION-PLAN.md)
is preserved for rationale and rejected/deferred ideas. It cannot enable
additional elements, moving fields or a second implementation sequence.
