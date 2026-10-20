# Planning clarity

This pass improves how players read the existing simultaneous rules. Combat, progression, room transport and protocol remain at version 13.

## Player changes

- Battles open in Overview, exposing both teams and every well. Focus frames the selected character's legal planning area while keeping phone targets at least 44 CSS pixels wide. Characters remain visible in Focus. Hovering preserves a manual pan; deliberate selection or action changes reframe the camera. Resolution restores the chosen view.
- The selected cast previews resulting fields across its entire footprint. The same pure forecast supplies tile colors, symbols, names, counts, meaningful consequences and allied-exposure warnings. Queued previews remain after pointer departure, and choosing another spell clears the old footprint.
- Forecasts use public terrain, the player's orders and announced creature actions. They exclude rival plans. Guaranteed allied movement collisions are reflected in the surviving cast's actual origin and footprint; hidden opposing orders remain uncertain.
- Phone spell controls use three columns and two rows, with readable element icons, names and costs. The selected spell's shape, reach and effect appear together. The four main turn controls remain fixed at the bottom.
- Focus displays prioritized status symbols and durations for allies and rivals, with an overflow count. Inspection retains complete status information.
- Character selection chooses a ready equipped spell, preserving an existing queued choice. Rules correctly explain that level-one spells require one affinity point.

## Cooperative review

Four specialist agents covered tactics, camera/interface, battlefield feedback and independent review. Integration used disjoint file ownership and shared pure helpers. Reviews found and fixed incorrect line footprints after an allied bounce, deferred selection after resolution, first-pan behavior at map edges, unreadable phone status durations, and excessive overview styling in adaptive Focus.

## Verification

Focused tests cover mixtures through all six elements, public creature interruption, deliberate Ice versus Flood, candidate replacement, allied exposure, hidden-order exclusion, immutability, actual resolver footprints, camera geometry, real component events, phone sprites and controller spell selection. Existing progression assertions remain intact; the extracted-handler harness now receives the controller's new real dependencies.

Browser checks exercise queued Ice and Steam, changing selected spells, a complete simultaneous turn, Overview persistence, Focus and phone card layout at 320 and 390 CSS pixels, plus desktop layout. Final test/build and deployment receipts are retained outside source in the task's work directory. Browser viewport emulation is not physical-device testing; these checks do not establish human enjoyment or long-term competitive balance.
