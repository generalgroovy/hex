# Wellspring Reach: room to stand, room to manoeuvre

The user's request is physical and tactical scale: hexes that fit every original character, a substantially larger and more interesting map, and spell reach and coverage scaled with it. This update retains the 30-character roster, 48 spells, three-mage teams and simultaneous orders.

## Geometry and composition

The original 128px animation frames are drawn at 192px on the battlefield. The former 88-unit tiles were narrower than several character silhouettes and foot spans. The revised tile geometry is derived from alpha bounds across the original atlases, while preserving the sprite drawing size. Terrain, selection, target footprints and pointer hit surfaces share the enlarged geometry. A tactical camera preserves useful character size; Overview provides whole-map orientation, and effect fitting shows the selected footprint.

## Geography

Wellspring Reach has radius six and 127 playable hexes, compared with 61 in v5. A visible, reusable seed generates two six-cell Earth terraces, two six-cell Water channels and three wells. The centre well remains fixed; a mirrored outer pair varies between four arrangements. Deployments, terrain and wells are mirrored through the centre. These are usable ground surfaces, not impassable decoration. Climbing costs two movement effort and elevation extends casts against lower ground. Streams and terraces supply their element to chemistry; temporary fields expire back to the natural substrate.

The outer routes give a company alternatives around raised ground and temporary barriers. Objectives remain central enough to contest early; the increased area must not be justified by empty travel.

## Reusable seeds

Seed text is canonical uppercase ASCII letters, numbers and hyphens, 1–24 characters. The v6 generator uses a fixed hash and PRNG with finite connected growth; it never depends on browser randomness, time, iteration retries or external services. `WELLSPRING` retains the curated reference layout. New seed selection uses browser randomness only to choose the text, then the same deterministic generator builds the geography.

The camp preview renders all 127 generated cells. A map link contains only the seed; a private match invitation separately grants joining access. The host's stored canonical map ID determines the online map, and a guest cannot override it. Saves, reconnects and rematches retain the seed. Strict save restoration checks that cell geometry matches the selected seed. Future rule versions must preserve this v6 algorithm for old replays.

## Scale of actions

- Normal movement: three effort. Chilled reduces it to two; Haste adds one and Rooted prevents movement.
- Typical spell reach: three hexes. Close-range commitments reach two; long spells reach four or five; self spells remain self-only.
- Tidal Surge: five-hex directional crescent with increased cost and recovery. Raise Cairn retains its three-hex strip so it remains a local obstacle.
- Selected wide control/support spells cover a 19-hex burst or 12-hex hollow ring at increased cost/recovery. The high-damage and ally-safe burst alternatives stay compact.
- Ground previews and the authoritative resolver use the same exact footprint. Board edges clip effects; target elevation and Blind affect reach.

## Compatibility and acceptance

New games use rules/protocol six. The frozen v5 resolver, catalogue, UI and renderer retain the 61-cell game at `/v5`; v4 and earlier remain available. Sealed v5 plans, fingerprints and retry receipts must survive unchanged. Current custom loadouts are retained under a new storage key.

Acceptance requires all character foot bounds fitting their tile; complete directional and area previews; mirrored, connected geography; valid terrain expiry/restoration; predictable movement and reach; private remote plans and exactly-once resolution; and a usable desktop/phone select–aim–confirm–lock flow. Automated matches measure fixture pacing and symmetry, not human balance or physical-device usability. See V6-VERIFICATION.md for the completed checks and limitations; the external release receipt identifies the exact published source.
