# T7 enclosing-profiler cleanup evidence

Root executed three separate Godot 4.7.1 native processes. Independent technical review passed all raw receipt, exact stderr, source-hash and cleanup-boundary checks: **194 assertions**, no unexpected diagnostics. The expected failure exits are part of the test; they were not ignored or converted into ordinary success exits.

| Case | Assertions | Process exit | Immediate end calls | Final end calls | Stderr |
| --- | ---: | ---: | ---: | ---: | --- |
| [Normal quit](normal/receipt.json) | 58 | 0 | 0 | 1 | Empty |
| [Inherited failure](failure/receipt.json) | 67 | 1 | 1 | 2 | Exactly the controlled failure heading and its backtrace |
| [Real report-I/O failure](io/receipt.json) | 69 | 1 | 1 | 2 | Exactly the rejected file-open heading and its backtrace |

Each case uses one real, ordinary paid Fire admission and the actual full-observer cumulative API. The actual inherited profiler cleanup changes only accumulation enablement. Tick, epoch, all nine stage counts/times, canonical state, strict packet bytes and combat events stay unchanged. The extra end call in failure cases is the actual finalizer's idempotent cleanup. The never-entered owned `TimedGame` is then freed; the side-channel receipt is written independently of the deliberately failed report path.

The [root summary](root-summary.json) records process exits, original receipt locations and hashes. The [archive manifest](archive-manifest.json) independently records byte lengths and SHA-256 values for all 13 copied artifacts. Original paths and source identities inside the receipts are deliberately retained. Copies are exact archival evidence, not relocated executable scripts: the helper's `res://` paths and the wrapper's repository paths still refer to the original working location.

The [helper](verify-completed-stage-cleanup.gd), [root wrapper](run-t7-cleanup.ps1), all three stdout/stderr pairs, and the [actual failure partial report](failure/profile.json.partial.json) are preserved. All 11 watched hashes in each receipt matched the source at independent review. This proof concerns the enclosing profiler only. It does not instantiate the application scene, validate art/audio teardown, test physical input, establish foreground qualification or measure frame pacing.
