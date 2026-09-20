# Tactile arena movement and readability acceptance

Status: **T0-T4 source candidate complete; human feel/charm acceptance pending**.

This slice makes FLUX easier to read and more expressive without adding another
movement technique. It applies broad action-roguelike principles—quiet floors,
clean projectile lanes, compact combat state and immediate response—through
FLUX's own Wellspring art and rules. It does not copy protected rooms, assets,
weapons, characters, interface layouts or exact mechanics.

## Player contract

| Slice | Observable outcome | Acceptance |
|---:|---|---|
| T0 paid sustain | Jump and slide provide a dependable tap, while holding buys extra airtime or travel with Stamina. | Host, prediction and replay share protocol 35; tap/hold/exhaustion are deterministic at 120 Hz; the opening protection timer never refreshes or grows. |
| T1 resource feedback | The compact HUD names Jump/Slide sustain while it is actively draining. | Cost is readable without relying on color; neutral state stays compact; low-resource release is understandable. |
| T2 living Wellspring | Fountains, portals and active stations use restrained presentation-only cycles. | Motion is bounded, cheap and disabled or calmed by Reduced Effects; collision and simulation hashes do not change. |
| T3 combat-first composition | Quiet traversal surfaces, strong actor/projectile silhouettes and concise prompts preserve the play lane. | At 50/75/100% scale the player, threats, interactions and worldbone read in that order; decorative motion cannot masquerade as a hit or spell. |
| T4 integrated checkpoint | Truthful jump and slide captures exercise held sustain, release and ordinary combat framing. | Focused and Full suites, source/import boot and 50/75/100% visual review pass; human feel/charm approval remains explicitly pending. |

## Movement economy

| Action | Guaranteed opening | Optional hold | Protection |
|---|---:|---:|---:|
| Jump | 28 Stamina; tap arc cuts at 90 ms | 120 Stamina/s until the 160 ms cap | Existing 90 ms opening only |
| Slide | 22 Stamina; 150 ms committed travel | 60 Stamina/s until the 300 ms cap | Existing 50 ms opening only |

Release and exhaustion end only the optional extension. They do not refund the
opening, reset cooldowns, add speed, bypass world collision or purchase another
defensive window. Slide braking remains a second press; airborne C remains fast
fall. Tuning stays centralized and compatibility-hashed.

## Performance and art constraints

Animate a few landmark accents rather than rebuilding tiles or spawning ambient
entities. Use coarse, repeatable phases, small translucent rings and restrained
contrast. The ordinary frame remains old-world and hand-built: actor first,
projectile lanes second, interactable stations third, environment last. All new
presentation must remain smooth at the single supported 120 Hz frame cap and
must not enter authoritative gameplay state.

## 2026-09-04 evidence

| Proof | Result |
|---|---|
| Focused movement/UI/map gate | 5 suites, 2,746 assertions, zero failures or stderr; `.godot/receipts/tactile-arena-focused-v2.json` |
| Full repository gate | 67 suites, 22,733 assertions, zero failures or stderr; source import and protocol-35 120 Hz boot passed in 35,533 ms; `.godot/receipts/tactile-arena-final-full.json` |
| Paid hold captures | 32-frame Jump and 48-frame Slide sequences at truthful 1280×720/120 Hz; both visibly name their active Stamina rate |
| Scale review | 50%, 75% and 100% world views inspected; the 50% revision removes distant station titles while retaining navigation props and screen-space combat HUD |
| Performance boundary | Illustrated ground still compiles once (64 ms in the final Full run); ambient motion is constant work over a few landmarks/stations, not per-tile regeneration |

This is a tested source checkpoint, not human approval of movement balance,
animation charm, or every device's ability to render at 120 frames per second.
