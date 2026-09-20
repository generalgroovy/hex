# Cast and motion acceptance

Status: active user-requested expansion; source gates and visual review in progress.

| Order | Slice | Evidence required |
|---|---|---|
| A | Motion poses follow physical travel, not stale aim/input; frontal south slide | Eight directions across walk/sprint/jump/slide/roll; visual front-slide contact sheet |
| B | Grace Riva (stable ID grace_reava), small sylph, Wind/Water/Light | Existing small template, all ten rows x eight directions, validated three-point budget and existing spells; local/remote switch, cast, save |
| C | Wa Bidi, small goblin, Charge/Wind/Fire | Same contracts, no hybrid attacks, independent cast/cost/reserves |
| D | Clean alternating leg contacts in every direction | Opposite foot contacts, stable body dimensions, repeatable motion captures, no repeated same-leg frames |
| E | Map object polish | Match elevated camera, retain collision footprint and roof cutaway; no new obstacles in movement lanes |

Both new champions initially use existing spells: Grace Riva Rillshot/Gale Burst/
Pocket Eclipse; Wa Bidi Arc Primary/Gale Burst/Cinder Fan. These are basic playable
kits, not claims of completed unique racial abilities. Every spell can still be
configured by any character. Three affinities split the same total three-point
budget 1+1+1; no extra points or automatic damage advantage.

New character pages are 768x960 (ten rows, eight 96px cells) rather than enlarging
the foundation atlas. Immutable generated sources and prompts live under
reference/art/cast_expansion_v1; deterministic packing and audit scripts accompany
them. Existing body templates stay small=58, middle=68, large=76, shared feet and
hitboxes. Grace Riva's spelling changes display only, not the existing roster ID.

Front contacts: all five champions now use reviewed opposite-foot south walk
contacts, also reused by sprint at its own faster cadence. Oh Tipi contact B
comes from only one accepted cell of a later edit; earlier failed drafts and
unrelated changed cells are not consumed. Body bounds never scale per animation.

Moving casts retain their walk/sprint, air or low body animation and travel
direction; spell aim stays in the separate bare-hand effect layer. Stationary
casting keeps the aiming pose. HUD medallions crop the same current body atlas,
so new champions and skin/design updates need no second portrait implementation.

The reusable audit also writes `.godot/walk-contact-audit.png`: five rows,
eight adjacent A/B pairs in S/SE/E/NE/N/NW/W/SW order. Coverage and duplicate-cell
tests pass separately from art review. Remaining D work: strengthen weak
side/back contact separation (especially Grace E/NE/N), verify every gait as a
time sequence, and correct anatomy/registration artifacts rather than claiming
that different pixel hashes prove correct legs. Human charm/feel acceptance is
still open. E currently supplies shared prop ground contact and fountain fade;
broader object simplification remains pending. No new collision or chemistry.
