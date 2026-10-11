# M1 movement and field-boundary evidence

Status: 2026-10-07 source candidate p57-0a679f632a77; focused v2 and Full v1 PASS. No package, installer, selected checkpoint, publication or human acceptance claim.

## Scope

| Change | Contract / proof scope |
|---|---|
| Held jumpsquat | Stops self-motion and clears resumable impulse stores, including held Slide preparation; complete same-command taps retain momentum; forced control and later external displacement remain effective |
| Slide entry | Captures incoming velocity heading before unchanged steering/friction; paid budget, cooldown, commitment and intentional brake retained |
| Field boundaries | Counts compatible boundary segments once per distinct occupied hex, preserving exterior and safe-hole edges despite duplicate records; no simulation membership/lifetime change |
| Delegation | 42 role cards, 20 new and 22 reused; three actual first-batch workers; other roles queued, not completed |

## Fresh evidence

| Gate | Result |
|---|---|
| Role definitions and dispatch coverage | PASS: 42 unique matching names/frontmatter, shared ownership reference and manifest entries; independent read-only review, one reviewer-contract contradiction repaired |
| Focused v1 | FAILED: two new tests used unsupported Vector2i.dot; the fourteen instantiated suites passed but the aggregate failed. Failure retained in focused-v1.json and focused-v1-suite.log.err |
| Focused v2 | PASS: all 16 requested suites / 366,039 assertions, zero failures / stderr; focused-v2.json |
| Full, import, identity and configured 120 Hz boot | PASS: 220 suites / 3,917,456 assertions, zero failures / stderr; full-v1.json, exact-hash log copies and source identity retained |
| Native boundary / movement feel review | NOT_RUN for this candidate; inspect normal/reduced overlap around a safe hole and actual held/tap movement |
| Export / installer / same-export networking / physical Internet | NOT_RUN for this candidate; prior packages are preserved unchanged |
| Dense sustained 120 Hz | Historical FAILED gate remains; correctness tests do not establish timing |

Source identity: 3,109 production records; SHA-256
`0a679f632a779868dc4ff82fa1e0d4e144919236787513d4d03b1f22ae9afb56`.
Protocol 57 / SessionSnapshot 23 / SessionRound 2 unchanged. Use matching builds.

The focused command selected movement-checkpoint1, movement-overhaul,
client-prediction, movement-response, movement-guide-model, movement-revision,
movement-height, movement-checkpoint1-integration, compact-combat-hud,
frostway-movement, hex-shared-presenter, hex-court-presenter, hex-render-frame,
hex-strength, hex-whole-coverage and hex-authored-shapes.

## Human acceptance route (pending)

1. Run, hold Jump with neutral/forward/opposed input: remain planted; releasing
   launches. Repeat from Slide; no stored impulse should suddenly return.
2. Compare an instant tap/impulse Jump with held preparation: only the instant
   tap carries earned ground momentum. Keyboard press/release timing determines
   whether a held preparation tick occurred; wheel impulses cannot charge.
3. Enter Slide while aiming elsewhere and with neutral movement: follow current
   travel. Steer sideways/opposite and observe the existing gradual carve/brake.
4. Form compatible overlapping fields around a clear hex: exterior and safe-hole
   boundaries stay visible as one source disappears. Compare normal/reduced effects.

Recorded assertions protect behavior, not subjective fun/readability. Continue
through the [single queue](../../.agent/OVERHAUL-IMPLEMENTATION.md); specialist
ownership is in [the dispatch manifest](../../.agent/ASPECT-DELEGATION.md).

To try this changed source with the installed development runtime, use
[scripts/run.cmd](../../scripts/run.cmd). Existing exported launchers still run
their previous frozen package bytes, not these M1 fixes.
