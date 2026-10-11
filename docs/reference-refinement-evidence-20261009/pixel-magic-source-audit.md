# Pixel magic source guard renewal — October 9, 2026

Status: **SOURCE DIFF REVIEWED; renewed test execution remains a root-owned gate.** The world/menu reviewer and root independently inspected the same preserved pre-edit chemistry file and the complete current diff. This is a narrowly qualified guard renewal, not a new visual, gameplay-balance or release acceptance.

The preserved file is `.godot/reference-refinement-baseline/damage-events/src/sim/chemistry/element_chemistry_system.gd`. Its raw SHA-256 is `de173e737321a45274f9a59f1bd4165fb8f2bc1ab28c500203232e8e37cf818a`, exactly matching the previously reviewed digest in `test_pixel_magic_library.gd`. The current file hashes to `30a5d07daf8dacf73dbed2fedda71ba7bc8138f1d610f90aacdc279ad95e7a2b`.

The complete difference is one local addition and one event-field replacement in `_apply_result`: capture `actor.health` immediately before the existing `PlayerResourcesSystem.damage` call, then report `health_before - actor.health` as `chemistry_hit.damage`. This makes the receipt reflect realized Health loss after defensive/vulnerable perk scaling and lethal overkill clamping. The same successful-damage branch emits it; the source actor, target, reaction and defeat attribution fields remain.

No recipe row, deposit admission, footprint membership, collision test, height/ground gate, spawn/dodge protection gate, contact bookkeeping, control application, damage amount entering the resource system, phase/pulse clock, quantity or deposit lifetime changes in this diff. It does not modify a pixel asset, atlas frame, palette, manifest or presentation lookup. The underlying perk damage behavior was separately introduced in the resource system; this source audit does not reclassify it as a cosmetic change.

The new test digest therefore acknowledges only the reviewed receipt-accounting change. The library test retains its exact source-difference allowlist, raw manifest identity, page/asset hashes, frame and absolute-clock checks, palette checks, and deliberately stale additional-source negative control. Any further change to this chemistry file again fails the exact digest assertion and requires a new audit.

The actual manifest read for this review is `art_batches/pixel_v1/magic/manifest.json`, SHA-256 `6cdf1d12d08dc80ac6605bbffc1cc81b01c3d0931a0067057888b71f32259638`. This records which manifest was inspected; a hash alone does not prove visual quality. Root's fresh test receipt and native inspection remain the acceptance evidence.

Related: [design and acceptance record](../REFERENCE-IDENTITY-REFINEMENT.md), [combat evidence](combat.md), [world/menu evidence](world-menu.md).
