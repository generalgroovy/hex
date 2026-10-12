# H.E.X. spell and loadout configuration

Status: current configuration guide, October 11, 2026. The specification and validated runtime catalogs own the rules.

The current source keeps six ingredients, 63 nonempty
ingredient sets, eight delivery families and **504 runtime spell definitions**.
The effective ability catalog retains 542 records; disabled historical entries
are not selectable spells. Qualification applies to the exact source and package
recorded in the [resume](../.agent/HEX-RESUME.md), not to arbitrary later edits.

## One casting model

Water, Fire, Air, Earth, Light and Dark form the selectable ingredients. Ice and
Charge are derived effects, not additional ingredients; `wind` is Air's internal
identifier. Every ingredient set has Bolt, Heavy, Rapid, Spray, Mantle, Fuse,
Split and Rebound definitions. Delivery determines the physical form; the
compiled payload supplies element membership and finite effects.

Keep damage, strength, cost, startup, recovery, cooldown, range, lifetime and
capacity values in their validated definitions. Do not copy an obsolete numeric
table into a menu or a second implementation. The
[specification](../SPECIFICATION.md#spells-and-planned-physical-combat) describes
delivery roles and admission; the [balance contract](HEX-BALANCE-CONTRACT.md)
distinguishes implemented choices from unproven competitive usefulness.

## Source ownership

| Boundary | Source |
|---|---|
| Canonical ingredients and legacy folding | [ElementRules](../src/content/element_rules.gd) |
| Authored records and runtime order | [Ability data](../content/abilities/foundation_abilities_v1.json), [AbilityCatalog](../src/content/ability_catalog.gd) |
| Ingredient-set identities and family mapping | [Mixture data](../content/abilities/element_mixtures_v1.json), [MixtureCatalog](../src/content/mixture_catalog.gd) |
| Executable spell definitions | [CombatDefinitionTable](../src/sim/combat/combat_definition_table.gd) |
| Admission, payment and release | [CombatSystem](../src/sim/combat/combat_system.gd) |
| Per-character weave storage and application | [Library](../src/app/character_weave_library.gd), [policy](../src/app/character_weave_policy.gd), [coordinator](../src/app/character_weave_coordinator.gd) |
| Earned signature availability | [Challenge catalog](../src/content/signature_challenge_catalog.gd), [progression](../src/app/signature_progression.gd) |
| Ground reaction identities and behavior | [HexRecipePolicy](../src/sim/hex/hex_recipe_policy.gd) |

These are separate responsibilities, not alternative authorities. UI, art and
audio present accepted behavior; they cannot manufacture a hit, resource,
reaction, unlock or movement permission.

## Twelve positions, shared spell identity

The Spell Loom configures Plain 1–4, Ctrl+1–4 and Alt+1–4. Positions do not create
new spell identities: duplicate equipment and swaps retain spell-owned cooldowns.
Fresh explicit input has priority, including refusal. Otherwise the lowest held
repeat-enabled position is selected; held single-press choices do not suppress
Bolt/Rapid. An invalid or unaffordable request must not silently spend on another
spell. Releasing input prevents new repeats; it does not undo an admitted cast.

Thirty signature definitions require a clean victory against the corresponding
rival. All other spells, including the original 24, remain available. Previously
valid saved/equipped choices are preserved. The offline Range temporarily loans
all definitions and restores the prior weave; Developer overrides do not grant
earned progression. All thirty sandbox characters are already available.

## Saves, wires and validation

The original 24 spell IDs and wires remain stable. Local legacy Ice/Charge weave
migration requires a visible replacement preview, preserves valid canonical
positions and retains original bytes before application. Old identities must
not be admitted silently through the live network boundary. Saves retain the
compatible `Godot/app_userdata/FLUX 2` location.

Changes to live definitions require catalog/compiler validation and meaningful
admission, payment, cooldown, refusal, progression, save and replay checks.
Production changes affect the canonical runtime identity; protocol 60 and
SessionSnapshot schema 24 require exact compatible state. Regenerating an
identity is not qualification. See [development](DEVELOPMENT.md) and
[networking](NETWORKING.md) for those separate boundaries.

The [exact previous document](archive/source-publication-20261011/ABILITY-CONFIGURATION.md)
retains the earlier sixteen-spell, eight-element design and historical harness
detail. Those tables and promotion plans are not current instructions.
