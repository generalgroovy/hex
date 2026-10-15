# Stationary ground branch - retained for production qualification

The ignored candidate removes target-speed, carry, drag and approach work only for zero-input/zero-planar-velocity actors with the exact PlayerState and SimConfig scripts. The existing preserve-idle return, sprint admission assignment and stamina recovery behavior remain intact. Derived state/config and every moving case use the predecessor body. No canonical change or production qualification is claimed by this archive; the measured baseline remains p61-64590c45c7a5.

Four native processes passed through the desktop Diagnostic launcher. Each completed three finite 48-tick paid cases and 5,080 helper checks, with 9 worlds/courts released. Each also passed 20 direct compatibility cases and the same 20 cases through a separate counted mirror: 48 stationary returns, 28 fallback executions and 4 preserve-idle returns. Counter code never enters either timed world. A concrete third world supplied every-step actor/event/input/payment equality; complete strict state/packets were checked at entry and exit. Every run's commands, semantic rows and complete endpoints match across processes. The final independent readback performed 13,329 checks; Gameplay separately performed 5,031 first-pair and 7,097 repeat checks.

The preset primary gate uses rows 4-47: at least 3% AND 30 microseconds of mean whole-step saving in BOTH stationary paid cases, positive paired median, and positive savings in both invocation-order strata in each process. All 8 workload/process gates pass; all 16 primary order means are positive. First 4 rows and the single admission/release rows remain visible in the raw results and analysis.

| Process | Fire mean saving | Mantle mean saving | Moving Fire mean saving |
| --- | ---: | ---: | ---: |
| forward-a | 61.386 us / 5.824% | 65.182 us / 5.767% | -3.909 us / -0.683% |
| reverse-a | 97.705 us / 9.149% | 108.386 us / 9.021% | -2.841 us / -0.633% |
| forward-b | 83.023 us / 8.093% | 155.955 us / 10.608% | -6.500 us / -1.462% |
| reverse-b | 98.205 us / 8.826% | 121.932 us / 9.730% | 6.932 us / 1.294% |

Tail counterevidence is preserved. Fire forward-a p95 rose from 1451 to 1707 us (+17.64%); the other Fire processes changed -13.63%, -8.43%, +3.08%. The extra unchanged pair was explicitly requested to check that first spike, not to change the original mean gate. Moving Fire p95 changed +1.81%, -9.51%, +6.31%, -0.51%; its single result above 5% does not meet the preset repeated-regression rejection, and no moving mean exceeded both 3% and 30 us. This is not a tail-latency or smoothness guarantee.

The stationary cases contain the actual five-actor campus roster; the negative control deliberately contains one continuously moving actor, preventing stationary training targets from hiding moving-path overhead. Fire first release/ground occurs at ticks 9/24; Mantle at 13/17. All cases have exactly one paid admission, one release, zero refusals and 600 finite matter paid, without regranting. Existing simulation profilers are off in all three worlds; clocks enclose pristine whole-step calls. Per-step proof occurs between calls and affects locality. Host-memory endpoints are context only. These results do not establish a whole-application, GPU, physical-input, threaded-CPU or FPS improvement.

[Final readback](review.json), [independent Gameplay first-pair review](peer-review-a.json), [independent Gameplay repeat review](peer-review-b.json), and all four raw receipt/runner/log sets are preserved. Source and runner files are archived as `.txt` to avoid engine registration. Their original paths and exact bytes are in [manifest.json](manifest.json); restoring the original ignored paths and the pinned 6459 checkout is required to rerun. Canonical integration and relevant regression tests remain a separate root-owned gate.
