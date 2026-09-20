# Input and Gallery lifecycle refinement

Status: verified local source refinement, 2026-09-08; not a new installer.

This is a bounded reliability follow-up to the cleanup/art checkpoint. Existing
working-tree changes are preserved. No movement values, resource costs, spell
definitions, art, protocol, saves or host authority are changed by this slice.

| Defect | Required behavior |
| --- | --- |
| Wheel jump survives focus loss | Clear queued wheel input on focus loss; no delayed paid movement on return |
| Action held inside a modal becomes a new gameplay edge | Require release and a fresh press after interruption for paid movement, primary/active spells and all spell layers |
| Unfocused game still samples local controls | Send neutral commands; authoritative time and shared session continue |
| Invalid Gallery reload retains state | Close old panel; drop pending wire/equipped labels, navigation, details and borrowed portraits; recover only through valid configuration and deliberate reopening |

Directional movement may resume after the interruption. Existing committed
actions and projectiles remain governed by simulation; this is not a pause,
invulnerability feature or cancellation of authoritative outcomes. Short taps,
wheel gestures and movement/spell chaining outside interruptions retain their
existing rules. No speculative controller-disconnect workaround was introduced.

## Evidence

Gallery regression first reproduced 11 failures; the corrected model/grid pass
448/859 assertions. Input/modal/focus regressions first reproduced 31 failures;
the final five-suite input gate passes 14,049 assertions with empty stderr.

Final aggregate Full: **87 suites / 398,436 assertions, zero failures/stderr**;
strict import and actual protocol 47 / 120 Hz startup passed in 86.036 seconds.
Receipt and red/green logs: `docs/evidence/input-lifecycle-v1`.
The previous cleanup/art Full receipt remains evidence for that earlier slice.
No commit, push, publication, new package or installer was produced here.

## Playtest

Run `flux.cmd play` from this checkout. In the Wellspring:

| Check | Expected result |
| --- | --- |
| Open F4, hold Jump or a spell number, then close | No new action until you release and press again |
| Hold primary fire while closing a panel | No UI click/hold leaks into a fresh cast |
| Alt-Tab after scrolling Jump, then return | No delayed wheel jump; fresh deliberate controls work |
| Move after returning | Ordinary directional input resumes; paid actions obey release-to-rearm |
| Gallery browsing and selection | Ordinary selection still uses host confirmation; no repeated same-character reset |

Automated tests inject real input events/production focus notifications; they
do not claim a physical Alt-Tab/controller or two-PC acceptance session. The
previous installer is unchanged, so use the source launcher for this refinement.
