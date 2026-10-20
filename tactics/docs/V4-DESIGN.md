# V4: depth through coupled decisions

The design hypothesis is that a small board becomes replayable when the same action changes value with the rival's kit, likely movement, existing ground, available Flux and future status constraints. Catalogue size alone is not evidence of depth. Prepared-position comparisons, invariant tests, mirrored matches and human play answer different parts of that hypothesis.

## Source and identity

The canonical input is `content/champions/foundation_champions_v1.json`, not the previous six-character web summary. The importer preserves all 30 IDs, current names, ancestry, body category and affinity points; original `wind` is normalized to `air`. `v4-roster-provenance.json` records its SHA-256. All thirty pixel-cast atlases are byte-identical copies from the original H.E.X. repository, with hashes and frame layout recorded separately.

Affinity constrains action economy rather than permission. Specialists buy their main element cheaply; three-affinity characters change roles more economically. Every unfamiliar spell remains an option, but must earn a slot and its extra Flux. Equal health, movement and resource pools keep the comparison legible. Original real-time passives are not transplanted, and characters whose canonical affinities coincide are not claimed as mechanically unique classes.

## One planning sentence

For each mage: move, then choose one equipped spell and aim, or Guard. Lock the company. Both teams execute together. Starter kits make editing optional for a first match. Rival kits, resources and statuses are public so prediction has evidence; selected orders stay private.

Ground targeting creates a commitment: attack where the enemy is going, protect where an ally will arrive, or alter a well without requiring an occupant. Movement collisions can spoil the firing position. The UI shows planned paths and the engine's footprint, and clears an old aim when the selected spell changes.

## Element personalities

| Element | Decision pressure | Tools | Cost or counter |
|---|---|---|---|
| Fire | Can the opponent afford to stay? | Burn, lines, broad attacks, conditional burst | Wet and cleanse remove setup; movement escapes a ground read; stronger casts spend Flux and recovery |
| Water | Which pressure should be absorbed or reversed? | Cleanse, healing, chilling, pull/push, shared Steam | Support gives up an attack; cleansing and healing solve different problems |
| Air | Where should everyone end the exchange? | Displacement, Concussion, Haste, area disruption | Guard and Anchor resist pushes; opposing vectors cancel; positioning constrains targeting |
| Earth | Which route or position deserves commitment? | Barriers, Anchor, Ward, Rooted, piercing Shatter | Terrain creates detours; support loses offense; piercing trades cost for protection bypass |
| Light | Which teammate must retain useful options? | Healing, Ward, Clarity, cleanse, dazzling pressure | Protection needs correct timing; support can concede an objective |
| Dark | Which future response can become inefficient? | Blind, Wither, resource pressure, conditional siphoning | Cleanse, Clarity and Resolve disrupt setup; a curse is weaker when its target does not need the restricted option |

## Simultaneity contract

Movement intent resolves across both teams; valid swaps and cycles may complete, contested destinations bounce. Spell intents use one post-movement board. Effects accumulate before health settles. A defeated caster still completes its committed spell. Push vectors accumulate instead of letting array order choose which push wins.

New restrictions affect future planning. Existing restrictions determine the current legal plan. Cleanse/Wet and control protection use explicit priority rules; Resolve bounds repeated control. Reactions use the union of ingredients at each cell. Each eligible pair applies once; products are not new ingredients. Environmental damage is capped at one per unit per exchange. These limits make triple interactions explainable and prevent accidental cascades.

The engine owns movement, sight, targets, footprints, costs and effects. UI and backend consume that engine. Animation presents causality and never chooses a winner. Replay does not resimulate the game.

## Evidence to player benefit

| Risk | Player benefit | Acceptance evidence |
|---|---|---|
| Array or network order changes results | Fair simultaneous resolution | Permutation, mirrored-seat, deterministic round and concurrent-lock tests |
| Larger catalogue hides cosmetic duplicates | Kits answer different situations | Prepared Ward/Shatter, affinity affordability, cleanse/heal and reaction comparisons |
| Control removes a player from the game | Restricted players retain decisions | Current-cast timing, Rooted still permits casting, Resolve and cleanse regressions |
| More elements create runaway combinations | Players can explain a triple interaction | Pair/triple chemistry tests, finite effects and environmental cap |
| Wrong tap commits an unintended attack | Phone orders remain revisable | Narrow-frame loadout/move/aim/clear/lock flow and fixed dock |
| Retry alters a sealed plan | Friends can finish a remote match | HTTP privacy, receipts, stale-round/match rejection and rematch tests |
| Wiped company loses controls | Recovery and defeat remain playable | Fallback lock/rematch dock and empty-plan recovery checks |

## Human validation still needed

Competitive balance needs strong players deliberately exploiting the system. Learning needs new players making and explaining a first plan without coaching. Mastery needs repeat opponents discovering different answers. Charm needs observation and preference, not an asset count.

The next focused study should watch uncoached pairs play, ask them to predict an exchange before locking and explain it afterward, then record whether they voluntarily rematch and change a kit for a reason. Include physical phones and distinct networks. Simulation timings are not frame rate, and bot outcomes are not retention. “Breakthrough indie hit” motivates the quality bar; it is not a verified property of this release.
