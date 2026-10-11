# FLUX chemistry — v1
**Source-grounded review and reversible experiment plan. No gameplay implementation or balance acceptance is claimed.**

Start with `HANDOFF.md`, then `IMPLEMENTED_VS_PROPOSED.md`. `REACTION_ROLES.md` contains all ten first-four reactions and all four projectile families. `EXPERIMENTS.json` contains exactly six ordered experiments, each `NOT_RUN`. `COUNTERPLAY_TESTS.md` specifies deterministic cases and short human drills; none has been executed in Godot.

The most consequential findings are a Vortex center that whole-hex selection fills in, additive Conflagration/flow overlaps, weak cooling that can increase Steam's computed scald, and a Steam renderer whose cell-level heat floor hides the cool palette. These are source/arithmetic findings, not invented playtest results.

References use `[P:L197-L219]`-style original-file line ranges or JSON pointers. Resolve them in `evidence/SOURCE_REFERENCES.md`; exact cited source excerpts are in `evidence/SOURCE_EXCERPTS.txt`. All source paths refer to the supplied packet, not a newly fetched repository. Original source files and the user's working checkout are unchanged.

`evidence/STATIC_CHECKS.json` records checks actually performed. `tools/verify_package.py` verifies package hashes and experiment structure, and optionally checks the original source ZIP. This validator does not launch or simulate FLUX.
