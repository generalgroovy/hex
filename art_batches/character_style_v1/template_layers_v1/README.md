# Shared template attachment/layer contract v1

This isolated package prepares a machine-readable body-layer declaration for the
current FLUX three-size rig. It is **preparation only** and remains pending human
shared-template approval. It does not contain a named skin, source art, copied
asset bank, runtime atlas, live renderer, or promotion instruction.

`attachment-layer-contract.v1.json` binds future offline layer declarations to
the actual 18 joint names present in every one of the current rig's 3,312 poses.
It also binds the 96x96 cell, feet pivot `(48,84)`, last opaque row 83, source
rig heights 58/68/76, and final display heights 58/63/68. Middle and large layers
therefore use the same pivot-relative scales as the current baker: `63/68` and
`68/76`.

The contract permits body, anatomy detail, clothing, hair, and ancestry traits
in rear/body/front bake bands. Future declarations must use only generic
`template_small`, `template_middle`, or `template_large` identities and exact rig
anchors. Weapons, staffs, wands, swords, shields, magic, spells, effects, auras,
shadows, ground markers, and environment layers are excluded.

Run the static contract and rejection proof from the repository root:

```powershell
python art_batches/character_style_v1/template_layers_v1/verify_contract.py --self-test
```

To inspect a future declaration without running Godot or writing output:

```powershell
python art_batches/character_style_v1/template_layers_v1/verify_contract.py path/to/declaration.json
```

A candidate declaration has exactly these fields:

```json
{
  "schema_version": 1,
  "contract_id": "flux-shared-template-attachment-layers-v1",
  "template_id": "template_small",
  "body_type": "small",
  "layers": [
    {
      "id": "plain_clothing_front",
      "semantic": "plain_clothing",
      "depth_band": "front",
      "anchors": ["neck", "pelvis", "shoulder_l", "shoulder_r"],
      "texture": "layers/plain-clothing-front.png"
    }
  ]
}
```

The verifier is deliberately bounded: declaration JSON is limited to 1 MiB, the
hash-locked rig snapshot to 16 MiB, the contract to 16 provenance sources and 64
joints, and a declaration to 64 layers with at most eight anchors each. It
rejects duplicate/unknown fields, unknown anchors, unsafe texture paths, and
forbidden layer-family terms. Provenance hashes make source drift an explicit
review failure.

Static metadata validation cannot determine what pixels depict. Human review
must still verify that a future PNG is body-only, visually correct, attached to
the intended anatomy, and ordered correctly in every facing and pose. Godot
import, runtime behavior, rendered performance, atlas assembly, and user
acceptance are `NOT RUN` here.
