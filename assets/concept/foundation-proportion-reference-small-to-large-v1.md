# Foundation body-template proportion reference v1

This non-runtime concept board fixes the redesign order and anatomy target for
the first three reusable champion body templates:

| Order | Template | Exemplar | Runtime height | Silhouette purpose |
|---:|---|---|---:|---|
| 1 | `small` | S. Wayne | 58 px | Short, compact and low-centred without childlike anatomy |
| 2 | `middle` | Oh Tipi | 68 px | Balanced torso and clearly separated limbs |
| 3 | `large` | The Red Baron | 76 px | Broad, heavy mass at the same feet pivot |

All three use the Red Baron's mature compact body grammar: the ordinary head
or skull is visibly smaller than the torso and legs. Hair, fin crowns, horns and
other ancestry silhouette features do not count as cranium size. The templates
must remain different sizes and shapes, use runtime scale `1.0`, align to pivot
`(48,84)`, and never move collision or gameplay authority into presentation.

`foundation-proportion-reference-small-to-large-v1.png` was generated with the
built-in ImageGen tool as a design reference from the active v11 runtime atlas
and `red-baron-eight-direction-source-v1.png`. It is an opaque RGB image with a
baked checkerboard and therefore MUST NOT be imported as a runtime sprite. Its
SHA-256 is
`c6ccbe9d9db8168fe01488e6c9bb0fc1e177f635fea28fae7bfc6c186a4d4759`.

## Generation prompt

```text
Use case: precise-object-edit
Asset type: production proportion reference for FLUX top-down character sprites
Input images: Image 1 is the exact current runtime identity, palette, clothing, ancestry and pixel-cluster reference for S. Wayne, Oh Tipi and The Red Baron; Image 2 is the exact Red Baron anatomy/material reference.
Primary request: create a NEW genuinely transparent three-character front-facing proportion board in strict smallest-to-largest order: LEFT S. Wayne (small hobbit), CENTER Oh Tipi (middle seakin), RIGHT The Red Baron (large undead). Preserve each identity, palette, outfit, empty hands and ancestry features. Rebuild all three with one mature compact anatomy grammar led by Red Baron: ordinary head/skull excluding ancestry crest/horns is visibly smaller than the torso-plus-legs, about one quarter of total body height; shoulders and torso read clearly; limbs are longer and natural; no baby/chibi proportions. Keep S. Wayne visibly shortest, Oh Tipi taller/balanced, Red Baron equally tall but substantially broader/heavier.
Style/medium: original charming compact cartoon pixel art, crisp economical clusters, nearest-neighbor appearance, gameplay-readable at roughly 58/68/68 pixels tall after reduction.
Composition/framing: exactly three isolated full-body south/front grounded poses, one horizontal row, aligned feet, generous transparent separation.
Constraints: body and clothing only; genuinely transparent background; empty hands; no magic, aura, projectile, shadow, environment, text, labels, borders, weapons, staffs, wands, tools, detached objects, watermark; non-sexualized; no palette or identity replacement.
Avoid: oversized heads, child/baby/chibi anatomy, copying Red Baron's skull/crown/cape onto the other champions, wrong size order, cropped figures, extra characters.
```

The generator returned an opaque checkerboard despite the transparency request;
the runtime atlas remains deterministic repository-built art. Subsequent live
review increased the large runtime template from the prompt's 68 px to 76 px;
the table above is the authoritative production contract while the prompt stays
verbatim provenance.
