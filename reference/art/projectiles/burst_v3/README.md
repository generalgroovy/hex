# Burst projectile style board v3

This project-bound source board was produced with the built-in image-generation
tool on 2026-08-26 after the imported v2 PNG streams failed decoding. It is a
replaceable visual source, not gameplay, collision, timing, element, or release
authority. `tools/assets/prepare_burst_runtime_v3.py` crops its nine ordered
cells and deterministically builds the validated runtime atlases.

Cell order is `neutral, fire, water / wind, earth, charge / ice, light, dark`.
The runtime generator recenters each token on its luminous collision read,
reduces it to a bounded palette, authors spawn/travel/impact/residue phases, and
derives exact mirrored eight-direction rows around a fixed 32×32 pivot.

Final prompt:

> Create nine distinct magical hand-cast projectile cores in a clean 3×3 grid:
> neutral, fire, water, wind, earth, charge, ice, light, and dark; charming crisp
> cartoon pixel art, old-world magic, economical dark outlines and 3–5 color
> ramps, transparent background, no text/UI/caster/staff/wand/gun. Keep a common
> readable collision core while elemental ornament makes every silhouette
> distinct at 32 px.
