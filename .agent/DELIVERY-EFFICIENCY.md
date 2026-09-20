# FLUX delivery efficiency

Status: supporting execution guide, amended 2026-09-12; not a separate implementation plan.

The [current queue](OVERHAUL-IMPLEMENTATION.md) owns order and acceptance.
[Implementation rules](OPTIMIZATION-IMPLEMENTATION.md) own working practice.
Historical C/F gate sequences and old performance counts do not schedule work.

| Stage | Exact purpose | Entry point |
| --- | --- | --- |
| Inspect | Verify checkout, dirty changes, current scope and content | scripts/current-state.ps1 -Check |
| Focused | Run explicitly named impacted suites | scripts/test.cmd -Tier Focused -Suite <id> |
| Structural | Import, environment and bounded startup | scripts/test.cmd -Tier Fast |
| Checkpoint | Every registered suite, clean import and 120 Hz startup | scripts/test.cmd -Tier Full -ReceiptPath <path> |
| Visual | Actual renderer, native scale, phase/direction and reduced effects | Bounded tests/visual fixtures |
| Network | Same-build real processes if wire/session behavior changed | scripts/smoke-farflow.ps1 |
| Delivery | Frozen-source Windows portable, exact PCK/export/boot evidence | scripts/checkpoint-portable.ps1; installer journey remains separately gated |
| Play | Existing source front door | flux.cmd play |

A source test is not an installer test. Preserve the previous verified installer;
build into a new directory and record exact hashes, source identity and omissions.
Do not publish, alter firewall rules, or change trust policy implicitly.

## Checkpoint cleanup

At each checkpoint consolidate the active queue, source/delivery status and next
slice. Remove only agent-owned disposable probes after preserving useful results;
do not erase original assets, dirty user changes, working builds or failed-test
evidence. Avoid copying the same plan into several competing documents. Keep
transient captures in `.godot`, immutable acceptance evidence in `docs/evidence`,
and release payloads in a newly named `exports` folder. Do not promote a build
before verification. Close owned test processes and restore test environment
variables. Keep memory/handoff notes short, pointing to current repo authority
instead of repeating stale implementation detail.

## Small slices and useful parallel work

One coherent source slice has an observable outcome, named owners, unchanged
invariants, a focused reproduction, evidence paths and the next smallest step.
Parallelize independent art, presentation or tests only with exclusive file
ownership. Freeze shared files before the final Full run.

All engine workflows share the checkout execution guard in engine-guard.ps1.
Contention fails before outputs are touched; synchronous nested wrappers retain
the outer lease. A surviving child from an interrupted owner blocks admission
until it exits. Never delete the journal to bypass a live or uncertain owner.
Use the physical checkout path; junction/symlink ancestry is rejected.
The guard is a backstop: the integration owner still schedules every engine job.

Tests retain a GUID run directory containing logs, stderr, source/asset reports
and receipt. A requested receipt or latest receipt is an additional pointer/copy;
retain the referenced run directory with it. Portable delivery validates and
archives those exact reports, even after another test updates the shared reports.
Default smoke, package and runtime-state logs also use distinct run directories;
explicit evidence/output paths remain caller-owned and must be fresh.

Remove obsolete producers before their outputs, with hash-verified recovery
copies outside the checkout. Preserve live import/provenance inputs and tested
compatibility migrations. Do not optimize for line count or add a speculative
framework; simplify a proven dependency and measure actual cost.

Reuse deterministic scenarios and production presenters. Counts come from live
catalogs, never copied historical tables. Keep authored, derived, rejected,
partial and promoted art distinct. A useful handoff contains the current queue,
source identity, active diff boundary, last receipt, exact next action and any
user-owned files that must remain untouched.
