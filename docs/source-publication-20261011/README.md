# H.E.X. source publication — October 11, 2026

Status: source cleanup and publication checkpoint for **p60-be3efd332e1a**. The game implementation and its October 10 performance qualification are unchanged.

This checkpoint brings the current game, its required assets, reproducible tests,
development tools and current documentation into the `generalgroovy/hex` Git
repository. Git history identifies the published commit. Windows portable
payloads remain local build outputs; this checkpoint does not create a GitHub
binary release.

## Preserved game and evidence

The runtime SHA-256 remains
`be3efd332e1a9cc584a4cdc4e983c2ce9e5de84ed5a179a0d1152f5ef8237e33`,
covering **3,390 canonical production records**. The current rules are six
ingredients, 63 compositions, eight delivery families, 504 spells, 30 playable
profiles, protocol 60 and snapshot schema 24. See the
[specification](../../SPECIFICATION.md) and [player guide](../PLAYER-GUIDE.md).

Required terrain chunks, character pages, import recipes, frozen test references,
original art and evidence receipts are retained. Git attributes preserve exact
runtime and evidence bytes across checkouts, including previously untracked
receipts whose hashes would otherwise change through newline conversion.

The [October 10 performance report](../performance-implementation-20261010.md)
owns the measured results: Full v5 passed 244 suites and 6,880,581 assertions,
with zero failures and zero stderr. Heavy spell workloads still exceed the
60 FPS frame budget on the measured laptop. Publishing the source does not
change those results or establish new gameplay, hardware or multiplayer
acceptance.

## Cleanup

The cleanup removed **83 obsolete or generated targets, containing 491 files
and 58,380,117 bytes**, from active project paths:

| Category | Targets | Files | Bytes |
| --- | ---: | ---: | ---: |
| Historical isolated test-profile folders | 78 | 486 | 54,548,991 |
| Duplicate fullbody art ZIP | 1 | 1 | 3,829,290 |
| Obsolete test-process PID file | 1 | 1 | 6 |
| Redundant agent-document redirects | 3 | 3 | 1,830 |

Each removed file has a hash-verified local recovery copy under
`.godot/git-publication-20261011/removed/`; the private manifest is outside Git.
This is active-tree cleanup, not a disk-space saving claim. The duplicate ZIP's
41 entries matched the retained `art_batches/character_cast_v1/output/fullbody-v2/`
files exactly. Live user profiles and existing portable builds were preserved.

Ignore rules now exclude generated test profiles, shader caches, PID files and
that duplicate ZIP without excluding surrounding useful evidence or source
import recipes. Nine superseded documentation bodies have exact archived copies
and SHA-256 receipts under [the documentation archive](../archive/source-publication-20261011/)
and [the agent archive](../../.agent/archive/source-publication-20261011/).

## Development and documentation repairs

- `hex.cmd` and `hex.ps1` select **PowerShell 7.2 or later**, propagate arguments
  and exit codes, and report missing or incompatible hosts clearly. Current
  scripts use APIs unavailable in Windows PowerShell 5.1.
- The policy-load diagnostic includes its exact frozen reference under
  `tests/support/references/`; it no longer depends on an unpublished `.godot`
  file. The September geometry comparison is explicitly marked historical.
- Source validation recognizes the terrain baker's exact authoring-provenance
  entry without exempting executable dependencies. The asset checker accepts
  empty evidence files as having zero references.
- Current design, character, spell, networking, development and handoff guides
  agree with the current source. Older originals remain archived as evidence.
- The README explains source prerequisites, launch commands and building a new
  portable. Local export paths are identified as local rather than downloadable
  GitHub artifacts.

Use the [development guide](../DEVELOPMENT.md) for the pinned Godot version,
source checks, test tiers and packaging commands. Agents independently reviewed
the documentation and launcher changes. A recognizable credential-format scan
of the publication candidates found no matches; it is not a universal secret
detection guarantee.

## Publication validation

Fresh-checkout validation is recorded here before the source is pushed. The
manual Windows foundation workflow provides the remote Full gate; its result
and tested commit are available in
[GitHub Actions](https://github.com/generalgroovy/hex/actions/workflows/ci.yml).
