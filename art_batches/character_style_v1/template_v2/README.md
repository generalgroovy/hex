# Basic size-template production v2

**Active scope: generic body templates only.** The user's latest gate requires
satisfactory Small, Middle and Large base templates before character-specific
repairs or additions resume. Tooling availability is not permission to start named
character generation, and no automatic mass-generation loop is allowed.

After that gate, the new [user-supplied cast sheet](../../../reference/art/cast_style_post_templates_v1/README.md)
is the primary later character-look target. Its hash and activation condition are
recorded in `contract.json.post_template_character_style`; current neutral
construction continues unchanged. Complete animation playback, not merely80 filled
cells, is required before using the new look on named characters.

This is the current offline production front door, not another renderer. Reuse
the existing character assembler, native QA viewer and runtime override seam.
Neutral sources under `reference/art/neutral_body_templates_v1` are unfinished
historical fixtures, not approved Small/Middle/Large art. No new live character
or complete neutral pack is claimed by adding this contract.

| Shared resource | Rule |
|---|---|
| Size guides | Small58 → Middle68 → Large76; same96px cell and48/84 foot pivot |
| Anatomy | Ordinary head20–23%, preserved torso/limb volume; no per-pose fitting |
| Eight headings | S0 / SE45 / E90 / NE135 / N180 / NW225 / W270 / SW315; diagonal chest/back overlap distinguishes neighbors |
| Construction unit | One heading ×10 actions/contacts in a2×5 board; at most two explicitly paired headings |
| Walk/sprint | A plants anatomical left, B plants anatomical right; opposing arm swings; no costume-mirror substitutes |
| Portrait | Automatic exact top third of occupied south-grounded bounds; full occupied width and ceil(height/3), fit32px |
| Identity additions | Deferred until the user accepts the basic size-template style/animation result |
| Compatibility | Same80 slots and semantic aliases; shared poses are not dedicated animations |

Start with the [contract](contract.json), [one-heading prompt](GENERATION-PROMPT.md)
and [review checklist](REVIEW-CHECKLIST.md). Accept a Small neutral heading/contact
pilot, complete its8-heading grammar, then inspect Middle and Large at their actual
pixel sizes. Do not assume downscaling alone preserves readable knees or faces.
Keep all current game characters unchanged during this phase. After the user's
basic-template acceptance, repair existing character directions/contacts, then
add remaining identities one fully reviewed page at a time. A failed pilot is a
held candidate, never a reason to mass-generate the cast.

## Current acceptance order and evidence

| Order | Required outcome | Current evidence boundary |
|---|---|---|
| 1. Small contact pilot | Genuine anatomical A/B support and arm alternation, readable rear-quarter heading, stable volume | [South v3](../template_small/south-pilot-v3/README.md) corrects opposite arm/leg contacts; three58px partial cells remain held for enclosed matte remnants; rear-quarter grammar remains unapproved |
| 2. Small complete grammar | All8 distinct headings and10 action/contact slots at58px, not just a good pair | Not a completed neutral runtime PNG |
| 3. Middle | The same usable grammar and stable proportions at68px | Construction guides only; no accepted neutral runtime PNG |
| 4. Large | The same usable grammar and stable proportions at76px | Construction guides only; no accepted neutral runtime PNG |
| 5. User visual acceptance | Basic size templates satisfactory together in game-scale review | Named character production remains gated until this acceptance |

Current `guides-v3/` and `contact-guides-v2/` are fixed-bone construction diagrams,
not neutral character sprites or finished animation atlases. Earlier `guides-v1/`,
`guides-v2/` and `contact-guides-v1/` remain rejected/superseded construction
evidence: v1 had front handedness errors; v2 still stretched/compressed limb chains
and drew a fixed near-side color. The current model uses rigid torso/head offsets,
fixed-length analytic two-bone legs/arms, one global scale and yaw-dependent
occlusion. In rear/profile views a farther planted foot can legitimately appear
higher on screen than a nearer passing foot: use its anatomical chain and actual
ground-height metadata, not the lowest screen pixel, to identify support.
The fourth art attempt,
`small-ne-guide-first-pair-v1.png`, is still a candidate, not an approved template.
The preceding `small-ne-pilot-v1.png`, `small-ne-pilot-v2-held.png` and
`small-ne-pair-v1-held.png` remain held. Passing finite-landmark or contact-sign
tests does not establish limb-length preservation, correct overlap or artwork.

The current shared assembler requires an actual `grounded/south` source even for
a partial review: it supplies the one body-scale reference. An isolated NE pair
cannot be assembled by inventing a South pose or a standing-height measurement.
The shared builder already supports explicit neutral identities
`template_small`/`template_middle`/`template_large`, with the same actual
South-reference, fixed58/68/76px scale and registration checks. The South v1/v3
partial reviews exercise this support; do not revive a parallel legacy producer.

## Deferred: start a canonical character batch

The scaffold command remains available for later use, **after the user's basic
template acceptance**. Do not begin named character art to bypass the current gate.

From the repository root, one command creates a fresh contained draft batch:

```powershell
.\scripts\new-character-art-batch.ps1 -ChampionId nico_lai
# Optional explicit NEW folder name; existing destinations are never overwritten.
.\scripts\new-character-art-batch.ps1 -ChampionId red_baron -BatchName directional-repair-v1
.\scripts\test-new-character-art-batch.ps1
```

All27 current technical IDs are supported. Retained `nico_lai` displays Waka Aren
Si and `donnok` displays Don Doko Don; planned renamed IDs are not silently guessed.
The command writes only14 draft files under a new
`art_batches/character_style_v1/<id>/<batch>/`: eight one-heading prompts, canonical
identity/body/affinity snapshot, contract snapshot, appearance worksheet,80-cell
source-layout scaffold,80 pending reviews and instructions. Unknown appearance,
source hashes, source calibration and crops remain explicitly pending/null.
These drafts intentionally cannot pass assembly or promotion until actual sources
and reviews exist. No artwork, live catalog, runtime registry or installer changes.
Paths with traversal/reparse points and existing destinations are rejected.

## Build, inspect, review, promote after the relevant gate

1. During the active phase, record a neutral body identity and immutable sources,
   prompt, explicit crops and a real South-grounded reference. Do not label
   code-rendered construction diagrams as accepted neutral artwork. Named
   canonical IDs become appropriate only after the user accepts the base templates.
2. Use `scripts/build_character_style_pack.gd` to assemble an isolated candidate.
   Its explicit neutral identities and named-character assembly both
   register actual occupied pixels after nearest downsampling. The old neutral
   importer is not the production command and must not be revived as a second path.
3. Use `scripts/review-character-sheet.ps1 -Sheet <PNG> -Mode Check` and `-Mode Export`.
   Native alpha/80 cells/baseline/hash differences are technical evidence only.
4. Copy [review-receipt.template.json](review-receipt.template.json) beside review
   evidence, replace its explicit placeholders and inspect all80 entries. The
   unfilled template intentionally does not validate. Candidate hash and evidence
   paths/hashes must identify the current artifacts; keep paths relative to the
   receipt directory. Reviewer kinds distinguish agent from human review.
5. Run the strict promotion check below. A valid held/pending receipt can be
   inspected with `-Inspect`, but is never promotion-ready. The command does not
   write a registry or disable existing live pages with no retrospective receipt.
6. A parent integration review must additionally run actual import/presenter,
   catalog/selection, in-game zoom and Full gates before changing a live registry.
   This receipt does not replace them or certify the user's visual acceptance.

```powershell
.\scripts\validate-character-art-review.ps1 -CandidatePath '.\art_batches\character_style_v1\<id>\candidate\<id>.png' -ReceiptPath '.\art_batches\character_style_v1\<id>\review\receipt.json' -AsJson
.\scripts\test-character-art-review.ps1
```

An approved receipt requires80 readable/stable cell decisions, the32 correct
locomotion contact/counter-swing attestations, and distinct hash-locked native
light/dark, gait-review, in-game and portrait evidence artifacts. Candidate or
evidence edits invalidate the receipt. This enforces explicit review integrity,
not automated visual understanding; never fabricate an `approved` attestation to
get a green tool result. The file format also supports the three neutral identities
`template_small`, `template_middle`, `template_large` for full guide pages.
