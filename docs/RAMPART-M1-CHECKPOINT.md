# Earth mirror: Rampart checkpoint

Status: verified local portable checkpoint, 2026-09-09; paused at the user's request.
The current source includes later cast additions: 29 playable profiles versus
27 in this frozen build. The evidence below applies to this portable, not those
post-export roster changes; they need their own test/export checkpoint.
Full, actual-game capture, exact-source export, raw Windows boot and same-export
localhost Farflow lifecycle passed. `docs/current-checkpoint.json` selects this build.

[Run the game](../exports/windows-rampart-m1-p47-20260909/windows/flux2.exe) with
its adjacent PCK, or share the [portable ZIP](../exports/windows-rampart-m1-p47-20260909/release/FLUX2-Windows-x86_64.zip)
(97,707,386 bytes). Extract the entire archive; both players must use this build.
No new installer is included. The older historical installer EXE was not found
on the final recheck; its retained receipt is history, not a current download.

## What changed

| System | Current M1 behavior |
|---|---|
| Earth + Earth | Rampart (stable internal ID `fortify`, wire 301): cardinal 64 x 36px temporary stone cover |
| Formation | 180ms warning; no movement blocking; someone already inside can escape without teleporting |
| Active | Up to 3.125s, 32 cover health; blocks movement/shots/rays, supports normal paid wallrun and walljump |
| Exit | Destruction or decay releases movement and stale wall contact; 400ms harmless crumble, then removal |
| Consistency | Every size uses 18px wall clearance; size-only 15/18/21px hurtboxes are unchanged; all teams meet the same wall |
| Budget | Existing spell costs, movement costs, Float/air-dodge budgets and one chemistry payload per cast remain; older-trail reactions retain shorter sustained time |
| Appearance | Six existing editable pixel sequences now form tileable masonry with visible rise/crumble; geometry matches the actual collision rectangle |
| Learning | F4 pair details, compact practice card and README name/effect/counter agree; other cover still permits walking |
| Multiplayer | Prediction carries the exact authoritative wall state; compressed, bounded fragments avoid oversized datagrams and reject stale complete updates |

This is a wallrun/kick surface, not vaulting, a climbable rooftop or a new source
of free invulnerability. Earth mirror alone changes movement collision; Ice,
Charge and other mirror proposals are still queued. Static worldbone is unchanged.

## Try it

1. At the Spell Loom equip **Earth / Rapid / Gravel Stream**. Any character may use it.
2. Aim at an empty patch about 100-200px away; tap the spell twice at the same spot.
3. Watch the stone warning rise into an active ridge. Walk into it, then along its face.
4. Use **V** with along-wall movement for wallrun; use **Space** for a legal walljump.
   Your customized bindings take precedence; F4 Movement shows the current controls.
5. Destroy the ridge with attacks, or wait for crumble: passage and contact must release.
6. Repeat with Small, Middle and Large. Clearance should feel identical, despite
   distinct body/stamina/health profiles. Try opposite-side approaches with a friend.

For an uninterrupted wall comparison use Rapid: it does not leave flight trails.
Bolt/Heavy/Wave can combine with an older trail before the intended terminal,
which legitimately makes a shorter-lived reaction earlier along the path.

## Evidence and boundaries

Full: **95 suites / 537,802 assertions**, zero failures/warnings/stderr, including
617 Rampart assertions and actual ENet delivery. The maximum 32-surface raw
reconciliation was 1,872 bytes; the corrected normal wire packet is 1,000 bytes,
with an independently exercised <=1,392-byte fragment fallback for larger input.

Actual-game capture: **38 frames**, with real paid Earth Rapid pairs across all
three sizes. Formation, active movement contact, harmless decay and reopened
passage are shown. Drawing does not change world hashes. A same-state comparison
with only chemistry drawing suppressed measures visible stone contrast; all
three sizes pass. The final audit checks both deposit and reaction triangles.

Delivery: 3,083 frozen runtime/test/package files unchanged across testing and
export. PCK SHA256: `23918264334a2c1dd013c0403903c53dda751155f8bd5dea2db27c18d98865b7`.
ZIP SHA256: `1af4d42cc71a9a091ad6e64682e3852b75ead65a297638fe9004e45d3e9a943f`.
[Immutable receipt](evidence/windows-rampart-m1-p47-20260909/checkpoint.json)
pins source, Full, capture and payload identity. Exact exported localhost
host/join/reconciliation/round/late-join/rematch/stewardship passed on UDP24972;
all three process stderr logs are empty and owned helpers were closed.

![Actual paid Earth Rampart and movement contact](evidence/windows-rampart-m1-p47-20260909/inputs/capture/oh_tipi-rampart-contact.png)

The new atlas adds 1,181 compressed PNG bytes; texture count and decoded atlas
budget are unchanged. Only six Earth-mirror sequences were reauthored. The
disposable backend-drawing probe was removed; its result is retained. Existing
working builds, original art and failed-test evidence are preserved.

Human fun/style acceptance, physical two-PC Internet play and sustained rendered
120 FPS are **not certified**. The prior eight-player CPU-budget miss remains
open; do not present the 120Hz engine setting as a performance guarantee.
No new installer, publication, push or branch unification is part of this slice.

Next: M2a Ice mirror and M2b Charge mirror, separately; then the other mirrors,
basic race visuals Small -> Middle -> Large, and Wellspring workshops/expansion.
See the [single active queue](../.agent/OVERHAUL-IMPLEMENTATION.md) and
[approved design reference](MIRROR-AND-WORKSHOP-PLAN.md).
