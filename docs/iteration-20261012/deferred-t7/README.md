# Deferred T7: all-completed-step attribution

**UNAPPLIED.** The user requested a pause at the next stable game state. These
reviewed patches are preserved for an explicitly resumed iteration; they are not
part of runtime `p60-1e084a50a029` or its qualification.

The [review manifest](review-manifest.json) pins all three exact patches and the
unchanged canonical base files. Technical, gameplay and experience agents
cross-reviewed them. Isolated PowerShell validation passed 239 assertions.
Godot parsing, actual simulation execution, native lifecycle and observer-cost
checks have not run. No performance improvement is claimed.

On resumption, verify the manifest's base and patch hashes before applying all
three patches together. The proposed test registers `completed-step-profile`;
the profiler adds explicit `-AllFixedSteps`, incompatible with the light observer.
Default gameplay is intended to keep cumulative collection disabled. Preserve
the stable portable while testing the resulting source as a separate candidate.
Patch applicability was checked with `git apply --check --ignore-space-change`
because context lines can differ between CRLF and LF. Require the recorded base
hashes first; whitespace tolerance is not permission to apply against newer code.

The diagnostic counts all successful fixed steps within each process interval,
including earlier catch-up steps hidden by the current final-step sample. It
rejects failed steps, world/epoch discontinuities, impossible stage counts and
inconsistent clocks. Stage sums exclude counter commits, snapshot copying and
other work outside those intervals; they are not total frame or GPU time.

Original before/proposed trees and local pure-PowerShell logs remain under
`.godot/iteration-20261012/T7-draft`. They are excluded from Git. The tracked
archive contains only the minimal patches and review record needed to resume.
