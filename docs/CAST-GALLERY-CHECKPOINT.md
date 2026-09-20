# Named cast and race-column Gallery

Status: verified local playable-baseline candidate,2026-09-08; individual sprite restyles remain unfinished. No commit, push or installer publication.

## Scope and authority

The latest user request makes the original supplied Oh Tipi the character-style
authority and asks for all planned characters plus race-column selection. It
supersedes the previous no-catalog-expansion priority, without erasing measured
performance limits or making generated artwork authoritative gameplay data.

| Slice | Current result | Acceptance boundary |
|---|---|---|
| Canonical identities |27 named playable profiles plus reserved Angel; Spiderkin vocabulary; three body types | Original five profiles/wires unchanged; new profiles are conservative baselines |
| Shared-system implementation | Every profile has stats,2–3 weighted affinities, three paid starter spells and twelve configurable slots | No claim of bespoke abilities, racial passives or individual balance |
| Race-column Gallery | Seven alphabetical columns/page, hover details, navigation, current/temporary/reserved labels | Physical-controller feel and human readability remain playtest gates |
| Network selection | Exact bounded wire request; host validates station, phase and actor safety | Protocol47 rejects old peers; loopback is not internet acceptance |
| Safe attunement | Same identity is a no-op; changed identity preserves resource ratios and resets starter loadout | User is warned; no switching during casting, protection or airborne actions |
| Reusable temporary visuals |22 explicitly marked aliases reuse existing small/middle/large atlas regions | No extra textures; no misrepresentation as unique race art |
| Oh Tipi-style production | Immutable raster drafts, prompts, source-layout metadata and strict importer | Opaque near-magenta backgrounds and opposite-contact QA prevent promotion |

## Honest art state

The five existing individual sprite sets stay live. The22 new profiles visibly
reuse tested body templates, including their eight directions and ten pose rows.
This keeps every named character playable but is not a finished full-cast restyle.
The original Oh Tipi reference is preserved byte-for-byte. Generated draft pages
are separate in `art_batches/character_style_v1/oh_tipi/`; neither an opaque
checkerboard nor a near-magenta background is accepted as transparency.

New raster art used the built-in image-generation workflow. No vector stand-ins,
external API, silent chroma-key cleanup or per-pose resizing replaced character
art. The next artwork slice must obtain transparent sources and verifiable A/B
foot contacts before producing a live80-cell page.

## Verification ledger

| Check | Result |
|---|---|
|27 ×3 starter slots ×8 directions |648 actual paid casts; release identity, directions, costs and stats pass |
| Network/policy slice |1,771 focused assertions; typed bounds, sender identity, replay suppression, prior-protocol refusal and no-op state preservation |
| Gallery integration |3,319 focused assertions, including actual production open/request/feedback handlers and neutral gameplay input |
| Runtime sprite aliases | All80 cells per template retain source atlas/pivot, no duplicate textures; focused visual suites pass |
| Real Windows Gallery render |1280×720 isolated source capture inspected; no startup error |
| Final Full suite + source boot |90 suites /398,091 assertions; zero failures/warnings/stderr;120Hz protocol47 source boot |
| Real remote-selection probe |450 assertions,28 snapshots,24 directional cases across new Small/Middle/Large identities; local ENet and actual production request handler |
| Farflow smoke | HELLO, reconciliation, shared phase, late spectating, reconnect/rematch and removal pass on isolated UDP24947 |
| Human feel, remote internet, sustained120FPS | Not accepted by these checks |

Retained [receipts and actual captures](evidence/cast-gallery-v1/README.md).
The first Full run exposed archive adapters incorrectly requiring all28 canonical
identities to exist in24 historical art slots; subset validation fixes that without
inventing artwork. A later station-label edit exceeded the52-character content
limit; the text was shortened and the final Full rerun above passed. No failing
run is being presented as acceptance.

## Test this source

Run `flux.cmd play` from the repository. In Wellspring, walk to the Champion
Gallery and press **E**. Hover cards to inspect, then click or use keyboard/D-pad
selection. Race pages use the visible buttons or PgUp/PgDn / controller LB/RB.
Escape/B closes without quitting; the shared world does not pause. A protected
spawn must settle before attunement is accepted. All friends need the same
protocol47/content state. Existing download installers have not been rebuilt.

## Next bounded slices

| Order | Deliverable | Gate |
|---:|---|---|
|1| Transparent Oh Tipi core + opposite walk/sprint contacts | Native-scale anatomy/facing review; no opaque matte |
|2| Complete Oh Tipi80-cell registered page | Ten poses × eight directions, fixed68px standing scale, all movement/cast captures |
|3| Small then large style templates; remaining characters one by one | Unique silhouettes; remove each temporary tag only with accepted complete art |
|4| Individual kit/stat/race distinctions | Evidence-led balance; preserve shared movement and paid casting |
|5| Resume measured projectile/reaction hotspot and transient-event priorities | Legal-eight p95 below8.33ms before claiming sustained120FPS |

See [current cast](CURRENT-CAST.md), [art production](../art_batches/character_style_v1/README.md)
and [previous delivery checkpoint](DELIVERY-PRACTICE-CHECKPOINT.md).
