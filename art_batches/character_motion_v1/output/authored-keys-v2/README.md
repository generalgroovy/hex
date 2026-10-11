# Three additional authored action-key sets

This candidate contains **Wa Bidi, Jan Wicked and Fluup only**. The three earlier pilots and their recipes were not changed.

| Character | Estimated source cranium, first front key | Uniform sheet scale | Target cranium |
|---|---|---|---|
| Wa Bidi | Crown y98 to chin y137: 39 px | 0.4615384615 | 18 px |
| Jan Wicked | Crown y76 to chin y111: 35 px | 0.5142857143 | 18 px |
| Fluup | Crown y86 to chin y124: 38 px | 0.4736842105 | 18 px |

**Confidence is low:** hair obscures the actual skull crown. These are explicit reviewed visual estimates, not alpha-bound-derived measurements or a claim that skull anatomy was perfectly recovered. See `source-first-front-measurement-review.png` for enlarged copies of the untouched first-front sources with original y coordinates.

Each character has 64 individually authored key poses: eight action rows × eight directional views. Each atlas is 1024×1024 RGBA, with 128×128 cells and a provisional support pivot at 64,104. One uniform scale applies to every pose; no pose was fitted back to standing height.

Rows: slide entry, slide hold, roll anticipation, roll tuck, jumpsquat, jump rise, fall and land. Direction columns: S, SE, E, NE, N, NW, W, SW.

- `three-new-characters-action-keys.png`: all 192 keys.
- `three-new-characters-front-actions-native.png`: native-pixel front action comparison, without shrinking sprites.
- `manifest.json`: exact atlas/recipe/source hashes and frame records.
- `registration-receipt.json`: measurements, limitations and fresh 192-cell reassembly evidence.
- `verify-registered.py`: independently reassemble all keys, enforce exact source-pixel ownership and compare each saved atlas cell.

These are **key poses, not complete animation cycles**. Native engine validation has not been run by the registration worker. Front/quarter-facing distinctions and some jumpsquat silhouettes still need visual acceptance; airborne support placement is provisional and does not encode the actual game jump trajectory. No gameplay integration or production promotion occurred.
