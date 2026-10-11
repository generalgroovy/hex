# Lively-motion evidence, 2026-09-29

Candidate `p56-2073879eeeb7`, protocol 56/schema 22, 2,944 canonical runtime
records. Source manifest is copied here; runtime files are frozen for acceptance.

| Gate | Fresh result |
|---|---|
| Import / configured 120 Hz boot | Passed, zero stderr (`fast.json`) |
| Focused regression | Five suites / 305,566 assertions, zero failures/stderr (`focused.json`) |
| Native normal / reduced motion | 168 frames each, three representative body sizes, eight headings; source state unchanged |
| Native roster | Five boards, all 30 identities admitted; source state unchanged |
| Visual inspection | Twelve explicitly inspected frames copied under `native/`; no claim that every captured frame was individually inspected |
| Eight-actor dynamic CPU pose diagnostic | 7,680 pose queries, eight stream buffers; p50 6.418 ms / p95 9.846 ms / maximum 28.053 ms |
| Full regression | 172 suites / 1,565,395 assertions, zero failures/stderr; import, post-import identity and configured 120 Hz boot passed (`full.json`) |
| Advanced input journey | 7,721 checks; all three sizes pass flight/double-jump/dodge-fastfall/wall cases, zero stderr (`movement-journey.json`) |
| Windows export | Passed: exact source identity, 30-skin admission, native boot and safe close (`package.json`) |
| Build retention | Retained lively-motion + UX-clarity; verified payload/ZIP hashes and boot receipts before removing older visual export, 299,596,285 bytes (`build-retention.json`) |

The CPU diagnostic checks pose updates only, not simulation, GPU completion,
moving rendered cadence or network capacity. Its p95 already exceeds an entire
8.333 ms tick budget; `status=passed` in `pose-cpu.json` means the diagnostic
completed correctly, **not that the timing target passed**. No baseline timing
comparison was run for this slice. Existing dense timing failures remain open.

Native frames come from the actual production presenter on Windows/ANGLE, using
controlled pose fixtures rather than physical input. No rendering call may mutate
canonical state. The normal blocked-wall frames at samples 0 and 12 are identical
despite a changed cursor heading. Unit tests separately cover real distance gait,
resuming/reversing after blockage, prediction rebases and long-frame gaps.

`sprint-inspection.gif` and `moving_cast-inspection.gif` assemble the 24 native
source frames with the existing tool, a shared palette and a deliberately slowed
960 ms inspection cycle. They are animation previews, not gameplay timing proof.

Twelve inspected source images: normal sprint 00/06, moving_cast 12, landing 02,
wallrun 06, blocked_wall 00/12, hit 06; reduced landing 02 and moving_cast 12;
all-roster idle and slide boards. Additional raw captures remain in the ignored
`.godot/fluid-motion-lively-20260929-v1-{normal,reduced}` and
`.godot/fullbody-capture-lively-20260929-v1` folders; the reusable review runner is
`scripts/review-lively-motion.ps1`.

An initial identity-generation command correctly refused overwriting the prior
manifest without `-Force`; no engine ran or result was accepted from that attempt.
An explicit pre-Full regeneration then passed import and identity checks.

Human feel/readability, physical keyboard/controller and remote multiplayer remain
open. No installer, public release, commit, push or historical pointer promotion.

The input journey uses production Bootstrap routing and unified simulation with
isolated profiles and arranged scene fixtures; it is not physical-keyboard or
controller-hardware acceptance. Full validation ran against the same unchanged
production identity as the native boards and CPU diagnostic.
