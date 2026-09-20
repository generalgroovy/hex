# Jan Wicked - new art batch

Status: pending appearance review and generation. No artwork or promotion exists.
Canonical ID: jan_wicked; race: human; body: middle, 68px.

1. Resolve appearance from approved references into champion-worksheet.json; no example palette/clothing was silently assigned.
2. Use eight one-heading prompts. Keep original generated source PNGs immutable; the planned2x5 board pairs A/B contacts.
3. Fill source-layout.scaffold.json with actual source hashes, measured crops and page-wide calibration. Null placeholders intentionally fail assembly; do not replace them with guessed values.
4. Assemble an isolated candidate with scripts/build_character_style_pack.gd, then run native sheet QA.
5. Complete all80 pending review cells against the actual candidate SHA and evidence. Agent review is not final human approval.
6. Run scripts/validate-character-art-review.ps1, integration tests and the Full gate before any new live promotion.

The existing game, catalog, art registry, sprites and installer are untouched.
Runtime stays80 slots/8headings,96px cells,48/84 pivot; each whole body uses one immutable scale. Effects remain separate and hands empty.
