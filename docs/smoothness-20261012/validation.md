# Validation evidence — October 12 smoothness pass

The [clean Full rerun](full-final.json) passed **261 suites, 7,401,986 assertions,
zero failures and zero-byte stderr** on `p60-be680e20d70e`, in 1,252,982 ms
(20 minutes 53 seconds). Import, source identity checks and the 120 Hz boot also
passed. The fresh local package, standalone payload verification, exported
terrain and five-case release lifecycle gates also passed. Runtime source
is unchanged by the test-only repairs: 3,436 records, SHA-256
`be680e20d70e1a284eb4175916a7d97da4446b20bfada79a89f98e741446aa8e`.
The preceding [focused gate](rich-repair-focused.json) passed **10 suites,
38,952 assertions, zero failures, exit 0 and zero-byte stderr**. See the
[technical evidence](technical.md) and [performance boundaries](performance.md).
Smooth sustained 60 FPS remains open.

Independent verification reconciled every Full suite row against the
[raw log](../../.godot/windows-tests/068f46fa05b64885b455b984f61455a7/suite.log),
recomputed its import/boot/suite log and source-report hashes, and checked all
three stderr files were empty. The source report and boot log identify the same
runtime above. Full suite-log SHA-256:
`000e9a4ce5f90d567de01e29032d7124b93d4e6b4823d45dbd84c645441c7201`.
Full receipt SHA-256:
`eed1514ac97d13fe9a81c8989ad596bc1cf6b4dfb4f5507aa16a09530b710fa6`.
This Full tier did not execute package/installer acceptance; that receipt field
is explicitly false. The subsequent package and delivery receipts below provide
their separate evidence; no installer was run.

**Local delivery passed.** The [package](package.json),
[standalone delivery](delivery-files.json), [terrain](terrain-pack.json) and
[release lifecycle](portable-lifecycle.json) receipt copies are byte-identical
to their originals. Independent read-only checks recomputed the ZIP/PCK hashes,
all ten unique ZIP members and corresponding loose payload hashes and lengths.
`SOURCE-IDENTITY.json`, exported `BUILD-STATE.json`, smoke and lifecycle logs all
identify `p60-be680e20d70e`. Export/smoke stderr is empty and the smoke log records
the completed safe-close path. The prior `p60-845f85b5253e` fallback's PCK and ZIP
still match its receipt.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| [Portable ZIP](../../exports/hex-smoothness-20261012/HEX-p60-be680e20d70e-Windows-x64.zip) | 161,150,389 | `9a41e2f97351d012e89da3a0aecf7d9ece95ac8d3fa930fedc207eb806451c83` |
| [Exported PCK](../../exports/hex-smoothness-20261012/windows/hex.pck) | 137,735,760 | `a166de4eb134061949c831910e3dd43ebdae4985680dfc7c4af9b144af5729ac` |

The isolated terrain verifier passed **2,062 checks**, decoding **132 chunks and
one overview** from the exported PCK. Its mounted copy, expected identity/manifest,
eight source hashes and unchanged minimal project were independently reconciled
with the current files and receipt; terrain stderr is empty. This verifies
exported terrain integrity, not native visual or frame-pacing acceptance.

The actual release executable passed Hearth, Garden, paid Fire, paid all-six
Mantle and reopen cases with normal owned-window closure. Every raw log hash
matches, each records both safe-close markers and the correct source identity,
and all five stderr files are empty. Independently parsed cast events confirm
**12 accepted / 0 refused** in each paid case. All five recorded preference
snapshots have the same hash; the final preference and backup files match those
records (`accdc4940c75081c7f1df399fd4af9db5c8066ce1ad4ad291b22f29a3e28c93f`).
The four watched payload hashes remain unchanged. The receipt records restored
caller APPDATA and a shared fresh isolated profile. These checks do not establish
foreground timing, physical-input access, earned progression, damaged-save
recovery, replay export or multiplayer acceptance. No new profile followed the
expired human-Start attempt; final-source smoothness remains open.

The preserved [first Full receipt](full-failed-rich-fixtures.json) records **261
suites, 7,400,531 assertions and 14 failures across 10 suites**, with zero-byte
stderr. Thirteen failures came from paid-state fixtures that requested a second
Fire Bolt after the faster Water Bolt had already completed its short route.
The remaining failure was the Compendium test's predecessor speed expectation.
The wrapper's generic `Godot emitted a script/import/runtime error` message is
retained unchanged; the raw log identifies these assertion failures and contains
no script-error, error or warning entry. This run remains failed.

The independently checked [focused raw log](../../.godot/smoothness-20261012/rich-repair-focused.log)
matches every suite row and the total in its receipt:

| Suite | Assertions | Failures |
| --- | ---: | ---: |
| hex-round-result | 5,517 | 0 |
| hex-owned-capture | 472 | 0 |
| owned-publication | 737 | 0 |
| session-broadcast-bytes | 643 | 0 |
| hex-strict-wire-decode | 833 | 0 |
| hex-sealed-snapshot | 300 | 0 |
| hex-producer-topology-reuse | 325 | 0 |
| hex-snapshot-optimization | 773 | 0 |
| hex-world-snapshot | 21,376 | 0 |
| player-compendium | 7,976 | 0 |

Both snapshot helpers now observe the real surviving flight, reaction product
and ordinary startup/recovery/cooldown readiness before submitting their single
follow-up Fire request. Scheduled Water requests retain priority; targets,
resources, bounded attempts and capture assertions remain intact. Their executed
diagnostics record **tick 176, pending wire 145 (Cinderbolt), one flight, one
product and 2,400 paid Matter**, equivalent to four ordinary 600-Matter payments.
The round fixture uses the same timing correction while preserving its guest's
separate Fire ground and paid Water Heavy startup. Its passing assertions require
simultaneous flight/product/ground/reservation, a damaging unsealed positive
control, exact result cleanup and conservation for timeout, score, departure and
mutable geometry. The Rampart checks are unchanged. The Compendium expectation
now checks current Rapid/Bolt/Heavy speeds and clash strengths, explicitly
separating HP damage and retaining the field-slow warning.

Original files were preserved before editing. Experience independently reviewed
the exact repairs, and the following current SHA-256 values were independently
recomputed after the focused run:

| Repaired test | SHA-256 |
| --- | --- |
| [Round result](../../tests/unit/test_hex_round_result.gd) | `b0c0df1ef479e514827977d79577e15fed9e2d1e814a7664a12effd8b64542d0` |
| [World snapshot](../../tests/unit/test_hex_world_snapshot.gd) | `b41037dbef15a3d57f6302d54d14e3cd13523f827d4b9bdce160ef0a3a8455a5` |
| [Snapshot optimization](../../tests/unit/test_hex_snapshot_optimization.gd) | `d603aa9878f155c54956451a7d0bde55c4a3a5cccdc42a3130d61bfbe09c7794` |
| [Player Compendium](../../tests/unit/test_player_compendium.gd) | `2c81a64c0dbbb7a497b88fad6570fd036e2fe0ca3f15191798f8f4d8d17a80be` |

The original [round fixture](../../.godot/smoothness-20261012/round-result-fixture-repair/test_hex_round_result.before.gd),
[world snapshot](../../.godot/smoothness-20261012/rich-fixture-repair/before/test_hex_world_snapshot.gd),
[snapshot optimization](../../.godot/smoothness-20261012/rich-fixture-repair/before/test_hex_snapshot_optimization.gd)
and [Compendium](../../.godot/smoothness-20261012/compendium-fixture-repair/test_player_compendium.before.gd)
remain local evidence. `.godot` artifacts are ignored by Git; their links require
this retained workspace. The first Full raw suite-log SHA-256 is
`c0cd5ad573f02d5d7f9de87465c3f660b465f4c49038d690d79845417c7da8bd`;
the repaired focused log SHA-256 is
`62a87eec743db4771f4ba760fe01f4d2c0c07a326bb35a699436fbfad4597e93`.
Both match their preserved receipts; both stderr files were independently
confirmed empty. Assertion totals vary with fixture loop length and successful
progression and are not a count of independent behaviors or proof of performance,
human feel, physical-input access or multiplayer acceptance.
