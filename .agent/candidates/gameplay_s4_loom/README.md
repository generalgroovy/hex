# Spell Loom starter preview candidate

Status: candidate only. Godot import, tests, native capture and visual acceptance are **NOT RUN** in this lane.

## Promotion targets

- `spell_loom_editor.gd` -> `src/app/spell_loom_editor.gd`
- `spell_loom_presenter.gd` -> `src/presentation/spell_loom_presenter.gd`
- Merge the added starter-preview test into `tests/unit/test_spell_loom_editor.gd` (the candidate is a full-file copy).

The candidate reads the existing `CharacterStarterKit.build()` projection and the shared `VisualLanguage` element/UI tokens. It does not mutate the player, library, world or catalogs.

## Root hook contract

Entry button: `SpellLoomEditor.STARTER_BUTTON_RECT = Rect2(960, 66, 220, 34)`.

While `editor.starter_preview_active()` is false, an activated entry button calls:

```gdscript
editor.prepare_starter_preview(state, champion_catalog, ability_catalog)
```

The method resolves the equipped character from `state.champion_wire_id`, calls `CharacterStarterKit.build()`, snapshots all twelve current/proposed wires, and opens the comparison only after full validation.

While the preview is active, route input to these controls before the ordinary Loom/Close handlers:

- Apply: `SpellLoomEditor.STARTER_PREVIEW_APPLY_RECT = Rect2(858, 614, 142, 38)`
- Cancel: `SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT = Rect2(1016, 614, 142, 38)`
- Overlay: `SpellLoomEditor.STARTER_PREVIEW_RECT = Rect2(88, 52, 1104, 620)`

Apply calls `editor.request_starter_apply()`. The returned root-action payload is:

```gdscript
{
    "action": "apply_character_starter_kit",
    "champion_id": String,
    "expected_wire_ids": PackedInt32Array, # exact twelve-wire snapshot
    "wire_ids": PackedInt32Array,          # exact proposed twelve-wire starter
}
```

Root authority should reject the action if the actor, equipped champion, or current twelve wires no longer match the request, then apply the complete proposed array as one authoritative transition. Call `editor.complete_starter_apply(true)` only after that transition succeeds; `complete_starter_apply(false)` retains the preview for review or cancellation.

Cancel calls `editor.cancel_starter_preview()`. It discards only the editor snapshot. A normal `close_editor()` call during preview also cancels the preview and leaves the Loom open, which quarantines older Escape/B/Close hooks until root routes explicit preview input. Recommended preview keys are Enter/A for Apply and Escape/B for Cancel.

## Presentation contract

The existing `SpellLoomPresenter.draw_panel()` signature is unchanged. It paints the usual Loom, adds a quiet starter entry button, and paints the comparison overlay only while a preview is active. The overlay shows twelve labeled before-to-after cards in two columns, using shared element colors and glyphs. Water and Fire carry `HEX COURT: WATER/FIRE`; Earth, Air, Ice, Charge, Light and Dark carry `HEX EFFECT PENDING`. The notice states that applying replaces a custom weave, Cancel preserves it, and Apply is the only save step.

No bootstrap hooks, authority mutation, network encoding, live assets or shared color files are included.
