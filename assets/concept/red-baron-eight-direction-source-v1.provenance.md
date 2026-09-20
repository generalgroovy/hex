# Red Baron eight-direction source v1

| Field | Value |
| --- | --- |
| Role | Editable body/clothing concept source for the first canonical `large` champion |
| Generator | OpenAI ImageGen through the built-in Codex image workflow |
| Generated source | `C:\Users\sende\.codex\generated_images\019f9fd1-1c85-71c0-a13f-166bc8195a9c\exec-022e9535-e10d-4c67-ba8f-0685ea819b4a.png` |
| Repository source | `assets/concept/red-baron-eight-direction-source-v1.png` |
| Dimensions | 2172×724 RGBA |
| Source SHA-256 | `4ab2294982f6ac2c7793907689504909d51ae9674b71989779c60b67dde34d73` |
| Runtime status | Source only; deterministic tooling derives the reviewed 96 px body atlas |
| License/originality | Original generated FLUX production source; no external game pixels or protected assets are included |

Prompt summary: create an original compact cartoon pixel-art Undead champion in
the fixed `S/SE/E/NE/N/NW/W/SW` order, with a broad large-body silhouette,
oversized skull, dark cape, crimson tabard, aged-brass clasps, and open empty
hands. Body and clothing only; exclude weapons, casting foci, spells, elements,
auras, shadows, environment, text, UI, and frame borders. The current FLUX
foundation atlas and the repository's legacy Red Baron direction preview were
used only as broad proportion and identity references.

Deterministic promotion command:

```powershell
python scripts/build_red_baron_foundation_atlas.py `
  assets/sprites/champions_v3/foundation/runtime_atlas_eight_v8.png `
  assets/concept/red-baron-eight-direction-source-v1.png `
  assets/sprites/champions_v3/foundation/runtime_atlas_eight_v9.png
```
