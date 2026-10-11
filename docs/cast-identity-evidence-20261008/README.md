# Character identity evidence

Status: locally verified source and Windows portable; human visual acceptance and anatomical normalization remain open.

Build **p57-ac86b7285a04**, October 8, 2026. Eleven portrait expression edits,
native-size Gallery framing and all-cast invariant tests. Root serialized all
engines; three disjoint workers contributed art/audit, UI and regression work.
No body-atlas PNG, simulation or balance change; no deletion, commit or push.

## Fresh gate ledger

| Gate | Actual result |
|---|---|
| Fast | [fast-v1.json](fast-v1.json): source preflight, doctor, import, identity and configured120Hz boot passed; zero suites by definition; [raw logs](fast-v1-logs/) |
| Focused | [focused-v1.json](focused-v1.json): nine suites / 1,964,169 assertions, zero failures/stderr; [raw logs](focused-v1-logs/) |
| Native | [capture receipt](native/receipt.json), [log](native/native.log), empty [stderr](native/native.log.err); 20 PNGs, all30 bodies / 300 controlled pose samples, actual Gallery/selected portraits at1280x720 and960x540 |
| Independent review | [review JSON](independent-native-review-v1.json) and [review notes](independent-native-review-v1.md): every final image viewed and SHA256 bound; 14 PASS / 6 LIMITED / 0 FAIL |
| Windows portable | [package receipt](delivery/package-receipt.json): release export, isolated packed identity, native EXE startup and safe close; [export-smoke.log](delivery/export-smoke.log); empty final error logs |
| Identity | 3,176 production records; SHA256 `ac86b7285a04ecec994a2b0408839933f34b3a2f1059329a9ecfd307818a430d` |
| Final handoff audit | Current-scope and all30 portrait checks passed; unchanged source identity after export; independent audit verified all10 ZIP members/all9 payload checksums and all11 original/source/runtime portrait hashes; 188 local documentation links resolved; CR-aware whitespace check passed; no Godot/hex/flux2 processes remained |

Focused suites: pixel-cast-continuity, pixel-action-bank, pixel-cast,
fullbody-cast, character-overview-model, character-selection-model,
character-selection-grid, champion-portrait-library and character-gallery-integration.
The new registration matrix alone samples 30 identities x 8 headings x 23 states
x 2 settings/phases = 11,040 cases. Counts do not establish anatomical quality.

All eleven revised originals were visually inspected before integration. The
native enlarged-portrait capture samples six of those identities at two window
sizes; it is not eleven independent native portrait captures. All30 admission,
source matching and bounded-cache checks cover the complete library.

## Delivery

[Play](../../exports/hex-cast-identity-20261008/windows/PLAY-HEX.cmd) or
[portable ZIP](../../exports/hex-cast-identity-20261008/HEX-p57-ac86b7285a04-Windows-x64.zip),
127,529,652 bytes. Extract the complete ZIP and retain adjacent EXE/PCK files.
The [previous momentum portable](../../exports/hex-momentum-roster-20261008/windows/PLAY-HEX.cmd)
remains a fallback. No installer was produced for this batch.
The packed README retains generic companion-installer instructions and an older
portrait-delivery link; these do not identify a new compatible setup. For this
checkpoint use the portable wrapper; the package receipt explicitly says
`installer: NOT_RUN`.

| Artifact | SHA256 |
|---|---|
| PCK | `8e6bde24bb0809e34403581764d454a24dac462bdcd36e452ab8aea5ce6cee5d` |
| ZIP | `a9625b236a22b468fa6861468447246619bc9a6f245b11147a11e3e5e50addc1` |

Protocol57/snapshot23/round2/hexworld4 and movement compatibility v17 are
unchanged. Use exact matching builds for peers. Packaging does not prove
physical Internet connectivity or 64-player performance.

## Artwork and limits

- [All30 expression matrix](../CHARACTER-PERSONALITY.md) grounds portrait choices
  in existing resources, affinity priority and actions, without invented powers.
- [Integration provenance](../../reference/art/portraits_20261008/personality-integration.json)
  preserves all11 original/selected hashes; root/motion/momentum prompt JSONs in
  the same folder record built-in imagegen prompts, inputs and outputs.
- [Rejected H. Lenee atlas trial](../../reference/art/portraits_20261008/action-anatomy-trial.json)
  changed pixel geometry/detail and was not admitted. Production body PNGs remain
  unchanged. Similar idle head sizes and coherent torso landmarks across action
  drawings still require careful authored corrections and continuous review.
- Native Gallery framing removes128-to96 body shrink and32-to40 head enlargement;
  common viewport scaling remains at960px. Helper text is small there; use1280px.
- Low/air pose sheets are static and cover South/East only. They do not certify
  all-heading anatomical consistency, authored action cycles or human motion feel.
- The historical dense120Hz timing gate remains FAILED. The prior Full222-suite
  result, installer and multiplayer evidence were not rerun and do not qualify
  this source as performance-, installer- or Internet-accepted.

A copy step initially looked for an incorrect `.stderr.log` suffix; the actual
empty `.log.err` files were then copied. No engine failure occurred. Evidence
copies preserve exact source logs rather than changing prior receipts.

[Checkpoint and test route](../CHARACTER-IDENTITY-CHECKPOINT.md).
