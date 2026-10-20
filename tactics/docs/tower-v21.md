# Tower rules 21

## Design

The run adds decisions around Confluence's existing simultaneous combat, without adding a second combat system. The player chooses health preservation, spell coverage, affinity growth and party composition while seeing the enemies before entering a room. Enemy plans remain private. The final lineup is visible early enough to prepare for it.

Three starters cover different approaches: Oh Tipi and Cinder create Water/Fire fields; Treevor and Puddle combine control with support; S. Wayne and Wick combine weakening effects with Light support. The starting champion stays throughout the run. New champions and creatures can fill the third position or replace companions; creature kits and class statistics stay canonical.

Nine floors include at least five battles. Ordinary and elite fights use fixed seeded opposition, never rubber-band against the player's choices. Elite training can award up to two affinity; ordinary training awards one. Recovery restores missing health instead of increasing a permanent maximum. Tuition costs two health from the lead champion and requires at least three health before entry. Drafts exclude owned spells and require at least one champion who can currently equip and afford the spell.

All enemy teachings are added at the end of their battle, including enemies defeated before a loss. They belong to this run. A separate draft choice provides further growth; knowing a technique does not increase the four equipped slots. After a win, actual final HP plus one carries onward, bounded by canonical maximum HP. A total party defeat ends the run. No round limit declares a draw while a party survives.

## Persistence and compatibility

- The run, current battle, draft orders and previous round form one browser-local record. Campaign and online keys are untouched.
- Saves validate room generation, history, party identities, canonical stats, library, battle provenance and legal orders. Bad draft/replay data can be dropped without discarding the valid run. Initial battle wounds cannot be replaced by full health in a restored snapshot.
- Reward claims only work in the pending reward phase. Reloading preserves the exact offered options. Finished battles must match the pending room before advancing.
- Copy edits do not invalidate a run. Room mechanics are compared independently from titles and descriptions, and current wording is restored.
- The battle renderer consumes an explicitly versioned, read-only rules-20 view for existing forecast functions. The authoritative snapshot stays rules 21; campaign resolution and campaign storage never receive it.
- Online rules 18 and campaign rules 20 remain frozen. The only campaign UI change is the Tower navigation link.

## Audit findings addressed

An initial hash-sort selection favored neighboring catalogue entries and repeated elemental pairs. A seeded Fisher–Yates shuffle now distributes choices. Across 32 seeds, the opening preview regression checks all six primary elements and at least twenty creature species. Each early pair has different primary elements and at least one damaging spell kit.

Free study rooms originally competed with ordinary battles for the same reward. Floors 2, 4 and 7 now require a battle, and tuition at checkpoints has a visible health cost. Recovery and recruitment remain deliberate alternatives at the intervening floors.

The separate tower version initially caused the shared preview functions to reject otherwise legal orders silently. The adapter now declares the presentation version explicitly; a regression checks both visible fields and projected spell trajectories while preserving the original state version.

Humor belongs to short room situations and occasional result lines. Action labels, costs, consequences and save warnings use direct wording. Repeated starter names, stacked victory quips and redundant spell descriptions were removed.

The tower AI formerly evaluated every target as guarding, even when that opponent could cast. It now weights both publicly plausible cases when a ready spell is affordable, including lethality within each case. A captured eighteen-round encounter provides a regression: the corrected planner recognizes Backdraft against a covered healer who would be vulnerable while casting. Enemy orders stay private and actual combat resolution remains identical to campaign 20 for the same submitted plans.

Room and summit portraits expose each opponent's actual prepared spells, signature, scaled costs, reach, effects and creature bond before entry. Phone previews retain affinity icons, and the selected spell's equip action stays above the library. The paused party overview uses current battle health rather than room-entry health.

## Evidence limits

Automated combat runs exercise actual movement, spell resolution, elemental collisions, elimination, persistent wounds, route transitions and save restoration. They are useful for detecting impossible states, ineffective enemy groups and stalled exchanges. A small deterministic bot sample does not establish a human win rate, long-term build diversity or subjective fun. Defensive builds and repeated projectile clashes can still make some fights reach closing ground; players can change firing angles, focus support units and use displacement.

Two whole-climb comparisons after the AI correction had mixed results. The equipped TOWER1 Steam route changed from a boss loss after 55 rounds to a completed climb after 74 rounds; the equipped TOWER2 Dusk route still lost at the boss but shortened from 70 to 54 rounds. Both measured TOWER1 opening fights still reached eighteen rounds. These observations support the specific decision fix, not a claim that all pacing or balance is solved. Separately, 108 synthetic climbs checked route/reward/save transitions with artificial victories; those are structural coverage only.

Browser checks cover the desktop and narrow phone layouts, preparation, real orders and combat feedback, reward/recruitment flows, saved-run reload and backup import. A resized browser is responsive-layout evidence, not a physical phone performance test.
