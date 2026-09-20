# Living Wellspring V1 acceptance contract

Status: **canonical initial-world acceptance target**. Rows describe required
proof, not an automatic claim that every journey already passes.

## Product gate

Living Wellspring V1 is FLUX 2's first product acceptance test. It is a cohesive
starting world and application shell, not a menu backdrop or a collection of
mechanics panels. Every later combat or adventure mode reuses the systems proven
here. No PvP, PvE, PvPvE, roguelike, stronghold, battle-royale, or custom mode is
described as production-ready before this gate passes.

## Player journeys

The same build must support these end-to-end journeys:

1. Start offline, create/load a local profile, complete or skip accessible
   onboarding, change controls/POV/audio/accessibility, train movement/spells/
   chemistry, inspect the guide and build, interact with the world, save, reset,
   and stop cleanly.
2. Discover connected districts by ordinary paths, learn advanced movement on
   optional routes, attune shrines, and fast travel only to safe clear anchors.
3. See a privacy-safe friend roster, understand why a peer is or is not
   joinable, host or join through LAN/direct/invite/optional directory paths,
   recover from a transient presence outage, reconnect, leave, and block.
4. As host, configure lobby/team/friendly-fire policy, readiness and privacy;
   manage bots/dummies/trials; invite or moderate; use announced safe group
   travel; inspect health; and end the session without orphan processes.
5. Run equivalent source and packaged journeys on the declared Windows targets
   with compatible protocol/content/save versions; preserve portable Linux
   source without making a current Linux package claim.

## World and feeling

Required functional areas are Nexus/arrival, Movement Conservatory, Alchemical
Proving Grounds, Wayfarer social/muster, champion/loadout, archive/guide,
settings/accessibility/diagnostics, recovery/garden, and essential services.
They may share buildings or districts where that improves coherence.

Acceptance requires spacious traversal, recognizable silhouettes without text,
layered near/mid/far depth, strong landmarks, material-rich architecture,
charming responsive ambience, dense decorated edges, clear movement/combat
lanes, readable collision/elevation, accessible ordinary routes, optional deep-
movement shortcuts, and rapid travel after discovery. Broad inspiration may be
drawn from richly staged isometric action environments, but every FLUX 2 asset,
layout, palette ramp, prop, symbol, effect, interface, animation, and camera
metric must be original or compatibly licensed.

Foreground terrain, roofs, foliage, buildings, and constructs may not hide a
character that is inside the viewer's authoritative line of sight. Those layers
fade, cut away, or yield to a restrained ownership-readable silhouette. When
LOS is blocked, the client receives no silhouette, nameplate, shadow, effect,
audio marker, or diagnostic leak. Mutable occluders update both decisions from
the same semantic geometry revision.

## Foundation systems inside the gate

- deterministic 120 Hz movement, collision, elevation, replay and reset;
- an original reusable character skeleton with ground/body/aim/shadow/effect
  anchors and a compact top-down body-lift jump with clear apex/landing;
- validated ancestry and champion layering, one accepted champion/loadout/spell
  path, and one unique non-advantageous taunt plus explicit fallback behavior;
- one bounded physics/chemistry laboratory with immutable worldbone, readable
  reactions, cleanup and exact reset;
- typed world interactions, contextual prompts, focus/disabled/pending/success/
  failure states, and keyboard/controller/accessibility parity;
- versioned settings, profiles, saves, content, session policies and migrations;
- observable performance, networking, logs, replay/desync diagnostics, stop and
  cleanup behavior.

## Friends and host policy

Presence states are offline, online, away, in Wellspring, in another activity,
joinable, invite-only, full, blocked, and incompatible. Privacy decides the
detail exposed. The client never displays private IP/session/location details
unless the owner explicitly uses a direct-connect flow.

The host policy includes lobby privacy/capacity, co-host/ownership, invites and
approval, team creation/naming/color/assignment/balance/locks, spectators,
readiness, late join, bot fill, and explicit friendly-fire/self-damage/healing/
collision rules. Practice privileges include waypoints, dummies/bots, refill,
trial/laboratory reset, announcements, pause, diagnostics, and safe group
travel. Forced porting exists only in an explicitly opted-in host-managed
practice policy with reason/countdown/state/destination checks and an audit
event. Players always retain leave, block, privacy, accessibility, and sanitized
report/export controls.

## Verification matrix

- pure schemas/systems and invalid-input tests;
- deterministic replay/reset at the authoritative 120 Hz;
- full offline start-to-stop journey;
- loopback plus two-machine Windows host/join/reconnect;
- latency, loss, duplication, reordering, invalid privilege, version/content
  mismatch, presence loss, host exit, and cleanup tests;
- gameplay-zoom, grayscale/color-vision, reduced motion/effects, readable text,
  remapping, controller, and audio-alternative review;
- LOS-visible actor cutaway/silhouette and LOS-hidden information-leak tests;
- modest-hardware simulation/render/network/memory/load profiling;
- Windows source and package smoke, save migration, logs, crash
  recovery, update/rollback and clean uninstall.

## Rolling slice handoff

Each runtime slice remains launchable and revertible. When it enters final
verification, the next slice begins only bounded preproduction: acceptance
fixtures, content/schema drafts, interface contracts, and original-asset
provenance. Runtime promotion remains serial. This keeps work flowing without
combining two unstable behavior changes or losing a known-green checkpoint.
