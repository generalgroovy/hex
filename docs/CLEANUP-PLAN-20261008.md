# Project cleanup audit — 2026-10-08

Status: prepared, not applied. The user requested removal of old unused
project files. A guarded deletion of a byte-identical staging ZIP was rejected
by execution policy. No deletion workaround was attempted and no project file
has been removed by this cleanup task. The following inventory is a proposal,
not a receipt claiming reclaimed space.

This inventory predates the later [momentum/roster portable](MOMENTUM-ROSTER-CHECKPOINT.md)
`p57-6a4557e6cace` at `exports/hex-momentum-roster-20261008`. Protect that new
delivery too. Recompute retention and preview before any future authorized
cleanup; the selection below is historical, not safe to apply unchanged.

## Keep two complete functional deliveries

| Role | Keep intact |
|---|---|
| Current portrait build `p57-30b90507f932` | `exports/hex-portraits-20261008` and `exports/hex-setup-portraits-20261008` |
| Verified previous team build `p57-a41d15007f8c` | `exports/hex-teams-20261007` and `exports/hex-setup-teams-20261007` |

The actual older-to-newer update, rollback and forward test used these two
deliveries. Keep source, original artwork, imported current assets, saved data,
and curated passing/failing evidence. Do not reset the dirty checkout, prune Git
history or touch another project to recover space.

## Audited recoverable space

| Category | Proposed treatment | Recoverable bytes |
|---|---|---:|
| 32 superseded portable/setup bundles | Archive every non-binary record with relative paths and hashes; prune only fully preflighted generated bundle directories | 8,858,330,485 net after retaining 39,787,273 bytes of records |
| Installer-test binary copies | 33 `.exe` / `.pck` leaves at least 1 MiB, 3,531,311,628 bytes; preserve logs, receipts, sentinel files and small fixtures; never traverse the 14 junctions | 3,531,311,628, separate unapplied cleanup |
| Eight duplicate raw capture directories | Entire contents SHA-256-identical to preserved counterparts below; record mapping before removal | 198,124,898, separate unapplied cleanup |
| Old diff-warning log | `.godot/hex-git-diff-check.log`; generated September 20 whitespace warnings, no found documentation/tool references | 17,093,931, separate unapplied cleanup |
| Retained setup staging ZIP | `payload.zip` may be discarded only after byte equality with its retained final portable ZIP and setup receipt is verified; final setup itself stays | Not included in totals above |

The first two categories total approximately **11.54 GiB**. The whole-bundle
maintenance command deliberately does not delete installer-test copies,
reparse points, retained setup staging archives or engine captures.

## User-run whole-bundle cleanup

The existing `scripts/prune-local-builds.ps1` has been hardened for explicit
portable **and setup** retention, complete preflight before deletion, default
dry-run behavior, no reparse traversal, archival and result accounting. Do not
run an older copy of this script: its previous two-portable-only selection could
also target the retained setup folders. Use the final reviewed command supplied
with this task; first inspect its dry-run output, then explicitly apply.

**Executed preview passed:** 32 recognized candidates, 8,858,330,485 payload
bytes, 39,787,273 record bytes, four protected directories and zero unknown
directories. The script returned `mode: plan_only` without writing or deleting
files. PowerShell parsing, nine pure accounting checks and independent static
review passed. An initial preview caught a dictionary-property accounting error;
the corrected implementation uses explicit typed records and 64-bit totals.
No game/source rebuild was needed or performed for this maintenance-only change.

Close any game, installer, packaging or export activity first. In local
PowerShell, preview with:

```powershell
& 'C:\Users\sende\Projects\hex\scripts\prune-local-builds.ps1' `
  -KeepBuild @('hex-portraits-20261008','hex-teams-20261007') `
  -KeepSetup @('hex-setup-portraits-20261008','hex-setup-teams-20261007')
```

After reviewing the reported candidates, repeat that command with **`-Apply`**
to permanently delete the obsolete build binaries after archiving their records.
No `-Apply` execution was performed by this task. The destructive path has had
static review; that is not an executed deletion/recovery test. The checks reduce
concurrent-change risk but are not an exclusive filesystem lock.

After applying, its archive/receipt is the authority for what was actually
removed. Historical documents may still name retired output paths; the archived
records preserve build identity and test history, not executable binaries.
The current two playable choices are the retained deliveries above.

## Verified duplicate-capture mapping

All paths below are relative to `.godot/`. Equal file counts, relative filenames
and SHA-256 were verified during this audit. Preserve the right-hand copy.

| Redundant directory | Complete retained copy |
|---|---|
| `pixel-actions-completion-package-v1` | `pixel-actions-completion-all-v1` |
| `pixel-actions-allcast-pack-v1` | `pixel-actions-allcast-v1` |
| `fluid-motion-quality-foundation-v1-normal` | `fluid-motion-lively-20260929-v1-normal` |
| `fluid-motion-quality-foundation-v1-reduced` | `fluid-motion-lively-20260929-v1-reduced` |
| `pixel-cast-scale-pack-v1` | `pixel-cast-native-v2-20261002` |
| `pixel-cast-craft-pack-20261003` | `pixel-cast-native-v2-20261002` |
| `pixel-cast-allcast-pack-v1` | `pixel-cast-native-v2-20261002` |
| `pixel-cast-pack-20261002` | `pixel-cast-native-v2-20261002` |

## Not classified as disposable

- `.godot/imported` (368,492,135 bytes): current engine import cache; preserve
  immediate source runnability.
- `.godot/fullbody-game` (211,506,313 bytes): unique historical captures, not all
  mirrored by curated evidence.
- `.godot/windows-tests`: mixed logs, inventories and profiles, not safe as a
  wholesale target.
- Wrapper `output/imagegen/character-closeups-20261007`: original generated art.
- Legacy launchers, Linux toolchain metadata and asset-provenance tools: still
  referenced by scripts/docs; removing them requires a separate dependency migration.
- Most `.agent/candidates`: different historical/staged implementations. Three
  small unchanged tracked copies matched live code, but deleting them would
  recover only 59,384 bytes and is unnecessary for this bounded disk cleanup.
- `legacy/web-prototype/assets`: empty retired directory tree; negligible space,
  left untouched while deletion is blocked.

No claim that every old-looking file is unused. No code, character artwork,
gameplay mechanic, save or historical test failure was removed.
