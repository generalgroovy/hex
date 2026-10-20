# H.E.X. expert review evidence — 20 October 2026

This directory supports the [integrated implementation plan](../../EXPERT-REVIEW-AND-IMPLEMENTATION-PLAN.md). The audited runtime source is commit `592855cbd88c070683d0c1fdc1fa0eaf235a0514`. Only documentation and diagnostic evidence were added during this review. No runtime changes, new production build or deployment were made.

## Independent reviews

| Review | Scope |
| --- | --- |
| [Systems](expert-audit-systems-2026-10-20.md) | Phase timing, spells, statuses, chemistry, collision geometry, AI, balance and canonical cast comparison. |
| [Experience](expert-audit-experience-2026-10-20.md) | Map topology, route choices, progression, teaching, scouting, joined/split cooperation, encounters and session reliability. |
| [Presentation](expert-audit-presentation-2026-10-20.md) | GUI, input, responsiveness, art consistency, animation, effects, audio, accessibility and performance risks. |

The coordinator integrated these findings, performed browser inspection and primary-source research, then asked the specialists to challenge the integrated plan. Priority labels in the independent notes are local to those notes; the integrated plan sets the implementation order. Recommendations are proposals unless the accompanying evidence explicitly identifies a reproduced behavior.

## Native diagnostics

| Script and raw result | What it establishes | What it does not establish |
| --- | --- | --- |
| [Spell/status probe](expert-audit-systems-probes-2026-10-20.mjs), [JSON](expert-audit-systems-probes-2026-10-20.json) | Native Tower Sunburst behavior on controlled substrates; effective centre/rim channels for selected spells. | Population balance, best repair numbers or human enjoyment. |
| [Arena contact probe](expert-audit-arena-contact-2026-10-20.mjs), [JSON](expert-audit-arena-contact-2026-10-20.json) | A legal current Arena volley with no reported clash, compared with the current volume-contact solver's Steam contact. | Every geometry case or renderer timing; those need regression coverage. |
| [Canonical cast comparison](expert-audit-canonical-cast-2026-10-20.mjs), [JSON](expert-audit-canonical-cast-2026-10-20.json) | All 30 hosted IDs, names, ancestries, body roles and elemental memberships match the bootstrap-selected original catalogue. It records the point-budget adaptation. | That every original action-game mechanic belongs in the tactics game. |
| [Pacing probe](expert-audit-systems-pacing-2026-10-20.mjs), [JSON](expert-audit-systems-pacing-2026-10-20.json) | Two reproducible native AI mirror fights on `FOCUS42-B`, including the long tail after the first defeat. | Frequency, all-starter balance, human pacing or a target win rate. |

These are diagnostics, not assertions that the observed behavior is desirable. They import the real game modules. The preserved JSON files came from the original executions. Repository copies of the scripts change only import/output handling and allow the canonical source path to be configured.

From the repository root, using Node 24.18.0 as used for this review:

```powershell
node --experimental-strip-types docs/expert-review/2026-10-20/expert-audit-arena-contact-2026-10-20.mjs
node --experimental-strip-types docs/expert-review/2026-10-20/expert-audit-systems-probes-2026-10-20.mjs
node --experimental-strip-types docs/expert-review/2026-10-20/expert-audit-canonical-cast-2026-10-20.mjs
node --experimental-strip-types docs/expert-review/2026-10-20/expert-audit-systems-pacing-2026-10-20.mjs
```

The repository copies print diagnostic summaries without overwriting the preserved JSON. Set `HEX_AUDIT_OUTPUT` to an explicit output filename if a fresh full result is needed. For a different checkout of the original game, set `HEX_CANONICAL_CAST` to its `content/champions/foundation_champions_v1.json`. Compare only equivalent source revisions. The pacing probe may take substantially longer than the other fixtures.

The shared/split encounter probe is tabulated with its seed, inputs and limitations in the experience review. It enumerates encounters and distinct teachers; it does not simulate victories.

## Browser observations

The coordinator inspected an existing local `FOCUS42-PLAY` save without submitting a new turn. Screenshots show an observed dense encounter, not a representative first-session sample. Browser device emulation is not physical-phone performance evidence.

| Screenshot | Measured CSS viewport | Observation |
| --- | --- | --- |
| [Desktop](expert-audit-desktop.png) | 1440 × 900 | Horizontal fit; detailed champions/trees alongside simpler creatures; spacious side rails. |
| [Phone](expert-audit-phone.png) | 390 × 844 | Horizontal fit; core commands present; small text and touch targets require usability review. |
| [Compact landscape](expert-audit-compact-landscape.png) | 790 × 444 | Spell content exceeds fixed button height and overlaps neighboring rows. |

The emulated browser reported device-pixel ratio 1.62. Physical screenshot dimensions therefore differ from CSS layout dimensions. Fresh UI observations were taken after viewport changes settled.

For example, Water Jet's measured button occupied CSS y=310.04–354.03, while its effect text extended to y=359.80. Cleansing Tide's button occupied y=359.03–403.02, while its effect text extended to y=415.11. These measurements corroborate the landscape screenshot.

The observed previous-round report showed blocked movement, a resulting Water Jet fizzle without resource expenditure, several simultaneous casts, many named terrain fields and net damage/status changes. The proposed consequence record addresses the gap between seeing those outcomes and explaining their causes.

No listening session, independent novice study, physical-device performance test or new broad regression run was conducted in this analysis. Proposed acceptance targets in the plan must not be reported as achieved.
