# Canonical H.E.X. affinity verification

Verified against the original repository on 2026-10-16. All 30 Confluence character IDs, display names, ancestry values, body types and affinity vectors match `content/champions/foundation_champions_v1.json`, with the sole identifier normalization `wind` to `air`. The original foundation roster also matches its separate canonical allocation, `content/champions/champion_affinities_first_eight_v1.json`, for all 30 names and affinity vectors.

Source SHA-256: `0125f9c55c976eb274ba51e1319f69f4ea62d5d6183bcab14a590aaa695a5b1a`. This is unchanged from `v4-roster-provenance.json`; no roster rewrite was needed.

The current original game uses six live ingredients: Water, Fire, Air, Earth, Light and Dark. `SPECIFICATION.md:313–318` and `src/content/element_rules.gd:3–12` explicitly retire independent Ice and Charge ingredients. Ice effects belong to Water and Charge effects belong to Fire; historical IDs are not admitted into live network state. The canonical allocation at lines 23–24 conserves each champion's three affinity points during this migration and explicitly forbids aliasing legacy Void or Chaos to Dark. The supplied champion poster guides visual style, not current rules.

Examples that differ from the historical poster are therefore intentional: Oh Tipi has Water 2 / Fire 1; Wa Bidi has Fire 2 / Air 1; The Red Baron has Fire 2 / Water 1; Grimm Bow has Earth 2 / Water 1. S. Wayne has Dark 2 / Light 1.

Confluence preserves these strengths while adapting their mechanical benefit to a four-spell, turn-based game: strength 2 reduces a spell's base Flux cost by 1, strength 1 uses its base cost, and an unaffiliated spell costs 1 extra, with a minimum cost of 1. Concussed adds its separate visible surcharge. Every element remains learnable. This cost rule is Confluence's adaptation, not a claim that the original twelve-slot action game uses identical costs.

Verification method: read both original JSON sources and import `CHAMPIONS` from the generated Confluence roster; compare each declared field and each affinity entry, then compare counts and source hash. Result: 30 / 30 characters and zero discrepancies. The original repository was read only.
