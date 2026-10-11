# Native movement and impact review — 2026-10-09

Status: **PASS for the ten controlled native-renderer samples; LIMITED for gameplay/readability acceptance.** No missing-renderer, wrong-element, incorrect disclosed radius, or essential-budget disappearance was observed in these samples. Every PNG was opened and inspected individually, rather than inferred from a contact sheet or receipt alone. No production source or asset was changed by this review.

## Exact evidence

- Capture: `.godot/movement-impact-native-reference-20261009-v2/receipt.json`.
- Receipt SHA-256: `4e75fd618f335defd5603059e21fa5f9c95e7ae507a550159d12b5933601e47a`.
- Receipt reports native Windows rendering, 1280 × 960 pixels, ten PNGs, 1,445,717 PNG bytes, and no image resizing. Flight samples use 0.75 world zoom; contact samples use 1×; floor samples explicitly show 1× and 2× detail.
- Independent post-capture hash comparison matched all ten PNGs and all 28 receipt-listed source/assets to the current files. All 270 recorded samples have `authority_unchanged: true`; this checks the controlled renderer inputs only.
- Nine sheets contain 24 element/family combinations and five floor-contact samples each. The separate Heavy sheet contains nine aftermath samples. Ages 0, 6 and 48 correspond to 0, 0.05 and 0.4 seconds at 120 Hz; the Heavy sheet uses ages 0, 12 and 30.
- The initial capture attempt timed out according to root's execution report. It is retained as failed evidence, not counted among these ten images. The v2 harness renders its offscreen viewport after two process frames with `RenderingServer.force_draw(false)`; it does not wait on the minimized root's `frame_post_draw` event.

## Individual image inspection

All image paths below are inside `.godot/movement-impact-native-reference-20261009-v2/`.

| Image | Verdict within capture scope | Visible observation and limit |
| --- | --- | --- |
| `normal-age-00.png` | PASS | All eight element rows and all three projectile families render. Rapid remains the small family; full-strength Bolt and Heavy cores are larger than their strength-one cores. Fire, Water, Ice, Charge, Light, Dark, Earth and Wind retain distinct palettes and contact artwork. Native floor marks are small and subdued, so this is not proof that players notice them in motion. |
| `normal-age-06.png` | PASS | Contact artwork develops into its next sampled phase while the element/family mapping stays consistent. Heavy damage-contact emphasis is visibly stronger than Rapid. The larger cosmetic contact shapes are not presented as the actual radial attack extent; the sheet explicitly labels that distinction. |
| `normal-age-48.png` | PASS | Later contact fragments remain visible. Landing marks have ended while the separately configured slide/wavedash marks remain. This is a sampled later frame, not evidence of smooth interpolation or frame pacing between ages. |
| `reduced-age-00.png` | PASS | Reduced artwork retains all element rows, projectile cores, contact centers and the family size hierarchy. Ground contacts retain their essential marks with less surrounding detail. |
| `reduced-age-06.png` | PASS | The reduced contact phase is visibly simpler than the matching normal frame while retaining element identity and the primary contact mark. Native floor cues remain subtle. |
| `reduced-age-48.png` | PASS | Fewer late fragments remain than in normal mode. No family or element is absent from the controlled samples; the diminished late detail is consistent with the reduced mode. |
| `zero-budget-age-00.png` | PASS | With all 192 optional decoration slots consumed, projectile cores and element contacts remain. Optional landing dust disappears while small essential floor marks remain. Their small 1× footprint limits readability conclusions. |
| `zero-budget-age-06.png` | PASS | Essential contact artwork survives the exhausted shared budget at the second sampled age. Ground cues retain their core marks without the normal landing dust. |
| `zero-budget-age-48.png` | PASS | Later contact fragments and the independently configured skid marks remain after budget exhaustion; expired landing marks do not reappear. This does not measure performance under a real 192-decoration combat load. |
| `heavy-aftermath-authoritative-radius.png` | PASS; LIMITED for boundary readability | The broken outer boundary preserves the disclosed 120px radius at 1× in normal, reduced and exhausted-budget rows. Central Fire artwork changes separately across ages 0, 12 and 30. The late boundary is very faint on the dark background, so recognizing it amid live terrain or effects is not established. |

## What this qualifies

**PASS:** the native capture produced complete, readable comparison boards without an observed viewport-edge truncation; live compiled radii/speeds/damage/strength are displayed; normal/reduced samples preserve the projectile-family hierarchy; essential marks remain when optional decoration is exhausted; the controlled renderer did not mutate its recorded authoritative inputs. The Heavy aftermath model and the printed comparison both use the current 120px radius.

**LIMITED:** one-power Rapid marks and native floor marks occupy only a few pixels. Several late fragments and Heavy radius dots are low contrast. Labels help this comparison board, whereas a played match adds terrain, actors and simultaneous effects. These observations identify the limits of this artifact, not a demonstrated live readability failure. Color vision accessibility, readability on other displays, and noticeability under divided attention remain untested.

**LIMITED:** the Heavy sheet uses the existing `HeavyBlastPresenter` with a controlled legacy deposit in an empty collision world. It is an already-resolved aftermath rendering, not a live Hex damage execution, wall-occlusion test, anticipatory hazard telegraph, or proof of the physical blast boundary. Collision and damage claims belong to the independent simulation tests.

**LIMITED:** these sheets do not execute player movement, casting, collision, multiplayer synchronization or physical input. They contain no continuous playback, performance measurement or human feel assessment. The three ages cannot establish animation smoothness, input responsiveness, temporal readability, or fun. They also do not prove that every aspect of the game is optimized or that a cited established-game technique improves this game's outcomes.

**FAIL:** none observed within the narrow rendering criteria above. The failed original capture remains a capture-harness failure and is not converted into a visual pass.

## Independent fixture review

Reviewed the movement agent's deltas to `tests/unit/test_champion_catalog.gd` and `tests/unit/test_pov_presentation.gd` against `.godot/reference-refinement-baseline/movement/` without running an engine. No blocker was found in the changes: the catalog now separates stationary base Flux recovery from S. Wayne's active walking/low-Flux recovery, using the independently specified 1150 factor per quiet-curve tick; the POV fixture places its occluder on the current 45-degree upper spoke, directly proves the upper ray hidden and lower ray visible, and preserves the unchanged event-cache/authority assertions. An adjacent startup-wait assumption was separately reported to the owning agent/root for investigation; it was not silently changed or treated as part of visual acceptance.
