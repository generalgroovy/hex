# Integrated usability checkpoint

**Paused at the qualified p61-7804a23eb300 checkpoint.** The later
[coherent Full gate](../full-7804/README.md) passes 265 suites / 7,573,807
assertions, zero failures, empty stderr and the 120 Hz boot check. All four
affected suites pass within Full with the same 95,514 assertions; Gameplay
independently recounted the raw ordered results. The
[fresh delivery](../delivery-7804/README.md) also passes 18 archive checks,
133 terrain images / 2,064 checks, and five normal-close/reopen cases with twelve
Fire and twelve all-six Mantle admissions, zero refusals and zero extra outcomes.
Its [independent review](../delivery-review-7804/review.json) passes 3,789 checks.
The [current local launcher](../../../exports/hex-checkpoint-20261013-7804/windows/PLAY-HEX.cmd)
selects 7804; the [qualified500be fallback](../delivery-review-500be/review.json)
remains preserved. No new experiment is active; further work requires a user resume.

This archive was assembled and independently reviewed **before** those Full and delivery results. Its exact [manifest](manifest.json) and [review](review.json) therefore retain the truthful archive-time status `FULL_AND_DELIVERY_PENDING`. They are preserved byte-for-byte, not rewritten to inherit later qualification. Gameplay independently verified all 49 payload hashes, the seven final source mappings, both repair chains and linked evidence without requesting correction.

The integrated seven-file batch preserves the reviewed behavior: mapped F5/F6 hints follow current ownership, the tactical slide-jump lesson explicitly says press and release, and otherwise-eligible finished results let already-admitted finite audio tails finish while external blockers still silence them. The [application receipt](application/receipt.json) and [staged manifest](application/staged-b-manifest.json) record exact application. Original and initially applied bytes are preserved under `application/before` and `application/applied`; original LF/CRLF conventions are retained. The staged manifest's unapplied wording is historical; its later application receipt establishes application.

| Affected suite | Passing assertions | Passing run | Overall-run boundary |
| --- | ---: | --- | --- |
| Local navigation | 3,817 | [focused-a](failed-focused-a/receipt.json) | Other suites failed; this subresult passed |
| Signature progression, including paid press/release gesture | 6,311 | [focused-a](failed-focused-a/receipt.json) | Other suites failed; this subresult passed |
| Spell testing tools, including supported remaps and paid input | 58,488 | [focused-b](failed-focused-b/receipt.json) | Audio still failed one fixture assertion |
| Element audio | 26,898 | [focused-c](focused-c/receipt.json) | Passed, zero failures and empty stderr |

That is 95,514 passing assertions across the last successful affected-suite results, not one clean four-suite run and not Full. Focused-c's runner took 83,123 ms; its suite reported 3,596 ms. These are distinct intervals, not gameplay performance measurements.

Both rejected overall runs remain exact. [Focused-a](failed-focused-a/manifest.json) found an undeclared test script alias, nonexistent `HOST` enum, and a dynamic untyped command-array call that returned before handoff guard decrement. Sixteen remap paid-action assertions then failed. The first [reviewed test-only repair](fixture-repairs/aliases-and-command-array/manifest.json) adds the canonical preload, uses `HOSTING`, and supplies `Array[SimCommand]`; its [application](fixture-repairs/aliases-and-command-array/application.json) preserves every assertion and command.

[Focused-b](failed-focused-b/manifest.json) passed remap tests but failed one audio blocker assertion with empty stderr. The prepared row wrote a getter-only map wrapper property instead of model-owned `is_open`. The second [reviewed repair](fixture-repairs/map-owner/manifest.json) targets that owner, checks owner and wrapper projection, and adds diagnostic labels; its [application](fixture-repairs/map-owner/application.json) leaves runtime blockers and original assertions intact. Exact patches are beside their manifests. Original proposal README/status fields retain historical unapplied wording; the application receipts and focused-c result supersede that status.

The [review](review.json) maps all seven final canonical files to exact archived bytes and records the verified repair chain. Audio's final test is in `focused-c/inputs`; the passing remap test remains in `failed-focused-b/inputs`. The [manifest](manifest.json) inventories raw evidence and preserves both failure-manifest hashes.

Original prototype evidence stays in the existing [audio reproduction](../terminal-audio/README.md), [audio repair](../terminal-audio/repair/README.md), [remap menu/guide fit](../remap-guide-hints/README.md), and [tactical guide fit](../tactical-jump-copy/README.md) archives. Their source pins, failures and screenshots are not rewritten or duplicated. Dummy-audio lifetime and prepared native layouts do not establish audible comfort, physical controls, full-boot behavior or FPS for integrated source.

Only source, patches and diagnostic receipts/logs are included. No isolated profile, binary, cache or generated art is copied. Root owns the final repository handoff; this evidence archive authorizes no execution.
