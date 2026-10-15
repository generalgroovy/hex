# October 15 product-loop candidate evidence

Status updated **October 16, 2026**: **clean Windows Full passed; source candidate is not packaged or promoted. Qualified desktop delivery remains p61-d6d1bfb9c529.**

The [assessment](../BREAKTHROUGH-ASSESSMENT-20261015.md) explains product priorities;
the [single queue](../../.agent/OVERHAUL-IMPLEMENTATION.md) owns remaining work.
The focused producer identifies candidate **p61-6618873387e2**, with 3,450 runtime
records. Clean Windows CI now completes its source Full gate. That pass and the
native layouts do not qualify a replacement portable or supersede existing d6d1.

## Executed evidence and its limits

| Evidence | Recorded result | Scope |
|---|---|---|
| [Circuit focused receipt](circuit-focused.json), [raw log](circuit-focused.log), [current state](circuit-focused-current-state.json) | **548 assertions, zero failures/stderr**: signature-circuit 488; signature-circuit-integration 60 | Prepared coordinator/panel checks plus actual controller-created encounters, three real paid wins, earned-spell payment/release, Range entry and normal-weave restoration. Progression is memory-only; no durable save/reopen claim. |
| [Earlier focused receipt](first-focused-fixture-failure.json) and [raw log](first-focused-fixture-failure.log) | Map **1,403 / 0**; Circuit **488 / 1**; overall run **failed** | The map subset passes, but the whole run remains failed. The completion fixture cloned can_next=true into a complete result; a test-only state correction and stronger exact-text assertion produced the later passing Circuit run. No production result logic was weakened. |
| [Native UI log](native-ui/capture.log), [empty stderr](native-ui/capture.log.err), [inert helper](native-ui/capture.gd.txt) | **8 captures**, each 960×540, terminal PASS | Three prepared Circuit stages and the map at scale 1 and 2; logical 480×270 at 200%. Independent review covers text/button fit and pager separation, not physical interaction, moving combat or performance. |
| [Helper parse failure](fixture-corrections/capture-helper-parse-error.log) | Failed before rendering: Panel alias shadowed a native class | Fixture correction only; retained as negative evidence. |
| [Wrong content-scale image](fixture-corrections/wrong-canvas-scale.png) | Earlier 960×540 output contained only a 720×405 rendered area | Does not satisfy the intended native fit gate. The later helper explicitly fixes the root content canvas; the failed image remains preserved. |
| [Terminal Full-a receipt](full-a/tests.json), [raw log](full-a/suite.log), [archive inventory](full-a/archive.json), [independent terminal review](full-a/independent-review.json) | **Failed**: 112 of 267 suites completed; 5,280,932 assertions; nine failures; 2,700-second timeout. **155 suites incomplete; boot not run.** | One network-capture failure remains unresolved. Eight remap assertions followed a stale test menu-row assumption; their stable-ID keyboard repair does not retroactively pass this run. Import/suite stderr is empty, which does not negate the logged failures or timeout. Original bytes are preserved; the compressed asset inventory expands to its recorded producer bytes. |
| [Post-Full focused-review-a](review-a/tests.json), [independent review](review-a/independent-review.json), [reviewed test-only changes](post-full-test-repairs/archive.json) | **Passed seven suites / 65,133 assertions / zero failures and stderr**, **264,217 ms** | Tools 58,514; Circuit integration 314 including exact InputMap teardown; Circuit 488; local navigation 3,847; map 1,403; signature recovery 68; solo-trial process 499. All pass. The seven suites exclude the failing eight-player network scenario. The applied changes preserve real keyboard menu selection, restore global InputMap state, and add bounded network traces/first-failure diagnostics. No production repair, retry or capture-limit change; runtime 661887 and its 3,450 records are unchanged. |
| [Clean Windows CI Full receipt](ci-full-38817305452/receipt.json), [independent review](ci-full-38817305452/independent-review.json), [archive inventory](ci-full-38817305452/archive.json) | **Passed 267 suites / 7,576,123 assertions / zero failures**, three stderr files empty, correct **661887 / 120 Hz / protocol 61** boot | Exact clean checkout **932f5974fe17a8d2432d8f82873eb86faf564543**, [run 38817305452](https://github.com/generalgroovy/hex/actions/runs/38817305452). Independent review reconciles all 267 ordered results and timings. Producer Full duration 937,643 ms; suite timing sum 717,841 ms; CI job 17m 0s. Signature recovery 68, progression 6,358, Circuit 488, integration 314 and network impairment 34,370 all pass. Source validation only: no replacement package/promotion, Linux qualification, physical-input or FPS claim; historical local capture cause remains unresolved. |
| [Light setup archive](profile-light-concurrent-a/archive.json), [independent review](profile-light-concurrent-a/independent-review.json) | **Failed setup; no gameplay measurement**: no recorded Start, armed=false, no instantiation and no results; wait 300,002 ms | Five raw producer files are preserved, with two losslessly compressed files verified after decoding. Other Codex tasks were running, but this is not a causal finding about the missed Start or performance. No automatic restart. |

Separate local outage diagnostics [A](network-outage-a/receipt.json) and
[B](network-outage-b/receipt.json) passed **6,478 / 0** and **6,465 / 0**
assertions/failures, each with **241 trace rows** and no rejected capture
reproduced; independent reviews [A](network-outage-a/independent-review.json)
and [B](network-outage-b/independent-review.json). Both use the same pinned
runner/inputs; dynamic receive checks can differ with polling, so this does not
prove identical trajectories. The historical capture cause remains unresolved;
the later clean CI Full pass is separate source-validation evidence. Delivery
qualification for the candidate remains open.

[Technical execution review](execution-review.md) independently reconciles the
focused receipt, raw assertions, source identity and selected native images.
[Experience visual review](visual-review.md) records inspection of all eight
corrected images, their dimensions/hashes, and the byte-exact inverse of the
narrow test-fixture repair. These reviews do not convert prepared UI outcomes
into paid combat evidence; the actual integration suite supplies that separate
boundary.

The [4,632-input snapshot](validation-inputs.json) pins local validation bytes and
membership captured for Full. It is not a Full PASS receipt, Git-clean claim,
Linux checkout qualification or evidence that CI ran. The failed Full archive
above describes those original validation inputs. The later focused pass
does not complete the other Full suites, run the missing boot, or establish
the historical network-capture cause. Pushed checkpoint [932f597](https://github.com/generalgroovy/hex/commit/932f597)
on `codex/hex-breakthrough-20261015` subsequently passed the complete clean
Windows CI Full recorded above. Its own receipt and inputs establish that pass;
they do not alter the original local snapshot or failed receipt. The source
candidate remains unpromoted and has no replacement-package qualification.
The Light source attempt expired before manual Start: **armed=false, empty
results, no gameplay measurement**. Other Codex tasks were running, but this
does not establish the missed-Start cause or any performance result. Matched
Full/Light and packaged pacing remain open; no automatic restart is planned.
Root owns final status.

## Specialist inputs

These inputs were developed concurrently and reciprocally reviewed:

- [Gameplay audit](gameplay-audit.md): short authored rival route, earned tool use,
  encounter authority and reference mechanisms.
- [Experience audit](experience-audit.md): discovery, compact map, art/action
  coverage and an integrated visual pilot.
- [Technical audit](technical-audit.md): performance evidence, memory, launcher,
  delivery and exact Full/Light observation limits.

Root integrates and serializes every engine invocation through the desktop
launcher. Source reviews are not executed tests. The Circuit's actual paid
learned-spell release establishes a working mechanism, **not tactical usefulness,
replay appeal or commercial demand**. Those questions require observed choices
and understandable next-fight opportunities. The broader illustrated animation,
tall-wall/occlusion/interior and campaign design remains proposed.

The qualified portable, fallbacks, saves and published handoff branch are
preserved. Candidate package/lifecycle, durable Circuit save/reopen, current
packaged performance and unfamiliar-player acceptance remain separate gates.
No store publication or commercial-success claim follows from this candidate.
