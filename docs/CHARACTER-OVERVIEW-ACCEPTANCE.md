# Character overview: alphabetical race rows

Status: initial source-model slice, 2026-09-06. This does not promote any
additional character or certify unfinished character artwork.

## Current contract

| Area | Implemented model behavior |
|---|---|
| Source | Validated `ChampionCatalog` and `ChampionRosterPlan`; no per-frame file loading |
| Rows | All declared races, alphabetical; characters alphabetical inside each race; an empty race row remains honestly empty |
| Coverage | All 24 canonical identities exactly once: five playable, eighteen planned, one placeholder |
| Playable details | Actual Health/Flux/Stamina maxima and recovery rates, movement-speed ratio, body profile, affinities/points, starting kit, playstyle and wire ID |
| Planned details | Canonical name/race/body/affinities and explicit planned status; no invented stats, kit, wire or accepted body profile |
| Race rules | Race is ancestry, not an implemented automatic bonus; actual statistics remain champion-specific |
| Safety | Immutable deep projection; invalid/mismatched catalogs fail closed with a reason and no partial rows; no gameplay authority writes |

## Integration API

`CharacterOverviewModel.build(champions, roster)` returns `valid`, `error`,
`rows`, `entries_by_id`, counts, source hashes and a race-rule note. Build once
after both catalogs validate, and rebuild after a deliberate content reload.
Never build every rendered frame or read this model to authorize character
selection. Pass the chosen stable ID to the existing authoritative selector.

Each row has `race_id`, `race`, `champions`, per-status counts and
`race_rules_note`. Each champion includes `id`, `display_name`, `availability`,
`selectable`, `stats_available`, `race_id`, `race`, `body_type`, `affinities`,
`affinity_points`, `affinity_status`, `stats`, `stat_lines`, `foundation_kit`,
`body_profile`, `playstyle`, `wire_id` and `note`. Reserved future elements are
separate metadata; they never become selectable affinities.

Raw stats retain simulation thousandths. The four compact `stat_lines` convert
resources into points, recovery into points/s and movement ratio into percentage
of base walk speed. Recovery is a configured rate, not a claim that recovery
is uninterrupted during damage, casting or movement actions.

## Acceptance and next slice

The focused `character-overview-model` suite checks complete unique coverage,
alphabetical order, all five real catalog profiles, honest planned status,
compatibility display names, immutable deep copies and malformed-input rejection.
The integration lead owns test registration and the in-game renderer.

Executed on 2026-09-06 using Godot 4.7.1 and an isolated direct suite runner:
**388 assertions, zero failures**; log `.godot/characters-audit/overview.log`.
This is model evidence, not an interactive acceptance or a Full gate claim.

Next: expose compact race rows in the champion overview with hover/focus details
and existing selection for playable entries; keep planned cards visibly locked.
Then promote one remaining champion at a time, smallest body first, only after
original body-only eight-direction movement/cast art, valid stats, selector,
combat and host/join acceptance. An overview row is not a completed character.
