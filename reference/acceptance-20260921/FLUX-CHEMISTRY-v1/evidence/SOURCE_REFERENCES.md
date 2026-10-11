# Source reference register

All paths below are relative to the original FLUX-SOURCE-PACKET.zip. Line numbers are one-based original-file lines, not wrapped text lines. `[P:L197-L219]` means alias P, original lines 197 through 219. `PROFILE#/runs/0` is an RFC-style JSON pointer into the supplied report, not a fresh benchmark.

Full file bytes were read for extraction/integrity. Analytical review is limited to the documented/cited paths and excerpts; this is not a claim to have audited every dependency in a runnable checkout. The exact referenced excerpts are bundled in `SOURCE_EXCERPTS.txt`, with original line numbers. JSON pointer values are included there when used.

| Alias | Original packet path | Lines | SHA-256 |
|---|---|---:|---|
| MAN | `INPUT_MANIFEST.json` | 398 | `b0a9d9a54f575d6e4f056cdf0b35988ba843779d30bb0deaed130744b44175d1` |
| CONTRACT | `01-SHARED-CONTRACT.md` | 42 | `af1ba3bca2c2f0c1ebe34a623202fbc02374046397f1c7cd23ef79df61ba0928` |
| BRIEF | `06-CHAT-CHEMISTRY.md` | 27 | `27153e6086cdd97bbc761d5fc35b4d3071973f2df11df0b2299a388c2f0ae404` |
| AUDIT | `11-AUDIT-SNAPSHOT.md` | 42 | `acc2e1c384fd13fbaa63cf9b8dde7c5002114273802bcb247d56b301473393a2` |
| SCHEMA | `10-HANDOFF-SCHEMA.json` | 31 | `48bce1abe18670f1c1e706d7791945fe0c46317270089d05136ca1fb31c652de` |
| SPEC | `repository/SPECIFICATION.md` | 960 | `26760a1c8fb3a758217251d6d5682e1a073355cb47eb5f3c8361470876f99333` |
| QUEUE | `repository/.agent/OVERHAUL-IMPLEMENTATION.md` | 348 | `7c06bd6c1196461098d780c492ddbc17c058ff9f2ad150e0ffd56af2cd7aec33` |
| CHECKPOINT | `repository/docs/current-checkpoint.json` | 90 | `d1bfaae39dfcb415ce91587237056e6a21aa85b688cc0dbea187a8f5484c8e9f` |
| README | `repository/README.md` | 521 | `16b062cf1ddeb8a757bacb93fdba5a3984ac0d845688d74b85b7292b64ec5fae` |
| COURT | `repository/docs/HEX-COURT-CHECKPOINT.md` | 90 | `5be42ee7f482cd88766bfaa46482270f2a93334ee447b04eac1aa319520fd075` |
| P | `repository/src/sim/hex/hex_recipe_policy.gd` | 328 | `2962b47e4a90a896b266988ece34d320e3c8fcf5ae507a17fed640f90b11a2e0` |
| W | `repository/src/sim/hex/hex_chemistry_world.gd` | 1085 | `ce04cda6ab82f369af04dcbdf0a81f4b1f3c5199b8d769f3fa9e7c0d4e0a6d8e` |
| E | `repository/src/sim/hex/hex_product_effects.gd` | 431 | `6c2f4f1a02a00cada569f73056f2df290f167558fc3723f08d40c7674217d9a9` |
| C | `repository/src/sim/hex/hex_projectile_combat.gd` | 646 | `aaa289ff77614a775c949f2f0c2836af90d93d445405618336dfc79a591a58b2` |
| G | `repository/src/sim/hex/hex_grid.gd` | 307 | `086ad20e6ec1de4229076ba331435e839fccdfc09d8e1af9d0fadd0aa208b1d0` |
| F | `repository/src/sim/hex/hex_footprint.gd` | 1664 | `74403370caa2c9f1331a7db849ffe8c45ed677de4fd9d389a02af6b3dda7b987` |
| V | `repository/src/presentation/hex_court_presenter.gd` | 1270 | `628f34d461137f4b6e150cc27451f0a2ce08875baa0a58478f8cd640fb01bf3b` |
| J | `repository/content/reactions/first_eight_element_reactions_v1.json` | 94 | `4431e33377773874f24037dd8382772903622c38bc2c79e6ed525e5124662cbc` |
| VIS | `repository/content/visual/visual_language_v1.json` | 165 | `8c7592f50e849ab409951a480a10c965a85ced528b2e7c1ff363574f27db27d1` |
| BODY | `repository/content/champions/body_type_profiles_v1.json` | 61 | `e3f386409159a431e43648efec8b8762c9424217208db683b02a07acf350ad13` |
| CFG | `repository/src/sim/core/sim_config.gd` | 43 | `a34108c94e174c2986250cdba07582a8bc21be5adce84a19cb68f74f36cb15eb` |
| NET | `repository/src/net/hex_world_snapshot.gd` | 642 | `14fc03676fff8ef18b5f1979ac7d23eca27444daa35fc0e81aa38833ddbc7276` |
| PRED | `repository/src/net/client_prediction.gd` | 423 | `706696e60cfa2ee43bed7afbfa64d27a94c07a26fb82e36de79454fae47fa126` |
| BURST | `repository/content/visual/burst_projectile_runtime_v3.json` | 136 | `9657f7599a3af634f06e65814e1b9b1aef6c073baa40d186f8984a95ef26649a` |
| FULL | `repository/docs/evidence/global-hex-20260920/full-v2.json` | 818 | `75df6b4bc9bfa4d812e271e40e73790489e558706d970f0da5227b0c47296a8c` |
| PROFILE | `repository/docs/evidence/global-hex-20260920/global-hex-profile-global-v2.json` | 233 | `432073b76c52be54d3d208500dfeec84d140694e3a682bc52614b195f480d379` |
| NETWORK | `repository/docs/evidence/global-hex-20260920/network.json` | 35 | `0658cd7779697537645205d9184fdb222dc4eda0d3caf94750db0ac2da240b22` |

## Saved native image access

| Image | Read scope | SHA-256 |
|---|---|---|
| `repository/docs/evidence/global-hex-20260920/native/01-before-free-casts-1280x720.png` | INVENTORIED_ONLY — historical, not a fresh capture | `d0fb61b44fd3d768a63576596ffbd901bad8cc0e02abab6cb5a73cee4a9a9b54` |
| `repository/docs/evidence/global-hex-20260920/native/02-water-away-from-dummy-1280x720.png` | INVENTORIED_ONLY — historical, not a fresh capture | `5921a321688a646662e2450e52b4ce90f4df0abca635844e310b823ee286d6f3` |
| `repository/docs/evidence/global-hex-20260920/native/03-steam-normal-1280x720.png` | INSPECTED — historical, not a fresh capture | `620a9c77b17d9a1a6bb69d294e63f6b66f07d97d8c3e1c6db0b7dca58265555f` |
| `repository/docs/evidence/global-hex-20260920/native/04-steam-reduced-1280x720.png` | INSPECTED — historical, not a fresh capture | `bd7aba036ff6d548b21642aee7c5327591b372fbad5745fc62626d5f5e226441` |

## Other reference boundaries

`INPUT_MANIFEST.source.json` is an exact copy of the supplied input manifest. Source ZIP SHA-256: `844e314277b3df5d6eccb44ec37b1f6a705b55abfb6c2101fc1fbadb939fc45f`. Its 63 listed records were compared against the extracted bytes.

The code aliases establish inspection evidence. `FULL`, `PROFILE`, `NETWORK`, `AUDIT` and `CHECKPOINT` establish what the supplied historical reports say; their success/failure labels must not be substituted for tests of this proposal. Runtime policy and live execution paths outrank older generic JSON profiles and prose.

The missing dependencies named in HANDOFF.md prevent a complete engine run. No uploaded source was altered. Concept references in `references/` were not used as gameplay or chemistry-authority evidence.
