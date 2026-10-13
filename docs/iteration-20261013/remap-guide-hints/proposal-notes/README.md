# Remapped convenience hints — unapplied draft

Status: independently source-reviewed ignored prototype only, based on frozen `p61-500be306a26a`. No canonical
source is changed. No parser, test, native image, full-boot, physical-device or
performance result is claimed. Root may apply only after the qualified delivery
checkpoint and independent exact review.

The supported binding editor accepts F5/F6 for gameplay. Existing routing gives
such a binding priority over Introduction/Range and their shifted convenience
actions, while current guide/menu/practice labels still advertise those actions.
This draft makes those labels agree with the existing predicate. Defaults remain
byte-identical, and Menu fallback uses the existing action hierarchy.

## Scope and ownership

- Experience owns this ignored three-file patch and the existing spell-tools
  regression draft. Gameplay reviews real remapping/payment/lifecycle; Technical
  reviews bounded queries/label scope. Root owns all engine execution and later
  integration. The self-prompt and source evidence are in the final selected-issue
  section of `docs/iteration-20261013/experience.md`.
- One `shortcut_available(key)` method extracts the existing ownership predicate;
  the routing condition and all changed labels share it. No action precedence,
  key reservation, geometry, font, pointer target, storage or authority changes.
- Only F5/F6 and shifted variants are in scope. Fixed Compendium F4, Menu M and
  every other input remain unchanged. There is no new cache or preference copy.
- `before/` preserves exact canonical bytes; `proposed/` is a full-file review
  view. `manifest.json` pins both, and `remap-guide-hints.patch` uses canonical
  paths but has not been applied. The generator refuses canonical drift.

## Regression and acceptance

The existing minimal Bootstrap test harness has real InputMap/editor capture,
inherited input dispatch, release/guard consumption, Menu activation, and an
ordinary paid Hex world. F5 and F6 each become spell slot 1 through the editor.
Both ordinary and Shift-modified presses use the actual input route. The draft
checks guide/menu fallback, exact real payment and cast event, Menu
Skip, default label and F5 action restoration, controller fallback and InputMap
cleanup. It deliberately does not claim a full game boot or Range-world travel.
No mid-run resources, timers or combat events are injected.
The existing harness manually decrements its two-frame input guard between
ordinary simulation steps; it does not call inherited `_process`. Its practice
menu has no Challenges row, so that Shift+F6 label branch has source review but
not a reached menu-row assertion; actual Shift+F6 gameplay routing is exercised.

After application, Root should run strict parsing and the existing spell-tools
and local-navigation suites, then inspect the longest fallback at 960/1280 and
100/200% plus controller mode. Prepared UI-state checks cannot replace that
native fit gate or physical-input acceptance. The public input API and global
InputMap must be restored even when an assertion records a failure.

Prior review checkpoint patch `59ceae7009640e2ccb3230636a2b0b23b2de8e80107910ef2f2aec2feab4ec8f`
was never executed. Finalization only shortens the new Range fallback and adds
the restored F5 action assertions, plus any explicitly recorded peer corrections.

Final frozen patch `93628c4843e11611f0420222d568c07ced1e635b9d9f483abdfac66869e9cc16`
has Gameplay's exact source approval. Independent Python reconstruction applies
each unified hunk to its pinned predecessor and reproduces all three proposed
files; canonical bytes still match every predecessor. This is patch-integrity
validation only, not Godot parsing, tests or native fit acceptance.
