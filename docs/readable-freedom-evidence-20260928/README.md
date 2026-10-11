# Readable-freedom evidence — 2026-09-28

Scope: state-aware practice advice and a bounded true-travel projectile cue.
Design goals and cross-asset visual direction are in
[HEX-READABLE-FREEDOM.md](../HEX-READABLE-FREEDOM.md).

Candidate `p56-6523a2fb7648`, source SHA256
`6523a2fb7648caef7b3bc6bb4ec78c61ee328b3784251c738d20d6e74602e90c`.
2,940 production records; protocol 56, snapshot 22, Godot 4.7.1.

| Gate | Result |
|---|---|
| Focused regression | PASS: 9 suites / 99,528 assertions, zero failures/stderr; [receipt](focused-receipt.json) |
| Native practice / projectile specimen | PASS: 12 native 1280x720 frames, zero stderr; [receipt](native/receipt.json); lead reviewed all 12, second reviewer checked the two projectile boards and two expanded cards |
| Separate Windows portable / native safe close | PASS: source/PCK identity, 30-skin art admission and explicit safe-close log; [receipt](package-receipt.json), logs in `package/` |
| Full unfiltered regression | NOT RUN in this presentation-only slice; earlier full receipt belongs to `p56-fa6d17ce9f39` |
| New rendered/dense performance, human feel, physical two-PC | NOT RUN |

No simulation tuning or authority files changed in this slice. Native card
captures use controlled state fixtures to cover availability/absence cases;
projectile boards use production presentation and compiled definitions at actual
75% scale. A native SubViewport isolates synthetic hover coordinates from the
user's OS cursor. Neither is a paid-cast, physical-input or human-acceptance test.
The earlier paid field and dense-combat receipts remain with their original build.

The facet adds at most two small filled primitives per supported live projectile,
with no texture creation, particles, trails, world query or history. That is a
bounded implementation cost, not a measured frame-rate claim. Existing dense
simulation timing is still an unresolved priority; no capacity increase occurred.

Initial source identity generation without `-Force` was safely refused because
the prior manifest existed. The subsequent deliberate generation was superseded
when the user added the visual pilot; only the final frozen identity is used for
acceptance. No previous portable or receipt was overwritten.

## Visual findings and retained failures

The controller binding and spent-dodge text fit; the Steam warning is clear and
within its card. Projectile facets remain inset and preserve the existing element
colours and delivery shapes. These static views do not demonstrate improved
reaction time or motion recognition. Rapid and minimum-strength projectiles
remain only a few visible pixels at 75% zoom due to the existing atlas occupancy
and strength shrink policy. The two Rapid rows intentionally show the same 1/1
strength. Reduced effects retain more prominent fixed contact ticks; that is
existing presentation, not a larger hitbox. Review moving shots over actual
terrain, clutter and colour-vision filters before calling projectile art accepted.

The first Focused preflight rejected a missing documentation `Status:` field;
no suites ran. [The rejection receipt](focused-preflight-rejected.json) is retained.
Native attempt v1 stopped on the frozen startup input-rearm gate; v2 rendered one
compact frame but stopped because native-window pointer position did not follow
a synthetic viewport event. No OS cursor was moved. The final capture uses an
isolated SubViewport and explicitly rearmed controlled state; v3 passed. Both
failed attempts' stdout/stderr are retained in `capture-failures/`.

Receipt paths preserve their original run locations. Byte-identical durable
copies of the successful suite log/current-state report are under `focused/`;
the 12 PNG copies in `native/` were checked against every receipt SHA256.
The final ZIP and every payload entry in `SHA256SUMS.txt` were rechecked after
packaging. The current-scope documentation check passed after handoff updates.
No owned Godot/H.E.X. process remained. The checkout stays on `main` at
`1559a566e33255c59337c5963f1c3c685d757f1f` with its pre-existing dirty work;
no commit, push, publication, installer or pinned checkpoint promotion occurred.
