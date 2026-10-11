# Internet friend play investigation

The current portable remains suitable for local solo testing, not accepted for
different-home play. This investigation preserves the failed multiplayer test
and the rejected optimization so later work can start from measured causes.
The implementation order lives only in the
[single queue](../../../.agent/OVERHAUL-IMPLEMENTATION.md#internet-friend-play-acceptance-slices).

## Fresh evidence

All figures below were measured on this machine on 2026-09-30. The probes use two
eight-caster fixtures, distributed and dense, with three calls per component.
They are diagnostic medians, not sustained capacity or rendered-frame results.

| Evidence | Result and scope |
|---|---|
| multiplayer-baseline |Same p56-606574fca67f Windows export, localhost UDP 24942, isolated profiles; 120 s timeout during late-join/Hearth/rematch. Host snapshot capture/send about 290-334 ms. Owned processes closed by wrapper |
| unified-snapshot-cost-friends-before.json / before-probe |820 assertions, zero failures; full capture 380.085/353.259 ms; world hash 69.668/59.392 ms; packing 3.396/2.998 ms |
| unified-snapshot-cost-friends-cache.json / cache-probe |820 assertions, zero failures; exact typed caches reduced capture to 293.197/280.552 ms and hash to 37.959/31.939 ms. Still unusably expensive; experiment rejected |
| friends-cache-focused-v1.json |Four existing snapshot/hash suites, 4,037 assertions, zero failures/stderr. The later proposed typed-cache-specific test was not verified by this receipt |
| restored-focused |After removal: four snapshot/hash suites, 4,037 assertions, zero failures/stderr; isolated profile restored. This is focused revalidation, not another Full run |
| rejected-typed-cache-*.gd.txt |Archived experimental source, not importable/shipping scripts. Only this run's cache additions and unverified extra test were removed; prior optimizations remain |

After removal, production source identity regenerated exactly to
`p56-606574fca67f`, SHA256
`606574fca67fade91af6ef0c60b3210319fc8f0c36d9aeba7d94c96ae331ca1a`.
No new runtime feature, package or release was claimed for this investigation.
Current and fallback exports were preserved.

## Structural finding

The production snapshot path repeatedly walks the 11,337-cell topology, hashes
the full canonical world and constructs a detached restored world for outgoing
validation. Native packing alone is not the dominant cost. The next candidate
must separate immutable validated geometry from sparse dynamic authority;
simply disabling incoming validation or reducing the player/effect limits is
not an acceptable fix. Canonical meaning changes require explicit versioning.

## Connection decision

Target UX is Create room, copy code, Join. The selected candidate is a packaged
native WebRTC transport, a small room/signaling service and managed TURN relay.
This is an engineering choice to evaluate, not existing functionality.
Official [Steam networking documentation](https://partner.steamgames.com/doc/features/multiplayer/networking)
describes a comparable lobby/relay approach. No Steam SDK or app registration
is assumed.

Godot documents WebRTC signaling and a native GDExtension requirement; its
current tutorial is marked not yet updated for 4.7, so extension compatibility
must be tested with the exact packaged engine, not inferred from the tutorial.
See [Godot WebRTC](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html)
and the [official native extension](https://github.com/godotengine/webrtc-native).

Read-only Cloudflare account discovery and TURN-key listing returned success:
one account accessible, zero TURN keys. No account identifier or credentials
are stored here. No keys, workers, rooms, subscriptions, firewall rules or
public services were created. Account access is not deployment authorization.
Cloudflare's [TURN overview](https://developers.cloudflare.com/realtime/turn/)
currently lists standalone relay traffic at $0.05 per outbound real-time GB;
this is not a total service quote, free entitlement or spending cap. Recheck
provider terms and obtain approval before provisioning. Long-lived keys stay
server-side; only short-lived scoped credentials may enter a packaged client.

The room-code feature may only be called friend-ready after clean packaged
Windows clients complete a real different-home session. A localhost pass,
available hosting account or a generated invite code is not that acceptance.
