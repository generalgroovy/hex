# M3 movement consistency and documentation consolidation

Status: October 7 source candidate `p57-51512b1ea1f1` passes focused, Full and
post-fix actual-input validation. Not a packaged release or human acceptance.

## Change and invariant

A lower-priority Slide edge could short-circuit held Jump handling at a wall.
Jump alone entered wallrun, while Jump plus Slide instead spent the character's
double jump or flight allowance. The same guard could swallow wall-jump release.
One effective Slide-intent predicate now serves both the held-Jump handler and
free fast-fall. Effective Evade/Jump priority and ignored held-repeat semantics
agree without changing costs, geometry, speed, momentum formulas or wire fields.

Regression cases use paid wall approaches on four mirrored faces, both tangents,
flight/nonflight actors and discrete/held/combined Slide edges. Additional
controls cover neutral/directed release, exact wall costs, legal kick momentum,
canonical continuation, Slide-only fast-fall, held-repeat detachment and all
eight flight/takeoff headings. These tests do not establish human movement feel.

## Evidence boundaries

| Gate | Result |
|---|---|
| Red production regression | FAILED as intended: 1 suite / 34,400 assertions / 264 semantic failures; zero stderr |
| First green attempt | STOPPED before engine tests: missing explicit status in rewritten core-design document; corrected, failed receipt retained |
| Focused green v2 | PASS: 10 suites / 132,260 assertions, zero failures/stderr |
| Independent movement review | No actionable defects; exact frozen production/test hashes matched; no engine run by reviewer |
| Full / import / identity / configured boot | PASS: 220 suites / 3,965,803 assertions, zero failures/stderr; configured 120 Hz boot and exact identity pass |
| Actual Bootstrap input journeys | PASS: 12 routes / 7,547 checks, three catalog sizes each for flight, double jump, dodge/fast-fall and wall routes; zero stderr; exact M3 runtime identity |
| Native visuals, human feel, dense timing, physical Internet | Not established by these checks; historical dense timing failure remains |

Release and additional held-repeat wall controls were added after the red run;
the red result does not claim to have executed those later cases. The red
wrapper's generic error text reflects assertion failure, not nonzero stderr.

## Documentation work

One short specification, one queue and one resume replace repeated checkpoint
narratives and contradictory active-looking rules. The player-first README
distinguishes tested source, existing team installer/portable and historical
pointer metadata. Archived plans are clearly historical entries, not other queues.

Corrections include current grid/protocol/spell scope, strength-subtraction
chemistry, no trails, pixel-art availability versus incomplete animation cycles,
unavailable physical attacks and restoration of character-specific saved weaves.
No character identities, affinities, size assignments or gameplay tuning changed.

Exact prior versions remain in `docs/archive/core-docs-20261007/`, with separate
pre-consolidation README and roster archives. No original artwork or existing
packages were removed. Documentation validation and archive hashes are recorded
separately from engine acceptance.

The validation-owned engines used isolated preferences and exited; the engine-run
guard is released. The evidence-copy helper's empty accidental directory was
removed after checking its exact path and emptiness; no user data was removed.

Receipts: [red regression](red-v1.json), [pre-engine documentation refusal](green-v1-doc-guard-failed.json),
[focused green](green-v2.json), [Full](full-v1.json),
[actual input](advanced-receipt.json), [independent review](independent-review.json).
Companion logs/state files are exact-hash copies of their recorded originals.

## Human source playtest

From the repository root, with the pinned development Godot installed:

```powershell
.\scripts\run.cmd --pixel-cast
```

The pixel flag also enables full-body art. The existing team installer/portable
does not contain M1/M2/M3 source fixes; use exact matching source builds for peers.

1. Approach a practice wall in the air with Jump released, moving along it.
   Compare a fresh Jump press with fresh Jump and Slide pressed together: when
   both reach the same input sample, Slide must not replace wallrun entry or
   spend a different aerial action. Holding Jump from a previous tick does not
   give a new Slide edge lower priority; Slide-only detachment is intentional.
2. Release Jump normally from wallrun and compare the legal kick on opposite
   faces and both tangents. The same-tick release plus fresh Jump impulse plus
   Slide corner case is exercised by automated commands; manual near-simultaneous
   presses alone do not prove they reached the same sample.
3. Away from walls, Slide alone must still fast-fall. Repeat with Oh Tipi and a
   flying character such as Grace Reava; flight and double jump remain different.
4. Retain M1/M2 checks: held jump preparation plants, instant taps retain momentum,
   Slide follows incoming travel, exhausted Sprint walks, and Water does not make
   Steam's scald stronger at the same exposure.

Source SHA-256:
`51512b1ea1f1f11760b4cd00c01ebe9034b5a5488f61a06cce904b57e1752b4e`;
3,109 production records. No export, installer, pointer promotion, commit, push
or publication is part of this checkpoint.
