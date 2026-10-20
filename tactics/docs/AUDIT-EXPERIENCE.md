# Experience audit and bounded optimization

Source control: the audit began at `98d70bba`. The release receipt identifies the integrated and published revision. This document records the visual/audio specialist's evidence, decisions and limits; mechanics, input and recovery have separate owners.

## Findings and resulting changes

| Evidence at audit start | Player consequence | Bounded change | Acceptance |
| --- | --- | --- | --- |
| The renderer skipped score events because they have no hex coordinate. The report excluded scoring and selected only the first three reaction/damage/fall events. A wide spell can emit many reactions before a fall. | Players could see the score change without a useful explanation of why, while decisive outcomes were buried. | Aggregate a score-first exchange summary, prioritize falls and blocked actions, retain statuses and health/reaction totals, and show positive well scoring in aftermath. Keep the complete event record. | A prepared 19-reaction exchange still reports score deltas, a fall and Blind. Zero-point exchanges do not play scoring audio. |
| Replay ended at 2,250ms; terrain labels could end at 2,390ms and return labels at 2,650ms. Normal resolution ended at 2,600ms. | Replaying an exchange cut off its final feedback. | One 2,800ms presentation clock for normal resolution, replay and audio. Cast begins at 450ms, impact at 900ms, aftermath at 1,700ms. | Every event delay plus its label duration fits inside the shared clock. Changing the sound setting does not restart replay. |
| Same-cell labels alternated between only two vertical offsets. Each tile in an area reaction repeated the same large reaction name. Reduced-motion CSS made all labels persist, aggravating overlap. | Status, damage and heal labels could obscure one another. | Three prioritized labels per hex, then an explicit overflow count. Keep every tile's reaction burst, but name each reaction combination once with its tile count. | Five same-cell updates render as three labels and `+2 updates`; 19 identical reaction tiles render 19 bursts and one name. Reduced motion keeps stable feedback without requiring animation. |
| Phone CSS hid the entire secondary terrain readout: elevation, expiry, barriers and occupant resources. | Information used to choose a route or target vanished on smaller screens. | Allow the compact inspection readout to wrap on phones. Keep the seed secondary. | Browser checks at 390×844 and 320×844 showed no horizontal overflow. Wet, Chilled and Resolve remained visible, with Chilled correctly showing two movement effort. |
| Audio consisted of one generic resolution chime started before events. Context creation was lazy, resume failures were not handled, and there was no owned-source cleanup. | Sound carried little useful meaning and could be unavailable despite an enabled setting. | Optional semantic stage cues, explicit gesture unlock, bounded voices, cancellation on mute/replay, generation protection against late unlock, and disposal. | Mocked-context tests cover silence before enable, denied unlock/retry, mute during pending resume, bounded overlap, replay replacement and cleanup. Actual-browser and listening checks are separate. |

The motion finding was refined during review: the original 1.4-second movement animation reached the planned landing at 30% (420ms), held through 60% (840ms), then showed displacement. It did **not** spend 1.4 seconds walking to the casting position. The original cast phase began at 390ms, only 30ms before landing. The implemented keyframes now reach landing at 450ms and begin displacement at 900ms, matching the shared phase clock. The replay cutoff was the larger, directly demonstrated defect.

## Style and scope decisions

The existing release screenshots show a coherent parchment palette and original H.E.X. pixel atlases. Character silhouettes, target dots, footprint hatching and separate confirmation are worth preserving. This change therefore improves the relationship between a chosen action and its visible result; it does not replace artwork or add ornamental screens.

Cross-review elevated two other specialists' findings: a hover preview could differ from the draft committed by Confirm, and known allied landing collisions were not disclosed. Both outrank adding more decoration. The experience specialist reviewed the bounded input and plan-insight helpers and found their distinction between known allied conflicts and uncertain rival actions appropriate.

Potential performance costs from repeated SVG rendering and persistent compositor hints were identified as hypotheses only. No frame-time regression was measured during this source audit, so the team did not claim a performance gain or change rendering architecture without evidence.

## Evidence

- `tests/feedback.test.ts`: six cases covering wide-area outcome summaries, score-only wording, complete event timing, distinct label lanes/overflow, reaction aggregation and silent zero-point rounds.
- `tests/game-audio.test.ts`: four cases covering explicit enable, source bounds and schedule alignment, late-unlock cancellation, rejection/retry, replay replacement, connection cleanup and disposal.
- The four existing battlefield geometry tests still pass, including all 960 original animation frames and phone camera geometry.
- All 208 tests and TypeScript passed on the integrated candidate.
- A prepared server-render fixture in `work/audit-experience-ssr.mjs` produced `PASS`: 19 reaction bursts, one reaction name, four capped same-cell labels including overflow, visible scoring, 127 disabled targets during resolution and no aim overlay.
- Mechanics and reliability specialists independently reviewed the feedback/audio changes. The mechanics reviewer caught zero-valued score events triggering a scoring cue; the condition was corrected and regression-tested. Reliability highlighted asynchronous toggle UI ordering for the integration owner.

## Completed browser and audio checks

The integration owner checked the actual interface at measured 390×844 and 320×844 browser viewport sizes. Neither had horizontal page overflow. Wet, Chilled and Resolve were visible; Chilled showed two movement effort. After a resolved exchange, the interface reported damage and status changes, and replay completed and returned control to planning.

The temporary `public/__audit-audio.html` harness imported the actual game audio module and rendered a prepared exchange with `OfflineAudioContext`. The resulting WAV and JSON receipt were saved in the task's `outputs` directory. Signal measurements were:

| Measurement | Result |
| --- | --- |
| Duration | 3 seconds |
| Channels | 1 (mono) |
| Sample rate | 44,100 Hz |
| Frames | 132,300 |
| Peak amplitude | 0.02910464 |
| RMS amplitude | 0.00318417 |
| Nonzero samples | 37,877 |
| Clipped samples | 0 |

The real-context **Play cues** button accepted the browser gesture and entered its Playing state. This establishes the gesture/playback path and the offline signal bounds; it is not a listening evaluation or proof of physical speaker output. The harness was copied to the task's `work` directory, then the exact temporary public file was removed before the production build.

Automated signal bounds, scheduling tests and browser viewport checks do not prove pleasant sound, human comprehension, competitive balance, physical iOS/Android behavior, mobile GPU performance or commercial success. No physical-device or listening evidence is claimed.
