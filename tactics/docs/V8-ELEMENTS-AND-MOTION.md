# Elemental ground and character motion

This pass makes existing decisions more expressive: change a route, prepare a slide, displace an opponent, or protect the next exchange. It adds no roster, currency, progression, spell slots or map size. All 30 original identities, their four affinity points, four configured spells and fixed signatures remain.

## Ground rules

| Material | Decision it creates | Exact behavior |
| --- | --- | --- |
| Water | Flood an approach or protect a retreat | Active Water fields cost 2 movement entering or leaving. Flood, Earth, marsh and climbing costs do not stack. Base shallows retain their original rules. |
| Ice | Prepare a fast lane, or make displacement dangerous | Frostbite, Deep Freeze, Water + Air and Water + Dark freeze their affected hexes. Entering slides straight to the last connected icy hex before dry ground, ruins, barriers or the map edge. The full voluntary slide costs 1 effort. Pushes and pulls use the same lane rule. |
| Fire | Make a landing unsafe or thaw a prepared lane | Pure Fire hurts its final occupant for 1. All environmental hazards share a 1-damage cap. Any Fire in a field melts Ice, including simultaneous frost. |
| Earth | Make a route costly or close it with a barrier | Active Earth costs 2 movement entering or leaving. Permanent terrain and existing cover remain underneath fields. |
| Air | Extend an approach or redirect an opponent | Starting on active Air adds 1 movement effort, without stacking with Haste. Rooted still prevents movement. |
| Light | Protect against the next control attempt | Pure Light grants Clarity to its occupant, either team, including incoming control this exchange. |
| Dark | Weaken recovery | Pure Dark applies Wither for next planning. Existing cleansing and healing timing remains. |

Reactions replace the pure Fire, Light and Dark effects. Every affected hex retains its ordinary element/reaction chemistry. Ice is separate validated metadata, not a seventh affinity. Fields expire normally and reveal the seeded biome.

Both teams move using the pre-spell board. Spells then establish their common field, damage and statuses; forces use that newly formed field. Fire has priority over frost regardless of order-list order. Guard and existing Anchored prevent forced displacement. Routes can cross intermediate occupants; competing endpoints collide under the established simultaneous movement rule. Previews show complete traversed paths and actual effort, including free continuation along Ice.

## Animation decisions

The principles used are timing, anticipation, staging, follow-through and secondary action, as described in [Walt Disney Animation Studios' animation process](https://disneyanimation.com/process/animation/). They guide implementation; they are not a claim of comparable production quality.

- All 30 characters have explicit motion profiles, authored around their silhouette and personality. Stoneborn and treefolk brace and settle; lighter characters use shorter accents. These are presentation choices, never combat modifiers.
- The original 1024 by 512 atlases contain eight facings and four poses. Motion uses those real frames; no extra hand-drawn sprite frames are claimed. Feet pivot at their existing atlas position.
- A cast prepares before its projectile moves. Water splashes and settles, Fire rises, Earth lands with weight, Air curls, Light expands and Dark contracts. Ice has a separate crystalline impact and flat cracked ground.
- Actor and healthbar follow the same actual hex path. Ice travel keeps feet planted. Displacement replays every successful segment; stale planning snapshots do not fabricate paths through obstacles.
- Field marks stay underneath trees and ruins. Only a deterministic subset glints or drifts. Overview is still. Large field creation gets one label rather than repeated words on every tile.
- Idle animation is opt-in for the selected/inspected character; roster thumbnails remain static. Reduced-motion disables movement and flashes while retaining effect silhouettes and labels. No per-frame JavaScript animation or new asset download is needed.

## Acceptance and evidence

Engine tests cover all 78 actions, six rotated ice lanes, preview/resolution parity, fresh ice with pushes, thaw order independence, protection, collisions, expiry and strict restoration. Independent tests replay complete seeded matches and reject forged Ice. Renderer tests execute the actual components and cover surface labels, seven material silhouettes, original spell footprints, actor/healthbar routes and resolution input lock.

The HTTP test creates an actual server-side Frostbite field and strict-restores every authoritative snapshot through a complete match and rematch. Existing rules 1–7 engines and fingerprints remain available; old saves use their corresponding pages. New matches use rules/protocol 8. No database schema change is required.

The small paired automated comparison is retained in `element-balance-comparison.json`: six matches per version across three seeds and both seats. All matches lasted eight rounds, mean final score spread stayed four, and V8 defeats rose from eight to twelve. No new inactive rounds or round-cap stalls appeared. The sample uses six champions and fixed policies, casts no Earth spells and does not equip explicit frost spells; it is not a general balance or human-enjoyment result.

Browser evidence and exact publication identity are recorded separately in the release receipt. Desktop/phone viewport checks do not establish physical-device touch performance. Audio is unchanged.
