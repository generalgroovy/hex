# Presentation follow-up: paths, projectile clarity and bounded work

This is scoped evidence for the smoothness follow-up after the preserved `p60-845f85b5253e` portable. It does not inherit that build's Full, package or lifecycle qualification. The [pass ledger](README.md) owns final candidate identity, foreground profiling and delivery status.

The post-withdrawal source is frozen at `p60-be680e20d70e`. Its clean [Full regression](full-final.json) passed 261 suites and 7,401,986 assertions with zero failures and stderr, including the 120 Hz boot check. The matching portable passed separate [package/archive](delivery-files.json), [133-image terrain](terrain-pack.json) and [five-case lifecycle](portable-lifecycle.json) checks; both paid cases admitted 12 casts with zero refusals, all closes were normal, stderr was empty and isolated preferences stayed identical. Its final foreground attempt expired before Start, with no gameplay measurements; the earlier `46fca` profile remains intermediate evidence only. The [performance assessment](performance.md) preserves that distinction and the failed setup receipt.

## Implemented changes and rationale

Movement trails now reuse eight fixed actor records and 48 fixed segment records. Sampling follows actual interpolated, height-adjusted body anchors. A bend or reversal starts a new witnessed leg while preserving earlier fading strokes; it cannot connect across a corner. Work is bounded independently of distance and speed: at most six segments per actor, 16 pixels per segment, 96 line draws and 432 current-visibility probes per frame across eight actors. Pause, hidden/omitted actors, invalid samples, corrections/teleports and reduced effects retain their reset behavior. No gameplay movement, collision or resource authority changed.

This applies the speed-independent work principle from [Riot's Rakan trail investigation](https://www.riotgames.com/en/news/profiling-real-world-performance-league). It does not import Riot's renderer or claim equivalent frame performance. [League's clarity guidance](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/) supports keeping direction, identity and important bounds ahead of decorative accents.

Projectile drawing now borrows six immutable normalized sector templates and creates only the current draw's vertices, colors and UVs. Diagnostic model APIs remain detached. The material body, all ingredient identities, direction/delivery marks, physical-radius marks, Fuse warning/countdown and Mantle coverage/resource marks remain. Two decorative rim arcs were removed intentionally. Glyph drawing reads the current shape directly without allocating the diagnostic shape/cadence dictionary; unknown shapes still fail closed. No new player-facing text or controls were added.

## Focused and native evidence

Root's initial focused gate passed `character-movement-trail` 10,683 assertions, `projectile-surface-depth` 92,522, and `element-delivery-presentation` 15,638. Gameplay independently reviewed the fixed-pool/corner logic, the ordinary paid movement test, exact sector geometry/UV/color comparisons and detached output checks. These are scoped passes, not a replacement Full run.

The [native projectile receipt](../../.godot/projectile-submission-20261012-a/receipt.json) passed 57 frames: 210 declared projectile cases and 48 glyph cases, with zero stderr reported by root. Every original-versus-optimized-with-arcs image matched exactly in RGBA; all frozen-versus-current glyph comparisons also matched. Production without the two arcs is recorded separately as an intentional visual difference. The cases cover all 63 masks in both effects modes plus seven travelling/persistent families at representative masks, directions, strengths, radii and declared delivery states.

All projectile variants receive the same current model, and their glyph dependency is shared. Consequently the separate frozen glyph comparison is required for the combined rendering conclusion. This check does not compare predecessor model generation, paid admissions or GPU timing. Root inspected projectile frames 001/015/032. The experience reviewer inspected 026/041 for armed Fuse warning and countdown, 050 for lifted Mantle/shadow in both modes, and 031/052 for six-ingredient Mantle identity and budget marks. No missing danger, coverage or ingredient cue was found in those samples.

The fixture measured alternating variants within one draw callback, discarded submitted commands after the measured interval, and excluded two warmup batches. Twelve measured batches per variant produced:

| CPU submission only | Mean µs/call | Median µs/call |
|---|---:|---:|
| Frozen projectile draw | 741.77 | 696.32 |
| Optimized projectile, same arcs | 677.46 | 656.60 |
| Production projectile, arcs removed | 646.16 | 627.69 |
| Frozen glyph draw | 35.924 | 33.682 |
| Current glyph draw | 31.686 | 30.698 |

These are isolated submission costs on representative declared states. They exclude simulation, pixel readback, display latency and GPU execution; they do not establish an equivalent reduction in frame time or smooth 60 FPS.

## Actual paid trail route and wording correction

The [paid trail receipt](../../.godot/trail-route-20261012-a/receipt.json) passed 40 native captures covering 160 ordinary 120 Hz simulation ticks. One actual Oh Tipi character sprints, admits slide/jump/air dodge, turns and brakes through ordinary commands. All 40 presentation boundaries preserve the world hash; 38 show visible strokes, no frame exceeds six segments, and Stamina decreases from 660,000 to a minimum of 571,067 without a refill. The [nine-frame filmstrip](../../.godot/trail-route-20261012-a/filmstrip.png) shows the body-aligned trail through the turn and lifted poses, with prominent protection cues. Root and the experience reviewer independently inspected it.

The original receipt says `Native30FPS`. That describes an arranged sampling interval, not measured wall-clock FPS: four simulation ticks are advanced per native capture and the presentation receives `1/30` second. Read it as **30 Hz presentation sampling**. The receipt is preserved unchanged. Its exact executed helper was reconstructed under [the ignored executed reference](../../.godot/smooth-casting-originals/capture_paid_trail_route_executed_20261012.gd), matching SHA-256 `d0bedcafad92994ccb2b220f410b4cda55ec59dd1b5583e4c0ac230383f4580b`. The current helper changes only that scope wording; its hash is `00fd43a9c357bdeb2888fe8f47dc67609cb08ecbe458f758611170e25b683609`. No rerun or gameplay change is represented by this correction.

## Provenance and limits

| Local artifact | SHA-256 |
|---|---|
| Projectile receipt | `2fc8c67dac5c8240e422813b9a3b1afe3be93c7bb49bcaec4821b43482fd95a4` |
| Paid trail receipt | `773a0b5383a2b6f7d5a65aa1118ceef482825d066f97f2937f58e4013a8e9d49` |
| Paid trail filmstrip | `37661c28a25af25983c15b1d891e16fe1c9f20f0c746b2cf212745275d77628a` |
| Trail runtime source | `2eaf62e315d5233ea0f62ecad120a32efeb8f088d28df5ea39f4ff90d6cde6f5` |
| Projectile runtime source | `fd81453cef079520467c980eb4e91738dda63c4aafae27357d8604f33145dfd2` |
| Glyph runtime source | `802330a87639902f31fbf5ba94ceed2f849646d4dc3e59747c801db50093d6df` |

The linked raw captures and helpers are preserved local ignored evidence. Full source hashes and individual native-frame hashes are in their receipts. The experience reviewer also reviewed the exact Garden spatial memo, finite projectile range/counter tests and rival-range adaptation. Court/world batching and its style memo were reviewed and then withdrawn after slower paired native submission measurements; they are not retained production changes. The ground timing fixture was corrected to assert actual callback order, and its Mantle attempts retain their actual admissions/refusals. The technical ledger preserves those negative results separately from the retained Garden and presentation changes.

Sampled pixels and a finite paid route do not establish physical-controller behavior, human animation/movement acceptance, complete competitive balance, network correction/privacy behavior in live play, or smooth frame pacing. Those remain separate gates. No source, engine or package was run by the experience subagent; root serialized all engine verification.
