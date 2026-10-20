# Continue development

## Starting point

The playable release is **45**, source `947019572508ad0e20bb1dbbfe19c0ebeeee7148`, at [H.E.X.](https://hex.onetruepath.chatgpt.site/tower). In this GitHub repository, work from `tactics/`; the root Godot project remains a separate game.

Read [the handbook index](README.md), then [Mechanics](MECHANICS.md), [Architecture](ARCHITECTURE.md), and the document for your area. Reproduce the setup in [Development](DEVELOPMENT.md). Inspect the actual current branch and Git status before editing. The imported web application includes older resolvers because existing saves and invitations depend on them.

## Non-negotiable design constraints

- Keep the original H.E.X. cast and world recognizable. New dialogue is light characterization, not invented canonical biography.
- Preserve simultaneous commitments, movement before casting, visible projectile travel and finite elemental interactions.
- Victory is actual enemy elimination. Springs supply Flux; they are not scoring objectives.
- Show consequences and uncertainty at the decision point. Never reveal sealed enemy orders through a preview or Guide.
- Match the native resolver in every range, cost, area, status and damage preview.
- Keep solo and 2–6-player Tower under one entry, with shared-door fights and synchronized floor advancement.
- Build variety comes from legal affinity allocation, four spells, a signature, team composition and terrain. Keep rewards readable; avoid an expanding inventory grid.
- Preserve seeded decisions, old saves, private seat ownership, original art inputs, useful failure evidence and fallback releases.

## Highest-value next work

These are open improvement hypotheses, not hidden completed features:

| Priority | Question | Useful experiment / evidence |
|---|---|---|
| 1 | Can unfamiliar players predict a simultaneous exchange? | Observe movement, area, interception and status decisions without coaching; compare predictions with results |
| 2 | Do charms and scrolls create choices across a full climb? | Multi-seed, multi-starter runs with authored equipment policies; compare reward pick rates, recovery pressure and encounter outcomes |
| 3 | Does six-player waiting stay enjoyable? | Real remote sessions, different doors, defeated squads, spectating, reconnect and delayed teammates |
| 4 | Are defensive fights still too long? | The one-seed diagnostic reaches 10–12 exchanges for three parties; inspect cause before lowering all enemy HP |
| 5 | Do busy effects remain readable on real phones? | Physical device frame/interaction measurements and visual inspection; a CSS viewport is insufficient |
| 6 | Does the sound mix communicate without fatigue? | Actual listening across quiet and crowded fights, volume/mute changes and reduced-motion/instant playback |
| 7 | Can documentation drift be detected early? | Keep reference rows derived from native catalogues and retain rule-vs-display regressions |

Avoid a feature expansion merely to make a release look larger. Prefer one measurable player problem, a source-grounded change and a clear acceptance test.

## Team ownership

The most productive release-45 split used three implementation lanes plus integration:

1. **Rules / progression:** native combat and Tower state, equipment, forecasts, authoritative co-op operations and service tests.
2. **Player decisions:** Guide, loadout configuration, accessibility, menu semantics and readable rules.
3. **Presentation:** sprite playback, elemental material accents, speech placement and sound lifecycle.
4. **Integrator:** shared contracts, actual browser checks, full regression/build, HTTP/D1 tests and release identity.

Assign disjoint files. Pair each lane with a different reviewer. Agree on shared contracts before parallel edits—especially spell metadata, order flags, costs, save fields and playback events. Freeze source before the final build; rerun affected checks after a late repair.

## Ready-to-use continuation brief

> Continue the H.E.X. web tactics game in `tactics/`. Read `docs/handbook/README.md` and the current release evidence, then inspect Git status and the executable rules for the requested change. Preserve the root Godot project, versioned saves, private seats, canonical identities and accepted art. Treat current native resolvers as authority; keep UI forecasts, Guide text and playback metadata aligned with them. Delegate independent work with explicit file ownership and cross-review. Implement a concrete player benefit, test the changed behavior and its compatibility boundaries, build and inspect the production game, and report exact evidence and remaining human acceptance work. A GitHub commit is not a website deployment. Do not publish a new site version unless the current user request authorizes it.

## Evidence boundaries

The [release record](../release45-evidence/verification.json) is a historical receipt for the published game, not a blanket approval of future edits. Raw art inputs and packers are included, but generating replacement artwork from the same prompt is not deterministic. Asset byte identity, software correctness, visual quality, balance and fun require different checks.
