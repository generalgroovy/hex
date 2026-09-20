# H.E.X. NET — Multiplayer lifecycle diagnosis

**Review date:** 2026-09-20. This is not the failed run's date.

**Status:** source-limited diagnostic contribution; no root cause established; no production patch; all runtime tests NOT_RUN.

## 1. Source basis and evidence classification

The only supplied current-task artifact is `Pasted text.txt`, a specialist assignment brief selecting `TASK_ID: <NET>`. Its SHA-256 is `baeb4e51c25d04095e135dea3ce13049664d3cf984038fdbe1367b94b5cd4d1c`. This identifies the brief, **not** a game source revision or executable.

The brief references a current design contract, active implementation queue, checkpoint, failed production-localhost run and relevant source, but does not include those materials. Library searches did not locate evidence tied to this particular run; older general FLUX material was excluded. No prior repository commit, engine version, executable path or protocol identifier has been substituted for the missing checkpoint.

| Item | Available evidence |
|---|---|
| Source revision, working-tree changes, build identifier and executable digest | NOT_SUPPLIED |
| Run identifier/date, participant count, seed, arguments and watchdog duration | NOT_SUPPLIED |
| Full current contract, active queue and checkpoint | NOT_SUPPLIED |
| Host, guest, driver/watchdog logs; profiles; relevant source | NOT_SUPPLIED |
| Reported journey outcome | Brief, line 39 only |

**Observed implementation facts:** none; no source, runtime trace or executable was supplied or executed.

**Documented outcomes:** the run reportedly reached first-round play, late-guest replication and exact-actor reconnect; Return to Hearth, second-round participation and administrative release were not completed before its watchdog [B:39]. These are claims in the brief, not independently verified runtime observations.

**Documented boundaries:** Godot authority, Windows as current release target, 120 Hz simulation target and eight-player target. This contribution does not change authority, gameplay, networking semantics, world rules or tested capacity [B:21–31].

**Hypotheses:** all proposed failure mechanisms below remain unverified. In particular, snapshot cost is not established as the cause [B:41–49].

**Proposed contribution:** observation-only lifecycle tracing plus a source-bound reproduction and regression specification.

## 2. Transition timeline and earliest divergence

There are no event timestamps in the supplied brief. A timestamped reconstruction would therefore be fabricated. The following is a milestone evidence ledger, not a reconstructed execution trace; its ordering follows the requested journey, not verified cross-process event order.

| Milestone | Actual timestamp | Reported status | What remains unknown |
|---|---|---|---|
| First-round play | NOT_SUPPLIED | Reached | Host/client state, authoritative tick and driver assertion |
| Late-guest replication | NOT_SUPPLIED | Reached | Guest identity, snapshot application and authoritative participation |
| Exact-actor reconnect | NOT_SUPPLIED | Reached | Identity evidence, transport mapping and completion criterion |
| Return to Hearth | NOT_SUPPLIED | Not completed according to brief | Whether requested, enqueued, received, rejected, committed or merely not observed |
| Second-round participation | NOT_SUPPLIED | Not completed according to brief | Whether round two existed and which participant/authority condition was missing |
| Administrative release | NOT_SUPPLIED | Not completed according to brief | Meaning of release, trigger, authorization, scope and completion condition |
| Watchdog boundary | NOT_SUPPLIED | Journey incomplete before watchdog | Start/deadline, final awaited predicate, progress and process exit behavior |

**Earliest actual divergence: UNKNOWN.** Return to Hearth is the first uncompleted milestone named after the reported successes, not a proven fault location. A driver wait or accumulated delay could prevent the request from being issued. An optimistic reconnect marker could also conceal an earlier disagreement. Those are hypotheses, not corrections to the brief.

The next trace must identify the first unsupported edge in this *proposed diagnostic model*:

`driver action → enqueue/send result → receive/dispatch → native guard decision → authoritative commit → consumer/driver observation`

These are observation points, not proposed game states or new protocol acknowledgments. Omit inapplicable edges only after inspecting the implementation, recording how the actual path is represented.

## 3. Evidence-ranked hypotheses

The strongest available evidence supports **an incomplete journey**, not a particular cause. A blanket claim that multiplayer never established is inconsistent with the reported successes. All remaining causal families are tied at **unverified**: there is insufficient evidence for an honest likelihood ranking. The order below is the proposed discrimination order.

| ID | Unverified hypothesis | Current support and contradictory/limiting evidence | Discriminating observation |
|---|---|---|---|
| H1 | Driver never issued the next action, or awaited the wrong completion predicate | Compatible with a watchdog ending a partial journey. No driver script or action trace supports it directly. A recorded correct action followed by a host-side failed transition would contradict non-emission. | Driver step, actual predicate and last observed values; action-issued record; send result |
| H2 | A lifecycle request reached the authority but was rejected or remained blocked by native state, identity, membership or round conditions | Compatible with failure around a lifecycle boundary. Reported exact-actor reconnect weakens an identity-never-restored explanation, but says nothing about every later guard or connection mapping. No rejected request is documented. | Receiver record, native state before evaluation, each relevant guard value and explicit outcome; expected/observed membership only where the existing contract uses it |
| H3 | A lifecycle message did not reach its required application handler | Compatible with partial success; earlier replicated traffic does not establish later lifecycle delivery. No specific message is documented as absent. Matching receive/dispatch and commit records would contradict this explanation for that request. | Correlated enqueue, API send result, receiver dispatch and handler records, plus trace-loss counters |
| H4 | Driver, host or guest scheduling stalled progress long enough to consume the deadline | Compatible with a timeout, but unsupported by timing/progress measurements. Continuous bounded progress and promptly serviced relevant callbacks would weaken it. | Per-process main-loop/authority progress, driver polling progress, external supervisor liveness and outstanding work spans |
| H5 | Transport disconnected, errored or changed mapping after earlier successful operations | Earlier success argues against a connection that never worked, not against a later failure. No disconnect, socket error or transport identity transition is supplied. | Transport state/error events and connection-instance mapping around the request; application callback evidence |
| H6 | Snapshot preparation/encoding/enqueueing delayed the relevant lifecycle path or exhausted the overall time budget | Explicitly a hypothesis in the brief. There are no measured durations, bytes, lock/queue observations or profiles here. Successful earlier replication is limited counterevidence to a snapshot path that never worked. | Snapshot stage begin/end or aggregate spans, outstanding stage, bytes/counts and overlap with lifecycle waits; check whether the work actually occupies or blocks the required execution path |

H6 is a possible mechanism within H4, not independent supporting evidence for it. A slow snapshot measured after the divergence does not explain that earlier divergence. Large snapshot size alone also does not establish blocking.

“No receive record” is not enough to assert packet loss: non-emission, failed enqueue, logging loss, dispatch failure, receiver starvation and transport failure must remain distinguishable.

## 4. Recommended solution: one observation-only capture slice

Instrument the original journey without changing its workload, authority frequency, feature set, deadlines, delivery mode, retries, state transitions or success predicates.

### 4.1 Proposed trace record contract

Use structured records. Map labels to real source symbols during integration; these are not claims about existing methods or fields.

| Record group | Minimum content |
|---|---|
| One header per process instance | Run ID; role and process-instance ID; source revision and dirty-diff digest; executable digest; launch arguments; actual seed; participant topology; configured tick rate; original phase/global deadlines; available clock mapping |
| Every lifecycle record | Per-process sequence number; monotonic timestamp; current native authoritative tick if available; event; native session/round identifiers if present; correlation evidence; outcome/reason |
| Driver action/wait | Step; actual awaited predicate; relevant last values; action issued; monotonic deadline and elapsed wait |
| Enqueue/send/receive/dispatch | Message kind; native correlation/sequence identifier where present; sender/receiver connection instance; enqueue/send result; handler entered |
| Guard/commit/observation | Native phase before/after; requested operation; evaluated guard values; accept/reject/wait outcome; commit identifier if already available; state observed by guest/driver |
| Identity/transport change | Logical participant/actor identity; old/new transport connection instance; native mapping change; disconnect/error reason |
| Watchdog expiration | Original start/deadline; final awaited predicate and values; last action and authority progress; outstanding stages; process status; trace-loss counts |

Reuse existing message identifiers. Where none exist, record local observation identifiers and mark cross-process correlation as unknown rather than pretending matching names prove identity. Do not add a wire field or invent a round epoch as part of this source-unbound proposal. A later source-backed instrumentation diff may identify whether stronger correlation is needed.

Do not conflate an actor identifier with a transport peer identifier. Observe their actual mapping, especially before and after reconnect. Do not require actor persistence across rounds unless the current contract requires it.

Order events within a process using its sequence and monotonic clock. Across processes use proven message causality and mapped authoritative ticks. Wall time is display metadata unless synchronization and uncertainty are established; do not subtract unrelated process-relative monotonic timestamps or treat unmapped client ticks as host ticks.

### 4.2 Minimal work/progress measurements

Capture low-cost begin/end observations or existing timers for the real snapshot preparation, encoding and send-enqueue stages. Record an outstanding stage so a blocked span is visible without requiring its end record. Record count, bytes and elapsed-time aggregates outside the simulation hot path; do not serialize, clone or hash a second snapshot solely for logging.

Record both elapsed wall time and authoritative tick progress. A 120 Hz target implies an 8.33 ms target tick interval; it is not a measured tick cost or a claim that every lifecycle operation must finish in one tick [B:23]. A stalled simulation can fail to advance tick-based deadlines, so retain the independent wall-clock watchdog.

The external driver/supervisor should record process liveness and its own progress independently of the game loop. A game-loop heartbeat alone cannot prove what happened while that loop was blocked. Liveness alone is also not proof of useful progress.

Use bounded capture for the bounded test run, with explicit dropped/overwritten-record counters. Avoid synchronous per-tick disk output and full-world dumps. A trace gap with unaccounted capture loss must produce `INCONCLUSIVE`, never a packet-loss or deadlock diagnosis. Capture bookkeeping must not mutate gameplay events or their retention.

### 4.3 Tradeoff and strongest counterargument

**Principal tradeoff:** this adds diagnostic overhead and requires another run instead of immediately fixing gameplay. Instrumentation can perturb timing; measure enabled versus disabled capture with the same scenario and record the difference rather than assuming it is negligible.

**Strongest counterargument:** the original logs or a small state-machine source defect may already reveal the cause, making extra instrumentation unnecessary or capable of masking a race. Obtain and inspect those inputs first. Instrument only unresolved edges; do not use this plan as a reason to postpone a source-supported small fix.

## 5. Deterministic reproduction and regression proposal

All cases below are **NOT_RUN**. No harness or production execution is implied.

### 5.1 Preserve the original failure first

Freeze the actual source revision plus local changes, production executable digest, Godot version/export settings, command lines, process topology, scenario seed, input script, event/snapshot workload and original phase/global deadlines. Do not substitute an older known commit or quietly increase the watchdog.

Rerun that exact script with observation-only capture. Retain complete driver, host and guest output, including process-exit records. Start the evidence window before first-round play: an earlier delay can consume a global watchdog even when the visible incomplete milestone is later.

Success for this **diagnostic rerun** means either a documented full journey or a bounded failure whose first unresolved edge and evidence limitations are explicit. It is not itself a release acceptance claim.

### 5.2 Controlled logical regression

Build the regression on the actual harness after its source is supplied. Use its existing authority observations and deterministic input facilities; do not write a replacement simulation or force internal state.

Drive this sequence with explicit semantic barriers rather than arbitrary sleeps:

1. Establish the first round and prove authority-observed participation using the current success predicate.
2. Join the late guest through the real admission path. Observe required replication and authoritative actor presence; connection alone is insufficient.
3. Disconnect and reconnect the designated participant. Verify the contract's exact-actor restoration condition and absence of an unintended duplicate actor. Observe the native connection mapping; do not assume its numeric identifier remains unchanged.
4. Invoke the contract's real Return to Hearth trigger. Verify the authoritative transition and observations by every participant required by that contract. Do not assume Hearth means disconnecting, unloading a scene or destroying actors.
5. Start round two through the real supported control. For every eligible participant, submit a distinguishable supported input and prove the authority applied it to the correct actor in the new round. A changed UI label or rendered actor alone does not prove participation.
6. Invoke administrative release through its real authorized path. Verify exactly the resources, membership and terminal condition defined by the contract. Do not equate release with process termination or destruction of every reusable lobby resource.

Freeze the seed and ordered input/event schedule for logical repeatability. Specify fault-injection positions by named barrier and message identity. Real Windows process/UDP scheduling is not thereby made deterministic: retain a separate unmodified production rerun to test timing-dependent failures. A barrier-controlled test may hide the original race, so it cannot replace that rerun.

### 5.3 Acceptance cases

| Case | Setup/input | Required outcome | Status |
|---|---|---|---|
| NET-01 Original production reproduction | Exact original topology, workload, script and deadlines; trace on/off comparison | Preserve the failure or document non-reproduction. Trace identifies issued action, last verified edge, outstanding predicate and limitations without inventing a cause. | NOT_RUN |
| NET-02 Full lifecycle | Execute the six-barrier journey at the recorded baseline participant count | First-round and late-join evidence; exact-actor reconnect; contract-compliant Hearth transition; authority-applied round-two input for each eligible participant; authorized release completion, all before their unchanged applicable deadlines. | NOT_RUN |
| NET-03 Stale/duplicate lifecycle traffic | Using actual harness hooks, hold one existing lifecycle message at a fixed barrier and deliver it after reconnect or a round boundary; separately repeat a message whose duplicate behavior is defined by the protocol | Native stale/duplicate policy is enforced; no unintended duplicate actor, phase rollback, stale authority grant or premature completion. Accepted, rejected or ignored outcomes are observable. Do not invent rejection where the protocol permits idempotent acceptance. | NOT_RUN |
| NET-04 Independent diagnostic faults | Separate runs: delay one lifecycle delivery; hold the actual snapshot stage at a defined test hook; prevent the driver from issuing the next action. Keep underlying gameplay workload unchanged. | Capture distinguishes not-issued, delivery/dispatch gap and blocked execution. Lost diagnostic records produce INCONCLUSIVE, not a fabricated network diagnosis. Injected stalls are diagnosis tests, not performance measurements. | NOT_RUN |
| NET-05 Eight-player target | Repeat the full lifecycle with exactly eight player participants using the contract's process topology | All eligible participants satisfy lifecycle/round-two assertions and release predicates; no silent wait for stale connections; no additional capacity claim. | NOT_RUN |

If a required predicate, deadline, native identifier or injection hook is undefined in the supplied implementation, mark the case BLOCKED_INPUT rather than filling it with an invented API or declaring a pass.

## 6. Patch disposition and required source packet

**Production behavior patch: none.** There is no supplied implementation against which a trustworthy diff can be written. No retries, timeout increases, forced phase assignments, acknowledgment requirements, new wire fields, snapshot frequency changes or new transport architecture are recommended as fixes.

The only recommended initial integration slice is observation-only tracing at existing lifecycle boundaries plus the original-run capture manifest. Bind every changed hunk to the supplied checkpoint/dirty source and rebuild identity; inspect for drift before applying it.

To support an actual timeline and narrowly scoped fix, attach this run-specific packet:

- The checkpoint and active-queue entry, source revision plus local diff, production executable digest, Godot/export identifier and launch manifest.
- The current contract excerpts defining Return to Hearth, round-two admission/participation, exact-actor reconnect, administrative release and the related authorization/completion rules.
- Complete timestamped driver/watchdog, host and guest logs for the failed run, the original driver script and its timeouts, and any existing profile covering the run.
- The source functions called by that script: action emission, lifecycle send/receive/dispatch, native transition guards/commits, reconnect identity mapping, release, snapshot work scheduling and watchdog completion checks. Include callers and relevant state declarations; actual filenames must come from the checkpoint.

## 7. Checks and integration handoff

**Checks executed:** read the supplied brief; searched for matching run evidence and excluded unrelated older material; verified the mounted input exists and decodes as UTF-8; computed its SHA-256; created and checked this standalone Markdown handoff.

**NOT_RUN:** compilation, source-level patch validation, Godot execution, Windows export, localhost reproduction, profiling, deterministic/replay regression, eight-player acceptance and administrative-release acceptance.

| Handoff field | Result |
|---|---|
| Source basis | `Pasted text.txt`, TASK_ID NET; brief fingerprint above. Game source/build/run identifiers remain NOT_SUPPLIED. |
| Recommended contribution | One observation-only lifecycle capture slice, preserving the original scenario and deadlines. |
| Artifact | `HEX_NET_handoff.md`: source audit, missing-timestamp ledger, evidence-ranked hypotheses, trace contract, reproduction/regression specification and integration requirements. |
| Proposed gameplay/protocol contract changes | None. |
| Unresolved risks | Missing current implementation and raw evidence; undefined release/transition predicates; capture timing perturbation; missing native message correlation; trace loss; timing races hidden by semantic barriers. |
| Smallest next integration slice | Bind trace labels to actual source and capture the unchanged original production journey. |
| Acceptance | Each attempted milestone has a traceable action, handler/guard/commit/observation outcome or a precisely bounded unknown edge; watchdog output names the actual pending predicate; trace loss is accounted for; workload, simulation target, authority, protocol semantics and deadlines remain unchanged. This accepts diagnostic coverage only, not multiplayer runtime readiness. |

## Source reference

[B] User-supplied `Pasted text.txt`, using the line numbering provided in this conversation: evidence rules 9–19; boundaries 21–31; NET assignment and documented outcome 37–49; completion requirements 160–173. All proposed records, experiments and acceptance criteria above are original recommendations, not claims that those mechanisms already exist.
