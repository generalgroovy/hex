# Expanded spell authority and combat decisions

Status: implemented and locally qualified in `p60-6d80c3bce71e`; see [integration evidence](integration.md) for Full/native/package results. References and automation do not establish human fun, balance or sustained performance.
Date: 2026-10-09
Scope: 63 nonempty six-element payloads × eight delivery families; preserves the original 24 live spell wires/order and twelve equipped positions.
Baseline: `.godot/element-expansion-baseline/combat/` contains exact pre-edit copies. The previously qualified p59 portable is retained.

## Identity and data

`element_mixtures_v1.json` defines every mask 1..63. Bits are Earth 1, Fire 2, Water 4, Air 8, Light 16, Dark 32. Ice and electrical techniques remain effects within Water and Fire, never separate ingredients. The 57 mixed names are the existing reaction names; singleton payload names are their elements. A spell is the named payload plus Bolt, Heavy, Rapid, Spray, Mantle, Fuse, Split, or Rebound. The representative element wire is a palette adapter; all chemistry/status/optical decisions use the full mask.

`MixtureCatalog.wire_for(mask,family)`, `mask_for_wire(wire)`, `family_for_wire(wire)`, `definition(mask)` and `all()` are the shared pure lookup interface. New wires use `1000 + 64*family_index + mask`, except the original 24 canonical singleton wires. The alias positions that would duplicate these singleton spells are rejected. AbilityCatalog schema 6 compiles exactly 504 unique mask/family cells. The first 24 runtime entries remain byte-for-byte the same integer sequence. Singleton lookup resolves the stable wire rather than indexing this nonrectangular runtime ordering. All thirty authored starter weaves remain twelve original spells.

Adding elements does not multiply a family's direct damage, projectile count, reaction strength, or material stock. Each extra ingredient adds 15% of base Flux cost, rounded upward to a whole Flux. Status duration declines from 1,000 ms for one ingredient to 600 ms for six. These numbers are local tuning hypotheses, not measured results or values prescribed by a reference game. One real paid cast still owns 600 material units. A mixed terminal can form its named product from one source, funded by actual consumed strength. Existing-source fusion transfers only remaining pools and preserves source disjointness, contact latches, and bounded ancestor expiry.

## Delivery decisions and counters

| Family | Distinct execution | Bound and counter |
|---|---|---|
| Bolt | Existing aimed projectile and cursor-bounded terminal | Existing positive cost, physical cover, finite life/range |
| Heavy | Existing deliberate projectile with contact-centered blast | Existing slow preparation, visible larger body, cover/height gates |
| Rapid | Existing 1-tick preparation/10-tick repeat cooldown at 120 Hz | One paid strength and 2 base Flux per shot; no new free volley |
| Spray | Existing instant finite cone; nearest physical interception | Short range, real cover and target eligibility |
| Mantle | Follows caster, one touch per enemy; movement leaves up to four finite trail pieces | 16 base Flux, 16k shared direct damage pot, 4k touch/2k trail quote, 36 px touch radius, 1.4 s lifetime. Approach risk and spacing; same enemy cannot be farmed by overlapping touch/trail. Trails transfer at most 150 of 600 units, preserving at least 450 for terminal. |
| Fuse | Traveling shot lands harmlessly, then 72 full warning ticks before 110 px blast | 18 base Flux, 20k shared pot across victims, 600 ms escape window, cover and airborne avoidance; landing cannot deal an early contact hit. |
| Split | Splits once after 30 travel ticks into two ±15° branches | 10 base Flux, 14k direct damage divided exactly, one 600-unit source divided exactly; both children phase 2 so no recursive split. Capacity refusal postpones splitting without minting stock. |
| Rebound | Uses exact swept wall normal to bank at most twice | 9 base Flux, 11k unchanged direct damage, 350 px/s speed, 2.6 s lifetime and existing cursor range. Banks consume allowance and never create damage or material. |

The four new delivery families require live Hex authority. The retained non-Hex compatibility simulator refuses them before spending Flux; it is not a second implementation of their paid ledger. No FieldState is introduced into Hex worlds.

## Six deterministic on-hit channels

A positive actual Health loss to an unprotected enemy applies each ingredient's channel. Spawn protection, timed dodge protection, owner/team exclusion, zero-loss contacts, and lethal hits cannot create a status. Status damage never applies another status or creates matter.

| Channel | Effect | Bound/counter |
|---|---|---|
| Earth — Fractured Focus | Future cast startup × 1.08 | Does not retime an already paid cast, affect cooldown, or amplify damage. |
| Fire — Burning | Pulses from one finite damage pool | Pool = min(2400, actual hit loss / 4); at most 400 actual Health per 12 ticks. Reapplication replaces one pool rather than adding pools. Protection blocks pulses. |
| Water — Chilled | Ground target speed × 0.88 | Takes the minimum with existing field slow; never multiplies stacked slows or reduces air steering. |
| Air — Gusted | One 80 px/s directional shove on entering the window | No launch/stun/control-state replacement; refresh cannot shove again until the window ends. |
| Light — Revealed | Marks the target for visibility consumers | Root integrates actual reveal subject to opaque geometry; no through-wall reveal claim. |
| Dark — Withered | Blocks otherwise ready Health/Flux regeneration during the window | Does not stop Stamina restoration, alter independent wait clocks, or drain resources. |

On equal status payloads the smaller stable source ID retains attribution; timers take the greater remaining duration. Nonstacking reapplication may refresh a timer without changing source attribution, so UI must not infer an exact elapsed fraction from that source's initial duration. Air shove is an immediate state change. Earth startup is sampled at admission; status timers advance after resource restoration and before movement/combat. Prediction advances clocks and movement effects without authoring Burn damage.

## Replicated state contract

PlayerState appends 48 scalar lanes: six channel rows of `[ticks,potency,damage_remaining,pulse_ticks,owner_id,team_id,wire_id,source_cast_id]`. Expired rows are all zero. Defeated actors clear the lanes. The existing actor indices remain intact. There are no hidden status dictionaries or unreplicated cooldowns.

ProjectileState appends `delivery_phase`, `delivery_ticks`, `delivery_damage_remaining`, and sorted unique `contact_entity_ids` (max 12). Phase 1 means armed Fuse; phase 2 means spent Split. Mantle/Fuse hold their shared pot; other families have no added damage pot. The network adapter pads the contact lane to 12 IDs. Ordinary phase 0 shots retain zero extension fields. Optical splitting also copies phase/timer/contact history and partitions a nonzero persistent pot. Court cast records append `element_mask`; funding triples continue to contain source ID, actual spell wire, and actual contributed strength.

## Primary reference support and limits

* [Paradox: Magicka](https://www.paradoxinteractive.com/games/magicka/about) and [Magicka 2](https://www.paradoxinteractive.com/games/magicka-2/about) establish element composition and hybrid effects as a game technique. They support separating payload from execution and naming composed effects. They do not establish this six-bit catalog, 504 count, exact statuses, or competitive tuning.
* [Noita developer release notes, April 2, 2021](https://noitagame.com/release_notes/20210402/) describe triggers/timers, explosive and contact-related spells, and fixes around repeated projectile creation. [Official release notes](https://noitagame.com/release_notes/) also document bounce spells and explicit caps on projectile/radius effects. This supports clearly timed execution and bounded composition. Our one-split, two-bank, four-trail and shared-pool rules are deliberate local constraints, not copied numeric balance claims.
* [Dave Crooks developer interview about Enter the Gungeon](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-) discusses firing/reload rhythm, readable projectile encounters, and reducing an extra ubiquitous active-reload demand. We retain existing controls while varying movement, travel geometry and commitment. This is designer intent and an implemented reference technique; it is not evidence that our particular tempo is fun or balanced.
* [Riot's official VALORANT 1.09 notes](https://playvalorant.com/en-us/news/game-updates/valorant-patch-notes-1-09/) explain a lingering vulnerability follow-up window and clearer visible effect bounds. The transferable principle is a legible, finite follow-up opportunity. H.E.X. deliberately uses bounded cast/recovery pressure rather than a stacking damage vulnerability. No exact timing or measured outcome is transferred.

## Acceptance evidence

`test_elemental_spell_expansion.gd` is the dedicated live suite: all 504 paid admissions; all thirty unchanged twelve-position starters; 57 real one-source mixed terminals; all eight actual damage/status routes; fixed status/protection/expiry gates; exact finite Split, Fuse and Mantle budgets; physical Rebound and mask-based optical controls; and complete Hex snapshot reconstruction. Root owns registration, parser/import, focused/full tests and native qualification. Test results and remaining limitations must be recorded from actual receipts, not inferred from these authored assertions.

## Independent review findings and resolved defects

The movement reviewer found that staged Split children could reuse one final owner slot, and that stationary Mantle/Fuse objects temporarily disappeared from later optical capacity accounting. Both were repaired by reserving admitted children in the real projectile inventory immediately and retaining stationary objects in that inventory while excluding them only from flight planning. New controls use 15 paid parents, two simultaneous ready splits, one last slot, a separately paid pending cast, and 15 held Mantles plus one moving Bolt. They retain the existing 16-owner / 128-global limits.

The menu reviewer found that generated records used `name` rather than the canonical `display_name`, and missing mixture metadata could silently produce empty teaching and default duration. All 480 new entries now use `display_name`; runtime catalog validation requires names and the complete validated mixture document. Each mask, ingredient list, representative palette, reaction identity, whole bounded duration and exact status potency is checked. A root diagnostic then exposed Godot JSON numeric arrays comparing differently from integer literal arrays; per-scalar whole-number checks repair the legitimate source admission without admitting fractional values.

The initial focused expansion suite reached 16,632 assertions with four fixture failures only: four original spells legitimately infer their family rather than storing an optional raw family property. The fixture now tests the established inference API. This initial receipt does not qualify the subsequent capacity, metadata, or display-name corrections. Root's later receipts are required for final acceptance.

## Concise player teaching

All 63 authored mixture purpose/counter pairs now use plain player language, with no internal tokens and at most 198 combined characters. The 42 larger mixtures describe their actual ring, lane, or disk; entry, burst, movement, dwell, or pulse trigger; and ingredient-specific ground, visibility, or recovery effects. Their numeric damage and finite shared pool remain unchanged. The longest row is Convergence (mask 63). Actual font wrapping remains a root-owned UI test; a character count alone does not prove visual fit.

This teaching describes the terrain reaction, separately from the spell's immediate on-hit statuses. A singleton terminal deposits its ingredient and needs another paid source to form the self-reaction. A mixed terminal may form its named reaction from its own funded source. Light-Dark compound fields block all resource recovery through the existing chemistry gate; the Dark on-hit status blocks only Health and Flux recovery.

## Latest observed focused receipt

The root-owned `.godot/element-expansion-focus-5/engine.log` records elemental-spell-expansion: 17,254 assertions, zero failures; expanded-spell-network: 255, zero; element-delivery-presentation: 15,472, zero; and hex-world-snapshot: 21,466, zero. The same run is not an integrated pass: spell-loom-editor reports 765 layout failures. This receipt qualifies the focused combat checks after the capacity, metadata and name repairs, not the subsequent teaching-copy visual fit or a released build.

The held-projectile capacity fixture directly proves the inventory and available-capacity gate, not a complete optical contact with that full inventory. Existing optical resolver controls are separate. No broader combined-path claim is made.
