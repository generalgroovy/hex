# H.E.X. full-roster pixel checkpoint

October 2, 2026. Ground/cast extension of the preserved three-character pilot.
Status: Full, native review and Windows packaging passed for this bounded local
checkpoint. Human visual/feel acceptance and complete action cycles remain open.

[Start the current candidate](../exports/hex-pixel-cast-20261002/windows/PLAY-HEX.cmd) ·
[Portable ZIP, 106.8 MiB](../exports/hex-pixel-cast-20261002/HEX-p56-ae223a7fae02-Windows-x64.zip) ·
[Playtest guide](HEX-PLAYTEST.md).

## Scope

| Area | Candidate implementation | Acceptance boundary |
|---|---|---|
| Roster | All30 current identities, using current names, ancestry and size | Old labels and affinities printed on style references are not authority |
| Style | New compact, charming pixel figures with primarily volume-based size differences | Small/Middle/Large calibrated to58/63/68px; gameplay stats unchanged |
| Ground actions | Idle, two painted walking contacts, neutral beats, sprint and rooted presentation | Some anatomical foot reversals remain unresolved; reversed phase has the same visible two-contact loop, not dedicated backpedaling |
| Casting | Empty-hand upper pose, same-facing independent foot frame | Limited pose bank, not a complete authored casting cycle |
| Facings | Eight stored headings; reviewed column swaps and separate rear corrections | Native review and human reading remain required, not inferred from file count |
| UI | New front head-and-shoulders portraits and new inspection sprites | The old upper-third crop cut off compact faces; Gallery inspection still does not implicitly Attune or change spells |
| Low/air/control actions | Existing working renderer retained | Still morphs some body parts; whole-animation replacement is NOT finished |
| Compactness | Four rows per1024x512 RGBA page; neutral beats reused by index |60MiB decoded new bank; old fallback textures also remain resident |

No movement, mana/stamina, chemistry, affinity, size-tier stats, hurtbox or wall
clearance rules change. The new bank requires exact catalog coverage, immutable
decoded pixel hashes, safe paths, fixed cell geometry and a common foot pivot.
Incomplete or corrupted banks fail admission as a whole; no partial activation.

## Repeatable art pipeline

Current identities come from `content/champions/foundation_champions_v1.json`.
The workbench preserves generator originals, exact prompts, references, source
receipts and reviewed `assembly.json` recipes. Alpha thresholding removes hidden
background RGB and low-alpha matte fringe. Assembly only extracts, uniformly
scales a sheet, registers feet and packs pixels; it never invents missing limbs
or bakes the old deformed mesh into purported new artwork.

Run `python -B art_batches/pixel_cast_v1/build.py`; `--available` is for partial
authoring review and never writes an incomplete runtime manifest. Use
`--pixel-cast` to opt into the new bank. The previous `--pixel-body-pilot` remains
available. The renderer does no per-frame image processing or resource loading.

## Fresh validation

Candidate source identity: `p56-ae223a7fae02`.

| Gate | Fresh result |
|---|---|
| Final structural assembly |30 identities,960 populated registered cells; one Python structural test passed |
| Focused source |3 suites /467707 assertions /0 failures /0 stderr bytes |
| Native presenter |30 final boards /1920 checks;26 unchanged images plus4 corrected images independently reviewed |
| Ordinary UI |Final frozen-source51 checks /11 captures passed, including Gallery, Attune, rebinding, assignment and paid casts |
| Full regression |175 suites /1,926,981 assertions;0 failures/stderr; import, source identity and configured120Hz boot passed |
| In-map motion |45 frames across Grace Riva, Jan Wicked and Fluup; ordinary paid casts and walk/sprint fixtures, not physical input or timing acceptance |
| Windows export and exact-package art comparison |Native launch/admission/safe-close passed; all30 exported board PNGs match final source by SHA256 |

Source SHA256: `ae223a7fae02bf415853a6cbc4f95f0a035d406af2acc3f25f279ea3829a1aba`.
PCK SHA256: `146985319665d846fb83f4666054ade7b86bbf4ff7c6010aaf52586560c2d500`.
ZIP SHA256: `a06d4c9bd280f07a536b4441292234f0a5ad2709143decd8502ba0f9e4936671`.
No commit, push, publication, installer or historical checkpoint-pointer promotion.

Failed attempts and source quality flags remain preserved; they are not
acceptance. [Compact evidence index](pixel-cast-evidence-20261002/README.md).

This visual slice does not certify dense120Hz, rendered FPS, physical input,
remote friend play, an installer/update path, or human visual/gameplay quality.
Those existing gates remain separate, including the failed dense120Hz and
unresolved internet networking dependencies.

## Review findings to carry forward

| Finding | Disposition |
|---|---|
| Spai Si, Leaf, Don Doko Don, Haara, Sai, Dr. Apex and Urzh rear quarters were reversed | Reviewed extraction mappings swap source columns3/5 without altering pixels; Dr. Apex/Urzh were found in native review |
| Jan Wicked cast-only rear quarters reversed | Cast row mapping corrected; other rows unchanged |
| Biggy Bob, Oll' I and Ha Rekt had weak rear views | Separately drawn rear strips replace those two columns; originals retained |
| Grimm Bow and Ba Djoh had near-duplicate rear diagonals | New strips establish opposing shoulder/cast directions; idle heads remain near straight-back and rear foot opposition still needs authored correction |
| Luuh I Zeh rear torso was front-facing under a back-facing head | Final correction has real rear armor/spine/appendage roots; slimmer rear volume, tiny head-edge marks and repeated rear foot remain open art issues |
| Faab had alarming colored matte fragments in source preview | They were low-alpha RGB; registered output reviewed clean after alpha thresholding |
| Wide Treevor/Grimm casting hands met nominal crop edges | Larger empty gutters and connected-character isolation preserve complete hands |
| Grace/Haara/Juul and some rear/profile contacts do not convincingly alternate | Explicitly unfinished footwork; human playback feedback and focused redraws required |
| Empty but correctly hashed cell could become invisible at runtime | Required-cell admission and defensive portrait guards now fail closed before publication |
| Old upper-third portraits clipped compact faces below the eyes | Full-cast portraits use a proportional nearest-fit upper-half crop; actual Gallery review confirms complete faces; prior bank's crop is unchanged |
| Reversed four-beat gait was described too strongly | Two contacts plus shared neutral beats are visually symmetric; backward-specific art remains incomplete |

Three disjoint artists produced source art. A separate bounded code review
identified the blank-cell and backpedal issues. Static cross-review found no
additional missing-parts or gross scale-jump blocker in the eight Small sheets
other than the separately flagged Luuh work. That review is not runtime or
human acceptance.

## Next feedback-gated work

| Order | Small slice | Acceptance |
|---|---|---|
| 1 | Correct passing/contact poses and explicit backward/sidestep choreography | Clearly alternating anatomical legs at native game scale; do not accept merely different pixels |
| 2 | Authored low/air/control poses, Small then Middle then Large | Slide direction follows travel; jump/roll/flight remain recognizable; stable skull/feet and cast compatibility |
| 3 | Reuse approved poses across identities with reviewed costume/anatomy correction | No blank state, detached cape/tail, scale jump or hidden fallback; Full/native/package gate repeated |

Internet friend-play and dense120Hz remain separate measured dependencies in
the single implementation queue; this art checkpoint does not clear them.
