# Adding current FLUX visual assets

Status: **basic size templates only until the user accepts them**; named
character repairs/additions and full-cast production are deferred.

The current character path is the eight-direction, three-body pixel-art pipeline,
not the archived five-size v2 SVG generator. Rendering never owns gameplay state.
Use the [sprite pipeline](SPRITE-PIPELINE.md) and
[production contract](../art_batches/character_style_v1/template_v2/README.md).

| Add/change | Current source of truth | Smallest safe work unit |
|---|---|---|
| Basic neutral templates — active | Three-body contract and user style acceptance | Small58 first: real A/B pair, then8headings/10rows; repeat Middle68 and Large76 |
| Character identity | `content/champions/foundation_champions_v1.json` | One existing canonical ID and approved body/race profile |
| Character artwork after template acceptance | New post-template cast sheet + accepted three-body construction; original Oh Tipi supports detail | One heading x10 poses/contacts, then a complete80-cell candidate with reviewed playback |
| Race anatomy | Canonical roster/race design + character worksheet | Reviewed ears, face, hands, feet, tail/wings; preserve body class and empty hands |
| Character animation | Current80-slot grammar and shared presenter | Correct authored heading/contact cells; do not invent extra runtime states |
| Wellspring environment | Current [visual system](VISUAL-SYSTEM.md) and environment manifests | One modular worldbone/material asset with existing renderer integration |
| Magic/chemistry visuals | Current element/magic manifests and presentation contracts | One effect family driven by authoritative phase/geometry, separate from bodies |

## Active work: make the three basic templates satisfactory

Finish genuine Small contact alternation, unambiguous adjacent headings and stable
volume before expanding to its full8-direction grammar; then validate Middle and
Large at their own pixel sizes. The first three neutral art attempts were held;
the fourth guide-first pair remains unapproved. Current `guides-v3` and
`contact-guides-v2` are fixed-bone code-rendered construction diagrams; older v2
guides/v1 contact boards are superseded, not accepted neutral
runtime PNGs. Keep existing game characters playable and unchanged during this
acceptance phase. Named character work resumes only after user acceptance.

The shared character assembler requires a real `grounded/south` source for one
immutable body scale. It accepts canonical champion IDs and explicit
`neutral_body_template` identities `template_small`, `template_middle` and
`template_large` with matching sizes. This support is implemented, not future work;
a parallel old neutral producer or fake South-reference pose is not a shortcut.

## Deferred: add or repair a character after basic-template acceptance

After that user gate, start with `scripts/new-character-art-batch.ps1 -ChampionId <current_technical_id>`
to create a new contained batch with eight heading prompts and all80 pending
source/review cells. It reads canonical size, race, name and affinities; appearance
remains pending approved-reference review. It never generates pixels or changes
the game. An optional `-BatchName <new-slug>` is refused if the destination exists.

Use the [post-template cast look](../reference/art/cast_style_post_templates_v1/README.md)
only now, over the accepted general templates. The supplied image is styling
reference, not a source for automatic roster, race, affinity or equipment changes.

1. Copy [the champion worksheet](../art/templates/champion_profile_v2.json) as
   an **offline design worksheet**, not a runtime catalog entry. Its filename is
   retained for existing links; its fields now describe the current three sizes.
2. Resolve the stable canonical identity, race and `small`/`middle`/`large` body.
   A worksheet does not approve a new race, change stats or add a character itself.
3. Reuse the accepted size/direction/contact construction guides. The first
   production acceptance proceeds Small58, Middle68, Large76. Incomplete neutral
   reference sources are not finished templates and must not be silently reused.
4. Generate one heading board at a time using the
   [current prompt](../art_batches/character_style_v1/template_v2/GENERATION-PROMPT.md).
   Preserve distinctive anatomy/clothing and the same body volume in every pose.
5. Assemble explicit source crops with `scripts/build_character_style_pack.gd`
   into an isolated candidate. Keep immutable sources, exact masks and page-wide
   calibration. No per-pose resize, weapon, spell, aura or shadow in body pixels.
6. Inspect all80 cells at native and gameplay zooms. Walk/sprint A and B must
   visibly exchange anatomical planted legs and counter-swinging arms; front,
   diagonal and profile views must remain distinguishable without labels.
7. Complete the exact-hash review receipt and run its strict validator. Pending
   or held direction/contact cells block **new** promotion. This does not disable
   an existing working page while its replacement is being repaired.
8. After native QA, source/import, presenter/catalog/Gallery, in-game captures
   and Full gates pass, integrate one complete identity through the existing
   override registry. Source/playtest acceptance, user approval and installer
   publication are separate milestones.

```powershell
.\scripts\review-character-sheet.ps1 -Sheet '<candidate.png>' -Mode Check
.\scripts\review-character-sheet.ps1 -Sheet '<candidate.png>' -Mode Export
.\scripts\validate-character-art-review.ps1 -CandidatePath '<candidate.png>' -ReceiptPath '<review-receipt.json>' -AsJson
.\scripts\test-character-art-review.ps1
```

## Shared construction, unique identities

The [race worksheet](../art/templates/race_profile_v2.json) describes anatomy,
palette and silhouette cues without creating another runtime skeleton. There are
exactly three body sizes, the same96px cell/48,84 foot pivot, eight headings and
ten action/contact rows. Distinct size-specific hurtboxes and a shared wall
clearance are simulation data, never inferred from artwork. Anatomy can extend a
silhouette without changing collision, reach, movement, damage or field geometry.

Portraits use exactly the upper third of the occupied south-grounded model bounds:
full occupied width and ceil(height/3), fitted into a transparent32px portrait.
No separate hand-authored portrait or full-body miniature is required.

## Scope and acceptance

No five-size workflow,25-animation coverage or archived generator output is
implied by this guide. Current single-pose action aliases remain honestly labeled;
two contacts are not a complete multi-frame roll or walk animation. Hash/packing
tests cannot certify anatomy, heading clarity, alternating feet or human feel.
Keep good live resources until replacements pass the relevant acceptance gates.
