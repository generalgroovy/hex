# Local build retention

User instruction, 2026-09-28: keep only the latest two functional local builds.
Older generated export directories are permanently deleted after verifying the
retained packages. Small identity, package, checksum and boot receipts remain
here; source assets, code, tests and historical diagnostic evidence are not deleted.

Historical documentation may name a build removed by this policy; such paths
are historical evidence, not available launchers. The current README names the
retained playable build and fallback. No release/installer pointer is promoted.

## Current cleanup request — October 8

**Audit/preparation only; removal is policy-blocked.** Preserve portable **and
setup** directories for `hex-portraits-20261008` / `hex-setup-portraits-20261008`
and `hex-teams-20261007` / `hex-setup-teams-20261007`. Older records below describe
their historical selections, not today's retained pair.

The [cleanup plan](../CLEANUP-PLAN-20261008.md) distinguishes old build binaries,
installer-test duplicates and byte-identical captures from source/artwork and
useful evidence. Use the updated maintenance script with explicit `KeepBuild`
and `KeepSetup` names; default operation previews only. Applying must be explicit
and should be done only after reviewing the complete plan. Never infer disposable
content from timestamp or an old-looking name. Failed candidates do not replace
either functional fallback.

## Historical retention receipts

Current October3 scale/performance checkpoint: `hex-scale-perf-20261003` and
`hex-cast-motion-20261003` are the freshly verified current/fallback pair. Native
launch/safe close and150 exact PCK image comparisons pass; both PCK/ZIP hashes
are verified. Seven export folders remain because the earlier cleanup block
is unresolved. No deletion or workaround was attempted.
[Current package evidence](../scale-performance-evidence-20261003/package-comparison.json).

Previous October3 all-cast extension: `hex-cast-motion-20261003` and
`hex-craft-20261003` are the freshly verified current/fallback pair. Native
launch/safe close and150 exact packaged-board comparisons passed; both PCK/ZIP
hashes were verified. Six export folders remain because the previous older-build
cleanup block remains unresolved. No deletion or workaround was attempted.
[All-cast package evidence](../cast-motion-evidence-20261003/package-comparison.json).

Earlier October 3 extension: `hex-craft-20261003` and `hex-pixel-cast-20261002` were
the selected playable pair. New native launch/safe close, exact PCK action/ground
boards and both selected builds' PCK/ZIP hashes passed. Five export folders remain
because the earlier cleanup block is unresolved. No deletion or workaround was
attempted in this turn; two-build retention is still pending. Current evidence:
[craft package comparison](../craft-evidence-20261003/package-comparison.json).

Historical October2 extension: then-current `hex-pixel-cast-20261002` and previous
`hex-pixel-pilot-20261001` are the selected playable pair. The current package
passed native launch/safe-close and all30 source/PCK board hashes. Both selected
PCK/ZIP files were freshly verified against their package receipts. Four export
folders now remain: older headroom and simplification copies are still present
after the earlier cleanup block below. No deletion or workaround was attempted
in this continuation; two-build retention remains pending, not falsely complete.

Latest attempt, 2026-10-01: pilot `hex-pixel-pilot-20261001` and fallback
`hex-headroom-20260930` passed fresh payload/ZIP and boot-receipt checks. The dry
run selected only `hex-simplification-20260930`; execution was blocked by the
environment before it ran. **No files removed; three exports currently remain.**
The extra simplification copy is pending cleanup, not a third selected checkpoint.
Do not claim the two-build policy has been completed for this slice.

Previous cleanup, 2026-09-30: removed `hex-boundary-reuse-20260930` /299,635,049
bytes. Retained `hex-headroom-20260930` and `hex-simplification-20260930`
after both payload/ZIP hashes and native boot/safe-close evidence were checked.
Small receipts are in `hex-boundary-reuse-20260930/`; source/original assets remain.
Deleted binaries cannot be launched or restored from these receipts.

Preceding cleanup, 2026-09-30: removed `hex-practice-masonry-20260929` /299,631,411
bytes. Retained `hex-simplification-20260930` and `hex-boundary-reuse-20260930`
after both payload/ZIP hashes and native boot/safe-close evidence were checked.
Small receipts are in `hex-practice-masonry-20260929/`; source/original assets
remain. Deleted binaries cannot be launched or restored from these receipts.

Preceding cleanup, 2026-09-30: removed `hex-quality-foundation-20260929` /299,625,584
bytes. Retained `hex-boundary-reuse-20260930` and `hex-practice-masonry-20260929`
after both payload/ZIP hashes and native boot/safe-close evidence were checked.
Small receipts are in `hex-quality-foundation-20260929/`; source/original assets
remain. Deleted binaries cannot be launched or restored from these receipts.

Preceding cleanup, 2026-09-29: removed `hex-lively-motion-20260929` /299,618,002
bytes. Retained `hex-practice-masonry-20260929` and `hex-quality-foundation-20260929`
after both payload/ZIP hashes and native boot/safe-close evidence were checked.
Small receipts are in `hex-lively-motion-20260929/`; the removed binaries cannot
be launched or restored from these receipts. Source/original assets remain.

Preceding cleanup, 2026-09-29: removed `hex-ux-clarity-20260929` / 299,613,249
bytes. Retained `hex-quality-foundation-20260929` and `hex-lively-motion-20260929`
after both payload/ZIP hashes and native boot/safe-close evidence were checked.
See the [current receipt](../quality-foundation-evidence-20260929/build-retention.json).

Preceding cleanup: removed `hex-visual-hierarchy-20260929` / 299,596,285
bytes. Retained `hex-lively-motion-20260929` and `hex-ux-clarity-20260929` after
payload/ZIP hashes and native boot/safe-close evidence were checked.
See the [earlier receipt](../lively-motion-evidence-20260929/build-retention.json).

Preceding cleanup: removed `hex-performance-eight-20260928` / 299,595,381
bytes. Retained `hex-ux-clarity-20260929` and `hex-visual-hierarchy-20260929`
after payload/ZIP hashes and native boot/safe-close evidence were checked.
See the [earlier receipt](../ux-decision-evidence-20260929/build-retention.json).
The preceding cleanup removed `hex-combat-clarity-20260928` / 299,578,614 bytes.

Earlier cleanup removed 26 obsolete directories / 7,369,159,608 bytes;
[historical receipt](../performance-eight-evidence-20260928/build-retention.json).
