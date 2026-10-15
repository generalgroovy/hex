# H.E.X. resume handoff

Status updated **October 16, 2026**: **ACTIVE PRODUCT IMPLEMENTATION; stop before 20,000 credits remain.**
The user resumed development after the completed Git handoff, authorizing deep
analysis and implementation toward a compelling indie game. Active local branch:
`codex/hex-breakthrough-20261015`, based on published `aec900a`. The previous
presentation branch remains the stable [Linux handoff](LINUX-HANDOFF.md).
Read the [product assessment](../docs/BREAKTHROUGH-ASSESSMENT-20261015.md) for the
new priorities. Circuit/navigation/measurement-tool changes are candidate work;
their current validation belongs in the single queue. The qualified portable
selection is unchanged. Candidate **p61-6618873387e2** (3,450 runtime records)
passed [clean Windows CI Full 38817305452](https://github.com/generalgroovy/hex/actions/runs/38817305452)
at pushed commit **932f5974fe17a8d2432d8f82873eb86faf564543**: **267 suites /
7,576,123 assertions / zero failures**, three empty stderr files and correct
**120 Hz / protocol 61** boot. The [independent CI review](../docs/breakthrough-evidence-20261015/ci-full-38817305452/independent-review.json)
completes source Full validation. The candidate is **not packaged or promoted**;
qualified desktop d6d1 remains selected.
The historical local [Full-a](../docs/breakthrough-evidence-20261015/full-a/tests.json)
failed after 112 of 267 suites, 5,280,932 assertions and nine failures, then
reached its 2,700-second timeout; 155 suites did not complete and boot did not run.
Three reviewed test-only follow-ups were applied. Seven-suite `focused-review-a`
passed **65,133 assertions / zero failures and stderr**, in **264,217 ms**,
including tools **58,514 / 0** and Circuit integration **314 / 0** with InputMap
cleanup. Local outage A/B passed **6,478 / 0** and **6,465 / 0**, each with
241 trace rows. Neither those reruns nor clean CI establish the historical
capture failure's cause. [Candidate evidence](../docs/breakthrough-evidence-20261015/README.md)
keeps failed, focused, full-source and prepared-layout scopes separate.
The [single queue](OVERHAUL-IMPLEMENTATION.md) owns all current work and assigns
an implementer and independent reviewer to every point. The completed design request
was analysis and complete overhaul design. The user selected illustrated 2.5D with
smooth animated sprites. Gameplay, Experience and Technical wrote separate drafts,
reviewed each other and the [consolidated proposal](../docs/OVERHAUL-DESIGN-20261015.md).
It covers all design/implementation areas with owner/reviewer assignments and
staged gates. The October 15 planning pass changed documentation only; the later
Git handoff publishes that plan together with the existing implementation and
evidence. It does not change runtime behavior, launcher selection, packages or saves. Earlier approved
implementation work and its pending measurements remain in the single queue.

## Source and playable delivery

Repository: `C:/Users/sende/Projects/hex`; branch:
`codex/hex-breakthrough-20261015`. `Documents/ChatGPT/H.E.X` is a wrapper.
Published candidate checkpoint: **932f597**; historical handoff base: **aec900a**.
`main` remains `95ca630`. Publication does not qualify the candidate delivery.
Qualified baseline source: **p61-d6d1bfb9c529**, SHA
`d6d1bfb9c5292d8dffbeade6e1cf460cd3a23ee54a655da7069d75e4cb572d44`.
The stationary velocity change and regression are integrated and peer-reviewed.
Full passed through the desktop Diagnostic runner with 1,693 frozen inputs:
265 suites / 7,574,524 assertions, zero failures/error output and a 120 Hz boot.
Qualified local portable: **p61-d6d1bfb9c529**, protocol 61,
snapshot 24, 120 Hz simulation / 60 Hz transport and 3,446 production records.
Package, all 18 portable checks, 2,064 checks over 133 exported terrain images,
and five actual desktop-wrapper normal-close/reopen cases passed. Fire and Mantle
each completed exactly 12 paid starts and releases, with zero refusals.
The [independent delivery review](../docs/performance-evidence-20261014/stationary-qualification-d6d1/delivery-review/review.json)
passed **4,076 checks**; [qualification archive](../docs/performance-evidence-20261014/stationary-qualification-d6d1/README.md).
Current-build foreground performance and portable FPS remain unmeasured.

The immediate qualified fallback is **p61-64590c45c7a5**. Its
[Full](../docs/depth-clarity-evidence-20261014/full.json) passed 265 suites /
7,574,438 assertions, and its [4,076-check delivery review](../docs/depth-clarity-evidence-20261014/delivery-review/review.json)
retains the exact depth/clarity package qualification. Native parity was 260 checks /
six captures, with five terrain-focused suites / 3,894 assertions.
The older **p61-7804a23eb300** [Full](../docs/iteration-20261013/full-7804/README.md)
passed 265 suites / 7,573,807 assertions; its [delivery review](../docs/iteration-20261013/delivery-review-7804/review.json)
remains preserved. Keep 500be and other working builds, original assets and user data intact.

Launch player sessions through **the desktop H.E.X. shortcut**, resolving to
`C:/Users/sende/Documents/ChatGPT/H.E.X/PLAY-HEX.cmd`. That stable wrapper selects
[the qualified portable](../exports/hex-performance-20261014-d6d1/windows/PLAY-HEX.cmd).
The shortcut's stale FLUX-checkout target was corrected and read back in this batch.
Use this same front door for future player/performance sessions; source unit
validation remains serialized through the repository test tools. A candidate must
be independently qualified before changing the normal playable selection.

ZIP: `exports/hex-performance-20261014-d6d1/HEX-p61-d6d1bfb9c529-Windows-x64.zip`,
161,194,910 bytes, SHA
`0741a134bc163be16e0390b3364c7602445f20556a4ea552ac01462cd5511382`.
PCK SHA: `5b6e84fe2af3dd1730972f755fd3012b1bc2fd6ee150ea36ead35c8021a1a819`.
The 6459 fallback, 7804, 500be and older working builds remain preserved. Local binary
exports are excluded from Git; this is not a published installer release.

## Acceptance boundaries

Current d6d1 foreground performance and portable FPS are unmeasured. The current
source Light attempt expired before manual Start: armed=false, empty results,
no gameplay measurement. Other Codex tasks were running, but this does not
establish why Start was missed. Matched Full/Light and packaged pacing remain
open; no automatic restart or new availability request is planned.
Previous-build source recording: **6459 Profile B**, full observer, 1280×720,
low detail and synthetic paid commands. Garden/sustained Fire/Mantle engine
interval mean / p95: **62.105 / 73.910, 92.595 / 117.084, 87.840 / 110.507 ms**.
All 638 recorded process samples were focused; source hashes stayed unchanged.
This is not portable FPS or physical-input proof. Low observed host memory,
uncalibrated observer cost and unmatched historical conditions prevent a causal
comparison to 500be. [Attempt A](../docs/performance-evidence-20261014/foreground-setup-a/review.json)
expired before Start, instantiated no game and remains unmeasured.
GPU/present/input latency, human feel, listening, balance and real two-PC
acceptance retain their own gates. The [occupied-membership experiment](../docs/performance-evidence-20261014/occupied-membership/README.md)
passed correctness but missed all eight primary performance gates and was
withdrawn without application. The [ground-speed experiment](../docs/performance-evidence-20261014/movement-ground-speed/README.md)
also passed correctness but failed its opposite-order benefit gate and remains
unapplied. [Garden attribution](../docs/performance-evidence-20261014/garden-attribution/README.md)
confirmed warm geometry reuse; its sparse lifecycle captures do not isolate
live phase-refresh costs. The [Low marker-budget experiment](../docs/performance-evidence-20261014/garden-sample-budget/README.md)
passed continuous-cycle image/state controls but failed both normal-effect cost
gates and increased ordinary draw cost; it is withdrawn without reduced-mode
expansion. [Casting-stage attribution](../docs/performance-evidence-20261014/casting-stage-attribution/README.md)
passed four native processes and identified movement as the largest measured
child in ordinary five-actor Fire/Mantle steps. The [stationary fast-path candidate](../docs/performance-evidence-20261014/stationary-ground/README.md)
passed all eight paid-case performance gates across four native processes, with
exact state/event parity. It is integrated and qualified in d6d1: it skips only
stationary target/acceleration arithmetic and preserves recovery and surrounding
movement processing. One-off tail regressions remain recorded; this is not an
FPS result. The separate Low-detail Conflagration decoration trial is withdrawn:
three of four primary cost gates failed, and single-field cost regressed by
5.94% / 7.04% in the opposite-order runs. Captured threat readability passed;
that does not rescue the cost failures. The stationary change alone was retained and qualified;
no renderer optimization from the withdrawn trials was applied.

Root alone serializes engines/imports/captures/exports. Preserve user data,
original assets, qualified builds and useful failed evidence. Delete only
classified unused/redundant files; keep references valid. Historical receipts are
immutable and qualify their recorded bytes. Previous detail is in the
[closed checkpoint ledger](../docs/iteration-20261013/README.md) and Git 38f1bc3.
`docs/current-delivery.json` owns the H.E.X. playable route. The separate
`docs/current-checkpoint.json` remains a legacy FLUX tooling contract, not the
active H.E.X. delivery pointer. The user authorized continued work with a cutoff of **20,000 credits remaining** (57,349 recorded at resume). This supersedes the former 1% usage cutoff and no-paid-credit restriction. Check the balance at phase boundaries and reserve enough to leave a coherent checkpoint before reaching the cutoff.
