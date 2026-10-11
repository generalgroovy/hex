# Native character review

Status: bounded visual review complete for final-source boards; human gameplay
and all-action animation acceptance remain open.

Final source: `p56-ae223a7fae02`. Native boards:
`.godot/pixel-cast-native-v2-20261002/`. Thirty images,1,920 presenter checks.
Reviewed copies are preserved in this directory's `native/` folder.
These are native Godot renders, not reference illustrations. Checks verify
connected presenter output and unchanged authority, not animation quality.

| Review | Finding |
|---|---|
| Small | Eight new sheets independently inspected; Luuh separately reviewed and corrected; S. Wayne retains tested pilot pixels |
| Middle | All ten native boards inspected independently; no new blank/clipping/scale/cast-seam blocker |
| Large | All ten native boards inspected independently; Dr. Apex/Urzh rear mapping and Grimm/Ba rear pose duplication required correction |
| Final corrections | Lead and independent reviewer inspected all four new native boards; NE/NW casts now reach opposing correct directions; connected full figures retained |
| Unchanged review coverage |26 final PNGs match the previously reviewed native set by SHA256; only Dr. Apex, Urzh, Grimm Bow and Ba Djoh changed |
| Portraits | Ordinary Gallery capture initially cut faces below eyes; full-cast head-and-shoulders crop now shows complete faces. Old pilot crop remains unchanged |

The replacement rear strips are somewhat narrower than direct N. Far hands may
be naturally occluded. Grace/Haara/Juul and several other rear/profile contacts
do not yet show convincing anatomical leg alternation; two different pixel
frames do not prove a correct walk cycle. Luuh retains weaker rear volume and
tiny ambiguous head-edge marks. These are carried-forward redraw/playback tasks,
not silently accepted animation completeness.

No authored sidestep/backward sequence is claimed: reversing the phase of two
contacts with shared neutral beats yields the same visible cyclic order.
Unsupported low/air/control actions continue to use the old working renderer.
Static boards cannot establish temporal smoothness, direction readability in
combat, controller feel, rendered performance or a human preference for the art.

All source originals and rejected attempts remain in the workbench. Three
disjoint art workers generated27 identity sheets; a read-only code audit caught
empty-cell admission and oversold backpedal metadata. The lead integrated all
changes and alone ran engines, imports, tests, captures and packaging.
