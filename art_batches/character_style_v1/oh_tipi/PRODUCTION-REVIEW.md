# Oh Tipi complete-page production review

Status: complete v5-registration page is active in source; human animation acceptance remains open.

The authoritative Seakin reference supplies identity and body/clothing design;
the source's staff is deliberately excluded. Gameplay, geometry and timings are
unchanged. Immutable generated originals and every assembly/removal record stay
beside the candidate.

| Candidate | Review decision |
|---|---|
| Full page v1 | Rejected: north action rows repeated idle and contact poses were weak. |
| Full page v2 / assembly v3 | Improved identity and actions; rejected front sprint direction and excessive north gait bob. |
| 32-cell gait board v1 | Not assembled: insufficient opposite-foot clarity. |
| Front/back gait board v1 | Used after exact alpha cleanup and source-wide anatomical calibration. |
| Assembly v4 | Complete 80-cell source-playtest candidate; all rows and contacts reviewed at native/2x scale. |
| Assembly v5-registration | Rebuilt with actual post-resize foot registration; pixels match v4 exactly; promoted only for Oh Tipi. |

## Reproducibility and limitations

`full-layout-v4.json` combines 72 full-page-v2 poses and eight front/back gait
slots. Seven new source poses fill those eight slots: south sprint B explicitly
reuses the corrected south walk B contact. It is not claimed as independent art.
All other directions retain the complete v2 page's poses.

`clean_ns_alpha.gd` applies the already-authorized deterministic cleanup to the
RGBA source: alpha below 128 becomes zero, all retained alpha becomes 255, and
RGB is unchanged. The original, exact removed/snapped-pixel mask and audit JSON
are preserved. No anatomy, poses or intermediate frames are synthesized in code.

Every front/back correction uses the same source-wide anatomical calibration
(`reference_cell_width=366.08`, measured relative to the 132px original page
and 416/150 source body ratio). It is not per-pose fitting. The assembler uses
nearest-neighbor sampling and fixed 48/84 bottom-center registration.

| Evidence | Result |
|---|---|
| Runtime PNG | `full-candidate-v5-registration/oh_tipi.png`, copied exactly to `assets/sprites/champions_v3/style_v1/oh-tipi-v1.png` |
| PNG SHA-256 | `dfdcc24b49a0e7e09c719ec24a74be4a4b8bf614b457539a7095cc60d65b8a74` |
| Technical QA | 80 nonempty cells, binary alpha, fixed feet, no identical gait A/B pairs, no errors/warnings |
| Actual Godot captures | `.godot/character-qa/792d1d4738e047e09314cc934579df2f`, 32 strict light/dark native/2x pages; actual Wellspring capture `character-pages-oh-tipi-20260908` |
| Visual review | Improved front/back alternating contacts and front sprint facing; suitable for initial source playtest |
| Open acceptance | Diagonal acting/contact clarity and cast/hit facing still merit in-game review; not final animation acceptance |

The validated complete-page override registry now admits this page only for
Oh Tipi. Other identities keep their explicit v15 fallbacks. Source-playtest
promotion does not imply a rebuilt installer or final human visual acceptance.
