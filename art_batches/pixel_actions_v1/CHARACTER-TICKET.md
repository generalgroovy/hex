# One-character fixed-pixel jump ticket

Lead assigns exactly one `id`; read its current body_type, ancestry and display_name in content/champions/foundation_champions_v1.json. Runtime identity wins over old reference labels. Do not change gameplay, roster, stats or scale policy.

## Read and inspect

Read C:/Users/sende/.codex/skills/.system/imagegen/SKILL.md and its required references fully. Use the built-in image_gen tool only. Inspect local input images with view_image before generation:

- assets/sprites/pixel_cast_v1/<id>.png (approved runtime costume, face, colors and headings).
- assets/sprites/fullbody_cast_v1/<id>-detail.png (identity detail).
- C:/Users/sende/Pictures/styleref1.png (charming retro style only; old names/races/props are not canonical).
- Read prompts/s_wayne.md in this directory for the successful v3 proportion contract. Do not emulate rejected oversized heads.

## Generate one source sheet

Exactly 8 columns by 4 rows, 32 complete full-body poses of this ONE character on true transparent background; no captions, names, grid marks, effects, shadows or environment. Eight headings in columns:

| S | SE | E | NE | N | NW | W | SW |
|---|---|---|---|---|---|---|---|
| Camera/front | Front-right | Right profile | Back-right | Back | Back-left | Left profile | Front-left |

Rows: (1) jumpsquat/anticipation, (2) rising tucked jump, (3) descending feet-ready jump, (4) visibly deeper compressed landing. Rise and fall must have distinct readable leg/arm silhouettes at small scale. All frames must be complete, uniformly spaced, unambiguously oriented, and preserve costume/anatomy. Maintain one shared head/body scale across poses: head about one-third neutral standing height, not oversized chibi. Size differences primarily body volume, not stretched height. Feet/limbs must articulate naturally without changing anatomical length. Preserve each character's gender presentation without sexualization. Keep characteristic wings/tails but leave transparent clearance around extremities. Empty hands: remove weapons, staffs, wands and baked magic. No synthetic mirrored directions or code-painted poses.

Use one initial image generation call; a corrective call only for a gross facing, anatomy, grid or cropping defect. Do not spend multiple calls polishing invisible detail. Review the generated original before acceptance. Save the generated PNG byte-identically using Copy-Item; deterministic alpha cleanup, registration and downsampling are lead-owned assembly work, not this ticket.

## Ownership and handoff

Only write these three files (create parent dirs as necessary):

- source/<id>/source.png (untouched original)
- source/<id>/receipt.json (JSON object with provenance/source identity, original SHA256, dimensions, transparency, review observations and limitations; completion marker written last)
- prompts/<id>.md (exact final prompt and reference paths)

Use apply_patch for text edits. No runtime manifest/builder/shared documentation edits, no Godot/import/capture/export, no commit/push, no other character work. Do not create tools/helpers unless necessary; remove only your own temporary helpers. Report the 3 files, hash, any visual ambiguity, and native-scale/runtime/human acceptance as NOT_RUN. Do not call source-size visual review runtime acceptance. Complete this one ticket and return promptly so the lead can assign the next character to a fresh agent.
