# H.E.X. comprehensive implementation — 12 October 2026

Status: implementation, independent review, clean Full and local portable delivery
complete for **p60-845f85b5253e**, 3,436 production records. Performance acceptance remains open.
The twenty-point audit was implemented by gameplay, experience and technical
specialists with independent review and root integration. The preserved
`p60-d8e6ea1cd808` portable remains the previous qualified build. Its Full and
performance receipts do not qualify this changed source.

The [single queue](../../.agent/OVERHAUL-IMPLEMENTATION.md) owns remaining product acceptance;
the [resume](../../.agent/HEX-RESUME.md) owns exact build and package identities.
No new commit, push, merge or publication is part of this implementation pass.
Personal profiles, original art, previous packages and useful failed probes are
preserved.

## Player-facing changes

- One spell inspector supplies actual cost, preparation, cooldown, hit/shared
  pool and field-counter information to the Loom and Range. Equipped comparison
  is optional and explicitly distinguishes quoted damage from sustained output.
- Optional movement route advice explains a route's purpose and paid tradeoff.
  The three-rival signature path teaches Rapid gaps, Fuse exits and Rebound
  banks in real Conservatory, Tideglass and Basalt courts. Every rival remains
  selectable; ordinary combat produces victories and earned spells.
- A nearby Garden plot can become the Range's exact mixture preset. Optional
  Range setup exposes a moving target, finite paid return fire, three real hurt
  sizes and an observation-only statistics reset. Loaners and testing overrides
  remain separate from earned progress.
- Controls include independent movement and aim deadzones, optional remappable
  digital aim and 200% text reflow. Existing custom bindings remain intact.
  Compact menus pin selected identity and key facts; optional controls move into
  Options/Setup. The native matrix and independent visual review cover 200% text.
- Wall attachment and release use orientation-specific poses. Ground characters
  retain their tuck during aerial casting; flying characters keep their flight
  body while hands cast independently. Actual protection and vulnerable recovery
  remain visually distinct. These are extensions to existing reviewed assets,
  not a claim that every character now has a bespoke authored action sheet.
- A bounded local audio batch prioritizes damage and confirmed contact over cast
  chatter, coalesces duplicates and retains four voices without tail stealing.
- Signature persistence keeps a rolling validated last-good copy alongside the
  original immutable backup. Recovery is explicit, reports the recoverable
  records and preserves damaged primary files.
- Developer tools can record up to 60 seconds of ordinary offline commands and
  export a versioned current-world replay locally. Continuous cheats are rejected;
  out-of-tick world edits stop recording. Verification reports the first divergent
  tick and requires the trusted matching map and runtime identity.

## Engineering changes

The [technical ledger](technical.md) records measurement policy, retained campus
commands, terrain instrumentation and the bounded network capture experiment.
The [experience ledger](experience.md) records layout, animation, map and audio
changes and their transfer limits. The [gameplay ledger](gameplay.md) records paid
perks, all 63 composition roles, expanded balance scenarios and integrated lessons.

The opt-in `--retained-campus` experiment uses six ordered CanvasItems to retain
campus drawing only while their exact source,
view, focus, animation and terrain inputs remain valid. The original immediate
path remains available for identical-workload comparison. Paid ground, gameplay
actors and visibility remain live. Child draw work is timed separately from the
parent; a smaller parent draw timer alone cannot establish a speedup. Ordinary
launches retain the immediate renderer until a valid matched profile establishes
a benefit. The native attempts retained here failed foreground, viewport or
manual-start admission and cannot justify enabling the experiment by default.

The network matrix uses actual ENet loopback, two/eight players and deterministic
delay, jitter, unreliable-packet loss and outage recovery. It checks complete
world equality, predicted scalar equality, input acknowledgement, bounded history
and queues, and reconnect identity. This does not simulate physical Internet
latency or establish eight-player frame-rate acceptance.

CI retains bounded logs and receipts on failure as well as success, excluding
isolated user profiles. Full/Release retain the same complete test registry;
their supervision budget accommodates the expanded matrix. No GitHub CI run is
claimed until this source is actually pushed and executed there.

## Verification evidence

All engine jobs are serialized. Iterative raw logs are in
`.godot/wave-a-integration/`; they include useful failures and their repairs.
An assertion pass never overrides parser errors, stderr, missing coverage or an
unsuccessful checked runner.

| Gate | Latest established evidence | Limit |
|---|---|---|
| Retained drawing | 19 invalidation assertions and 40 native exact RGBA comparisons passed | Component first-frame cases; not all Bootstrap states or performance |
| Terrain | Actual bake produced 132 chunks plus overview; only manifest provenance differs from tracked image bytes | Decoding/upload stage timings still need a matched profile |
| Paid balance diagnostics | 142,770 assertions passed; all 504 spells and 63 compositions accounted for | Scenario correctness is not human balance acceptance |
| Network impairment | 34,192 focused assertions and 33,747 assertions in the final Full passed across eight two/eight-player cases | Injected loopback timing; delivered-packet counts vary, not Internet/FPS acceptance |
| Range and district journey | Range 1,426; map 1,202; joined tutorial/three-district progression 6,159; protected-contact feedback 1,899 assertions passed | Actual finite paid commands and persistence; not a human tutorial study |
| Replay and persistence | Current-world replay 356; recording 104; rolling recovery 68 assertions passed | Local deterministic verification and failure fixtures |
| Native motion | Seven trajectories at 60 samples/s and seven reduced-effect trajectories at 30 samples/s, four identities each | Timer/render coupling; no physical-input or human-feel claim |
| Native reading layouts | Final 196-frame matrix passed pointer/authority gates; performance/UI 16,415 and spell-testing 58,094 assertions passed | 16 views, two sizes, three text scales, two prompt devices plus four actual Back Options captures; physical controller acceptance remains separate |
| Garden teaching repair | 76,742 assertions, no failures or stderr | Explicit paid damaging hit requirement restored; all original layout and isolation checks retained |
| Final Full and portable | Frozen 845f candidate; clean Full passed 260 suites / 7,331,212 assertions / zero failures or stderr, including import/identity and 120 Hz boot; fresh export and standalone delivery passed | Previous d8 receipts remain historical; no installer or publication claim |
| Exported terrain | 2,062 checks; 132 chunks plus overview decoded exactly from an isolated mounted copy of the exported PCK, empty stderr | Resource integrity, not loading performance |
| Portable lifecycle | Five sequential normal-close/reopen cases passed; both paid cases admitted twelve casts with zero refusals; same isolated preferences and unchanged package bytes | No foreground/FPS, physical input or earned-progression claim |

The first native reading matrix exposed poor 200% information density despite
passing structural checks. The repaired layout keeps the selected identity and
cost/timing visible; independent review also caught and fixed a compact Setup
keyboard/controller action that previously dispatched Refill. A later capture
failure came from the fixture assuming Setup forgot its selected page; the
fixture now follows actual visible navigation. Failed runs remain preserved.

The first final Full on 549a exposed a real teaching omission: the Garden notice
had lost its explicit explanation that actor statuses require paid damaging hits.
That explanation is restored alongside the selected-mixture Range route. Tests
independently retain the harmless-ground, live-spell, status and handoff clauses
at both viewport scales. Independent review and the focused Garden gate passed;
the [failed first Full](full-first-failed.json) is preserved, and the replacement
Full ran against the corrected 85b1 identity.

That [second Full](full-second-failed.json) completed all 260 suites and
7,217,428 assertions, exposing 636 failed assertions across nine suites. The
causes were obsolete no-hands animation expectations, corrupted Unicode unbound
markers, a navigation expectation predating digital aim actions, and shared
spell-stat formatting. Four independently reviewed repairs preserve the original
body geometry and all 504 independent spell-metric expectations, validate exact
hand strips and expiry, restore labels, and convert summed integer ticks once.
The [13-suite repair gate](final-repair-focused.json) passed 1,967,421 assertions
with zero failures and stderr.

A refreshed 196-frame capture then exposed two human-visible clarity issues
despite passing structural checks: a clipped aim label and unnamed spell
comparisons in the wider layout. The reviewed repair keeps Aim cue within its
button, pins the selected spell name and starts comparisons with both identities.
The 845f source includes these corrections. The [final four-suite UI gate](final-ui-focused.json)
passed 185,185 assertions with empty stderr, and the [final native receipt](readable-ui-delivery-final.json)
contains 196 frames, 68 at 200%, no failed routes and unchanged authority. Root
and both specialists visually confirmed the repaired samples. The replacement
[Full](full-final.json) passed all 260 suites and 7,331,212 assertions with zero
failures/stderr in `.godot/windows-tests/18b42abf09814ca6ac5307595d7d50c1`.
Import, runtime identity and 120 Hz boot also passed. The final package and its
separate delivery checks passed as recorded below.

A network capture size-witness experiment preserved exact packet bytes but
showed no reliable timing benefit. Its production changes were reverted; only
the benchmark and evidence are retained. It is not a delivered optimization.

Two actual d8 portable measurement attempts are retained below. Both executed
their paid workload and closed normally, but failed foreground admission. The
second included one explicit native foreground request. Neither qualifies a
before/after speedup claim. The user agreed to keep the final test window in front.
Subsequent source runs failed independent foreground admission, a changed viewport
or the manual Start deadline. They remain failed evidence; sustained-performance
acceptance is open.

- [Initial failed foreground baseline](baseline-d8-window-gated/measurement.json)
- [Explicit foreground-request baseline](baseline-d8-foreground/measurement.json)

## Delivered local candidate

The [delivery summary](delivery-summary.json) binds the eight final receipts and
their hashes to the exact local candidate.

Open [PLAY-HEX.cmd](../../exports/hex-comprehensive-20261012/windows/PLAY-HEX.cmd),
or extract the complete [Windows ZIP](../../exports/hex-comprehensive-20261012/HEX-p60-845f85b5253e-Windows-x64.zip)
into its own folder. The archive is 161,146,185 bytes (153.7 MiB). The tested
launcher selects the full-roster pixel presentation. No installation or
administrator permission is required. The previous d8 portable is preserved.

| Artifact | SHA-256 |
|---|---|
| Runtime source | `845f85b5253ed6f3138acb7de50756533a0f396fb180bd4a9b7d068f44005b5b` |
| ZIP | `e25f8e3e5abbf0c3a678b66b2ef1aa51b3f16a5f7de8996dfc8679f287e30539` |
| PCK | `7f0fc2057bfd024651500b14f12a8b810662ba3c8188b7133f01f8f8d0d8d2bc` |

The [package receipt](package.json) records export, exact identity, thirty-character
presentation admission and native safe close. [Standalone delivery](delivery-files.json)
verified all ten payload files and unique ZIP members, launcher instructions and
the unchanged fallback PCK/ZIP. [Terrain decoding](terrain-pack.json) and its
[mount provenance](terrain-pack-provenance.json) verify all 133 images without
checkout resource fallback.

The [final lifecycle receipt](portable-lifecycle.json) covers Hearth, Garden, paid
Fire, paid all-six Mantle and reopening, using one fresh isolated profile. Every
case closed through the owned window with zero warnings/stderr. Both paid cases
admitted twelve casts with zero refusals. Preferences remained byte-identical
across all five cases; the executable, PCK and both identity documents were unchanged.
Caller APPDATA was restored. This does not establish foreground admission, frame
pacing, physical input, learned-progression persistence or UI recovery/replay export.
Those behaviors retain their separate evidence and acceptance limits.

Two useful harness failures remain: the [hidden-window attempt](portable-lifecycle-hidden-failed.json)
could not deliver a normal close, and the [first visible attempt](portable-lifecycle-parser-failed.json)
encountered a parser assumption that all logged events carry a spell ID. The
reviewed helper now requests a visible window and requires a spell ID only for
cast outcomes, retaining all strict success gates. The clean replacement ran all
five cases from the beginning. No game or package files changed for these repairs.

## Design basis and acceptance

The techniques follow established examples with explicit transfer limits:
Riot's workload-specific profiling and clarity hierarchy, Godot's retained draw
commands, Titanfall's readable movement/geometry relationship, Apex's configurable
Range, Gungeon's visible attack and recovery patterns, Magicka/Noita's compositional
experimentation and Mega Man's defeated-rival weapon learning. Linked primary
sources and the exact H.E.X. application live in the specialist ledgers. Numerical
balance, control rules and authored content remain H.E.X. decisions tested in its
own context; another game's success does not prove this implementation is fun.

Human feel, listening, wayfinding, physical controllers, two-PC/Internet behavior
and sustained presented-frame smoothness remain distinct acceptance questions.
Complete bespoke animation cycles and a campaign beyond the three district lessons
remain unfinished. The 63-composition audit reveals equivalent roles rather than
claiming all recipes are mechanically unique; prepared passive probes do not prove
natural usefulness or fairness. This delivery makes no promise of perfect performance.
