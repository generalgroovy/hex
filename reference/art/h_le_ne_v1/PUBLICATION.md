# Cast additions: publication checkpoint

Status: locally verified source checkpoint prepared for the user-authorized repository push.

H. Le-ne is a female Stoneborn, Middle (medium), with Earth 1 / Wind 1 / Fire 1.
Fimu Yashiha is a female Treefolk, Small, with Water 1 / Fire 1 / Light 1.
The two selected v2 portraits are separate files in their respective folders.
Both are registered playable baselines using existing same-size stats and shared
spells, with stable new wires 28 and 29. Existing wires and character profiles
remain intact. The current cast is 29 playable identities plus one reserved Angel.

The repository branch is `codex/character-roster-portraits`. Publication includes
the complete current source and required art/reference/evidence checkpoint because
the preceding cast and game systems were still uncommitted in this checkout. It
does not claim that the entire checkpoint was created by this portrait request.
The isolated publication index preserves the original checkout and ordinary index.

Full validation passed: **95 suites, 545,249 assertions, zero failures, zero
stderr bytes**, with asset/current-state checks, editor import and a 120 Hz game
startup. Runtime body rendering still uses the existing shared size templates;
portrait acceptance is not animation or individual-balance acceptance.

The first full run exposed two test-only integer/float dictionary comparisons in
the new affinity assertions; those comparisons were corrected to compare integer
values per element, followed by the complete passing rerun.

Evidence: [full receipt](cast-additions-full-receipt.json),
[full suite output](cast-additions-full-suite.log),
[120 Hz startup](cast-additions-boot-120.log).

The push result and exact remote commit are confirmed separately in the chat
after upload. This note is prepared before the commit, so it does not fabricate a
post-push result or a new executable release.
