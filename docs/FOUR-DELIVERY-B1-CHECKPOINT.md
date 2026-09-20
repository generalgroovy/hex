# Four-delivery B1 source checkpoint

Status: B1 COMPLETE validated source, 2026-09-13; unexported candidate paused for playtest. B2 pending.

September 14 follow-up: the [scaling baseline checkpoint](SCALING-BASELINE-CHECKPOINT.md)
adds measured load instrumentation and a limit audit on unchanged B1 production.
Its fresh validation is recorded separately; the B1 receipts below retain their
original scope. Full-system performance acceptance remains unresolved.

This bounded substep carries cast-owned reaction strength into paid projectile
releases, optical children, trails and terminal deposits. Persistent chemistry
now requires exact strength equality; unequal deposits wait unchanged. This
does not implement direct attack clashes or Spray interception.

| Delivery | Reaction strength | Current ingredient behavior |
| --- | ---: | --- |
| Rapid | 1 | Paid individual shots; terminal matter; explicitly no flight trail |
| Spray | 3 | Instant cone damage after startup; no ingredient or interception yet |
| Bolt | 5 | Projectile, eligible flight trail and terminal matter |
| Heavy | 15 | Shell and existing blast; eligible trail and terminal matter |

All eight elements use the same ladder. Equal-strength setup currently means
separate casts from the same family, such as Fire Bolt plus Water Bolt. Strength
is independent of damage, Flux, geometry and remaining material quantity.
Optical splitting conserves every valid material quantity from 0 through 1000;
a one-unit parent keeps that unit, and zero material never becomes fresh. Both
branches retain their numeric strength and share the parent's effective cast ID.

Snapshot schema19 appends strength and rejects malformed values or inconsistent
strengths within a cast across projectiles/deposits. Protocol49 and the full
runtime identity prevent older or different builds from joining; old-protocol
replays are refused before stepping. Snapshot application reconstructs remote
presentation state: it is not proof of resumed authoritative simulation.

Final candidate identity: p49-5e49b41aac92; production SHA256
5e49b41aac92b68d76f7baf8409b76bddebc081ae2792350881fac80eb4a60ef;
2720 production records. The generated manifest's candidate status is preserved.

Evidence: docs/evidence/four-delivery-b-20260913/.
Final provenance-full-v2.json passed105 suites/696784 assertions in131757ms with
zero failures and zero stderr, strict import and isolated120Hz boot of the exact
candidate. Native capture-v2 produced32 frames across8cases at720/1080 in normal
and reduced modes; every draw preserved authority. Independent Astra review
inspected16 actual frames covering every case and both resolutions, finding no
blocking readability issue. This is native UI evidence, not an input playthrough
or rendered-FPS benchmark. Final inventory-v3 and the after-inventory cover3132
inputs; provenance-freeze-validation.json records the comparison and copied-log
verification. Logs and captures are preserved together under referenced/.
Earlier numeric/A receipts are historical, not proof of this candidate.
The failed provenance-focused-v1 retains its actual protocol
fixture failure. Corrected focused-v2 passed10 suites/62284 assertions, but it
precedes the compact chemistry-overview text correction. Native capture-v1 also
preceded that correction and mislabeled three family cases; final capture-v2
selects explicit wire IDs. Earlier inventories are superseded by inventory-v3.
Full-v1 retained10 failed assertions: old P48 LAN fixture identities, a pre-schema19
deposit row and the pixel library's old chemistry source audit. The corrections
retain protocol rejection and geometry checks, preserve the original art manifest,
and acknowledge only the reviewed chemistry source difference by exact hash.
Focused-v3 then passed3 suites/66288 assertions with zero failures/stderr before
the final freeze and successful unfiltered Full-v2. Source review and native
follow-through are in provenance-source-review.md and provenance-final-review.md.

To play the newest source, run scripts/run.cmd in this checkout. It delegates to
the guarded Godot launcher and opens the source game; closing the game releases
the engine lease. The launch log prints the identity above. Use Spell Loom and
the Traveller's Compendium to inspect the current strength rules.

Selected portable fallback remains Overnight P48 p48-111d911c27fa:
exports/windows-overnight-p48-20260913/windows/flux2.exe, with its adjacent PCK;
ZIP: exports/windows-overnight-p48-20260913/release/FLUX2-Windows-x86_64.zip.
That package has the older rules. No new EXE/ZIP, pointer promotion, installer,
updater or publication is included in B1. Personal-profile and fallback hashes
are checked separately in provenance-preservation.json.

Playtest this substep: assign Fire/Water Bolt to two accessible slots and aim at
the same nearby clear endpoint before the first matter expires. Matching strength
should combine; repeat with Bolt/Heavy and confirm unequal matter remains apart.
Inspect all four family descriptions; hold/release Rapid and verify no flight
trail. Existing enemy hits, cover and travel can terminate a projectile before
the intended endpoint, so use an empty practice area for the ingredient check.

The 120Hz performance gate remains unresolved. Earlier P48 simulation p95 values
16.658/16.934ms exceed8.333ms and are historical, unmatched to the new four-family
workload. No new sustained simulation benchmark, rendered FPS, physical two-PC,
exact-export networking or human acceptance is claimed by B1. Engine boot at120Hz
and headless transport fixtures are separate evidence categories.

Next bounded work is B2: retain a legal eight-player four-delivery performance
baseline, then integrate ordered direct contacts and bounded Spray interception.
Evidence-only geometry drafts are not live source. The Spray lattice proposal
explicitly misses some thin overlaps/tangencies and has not been accepted or
implemented; resolve contact semantics before promoting that behavior. Mutable
actor/cover blockers require event-time revalidation, not permanently clipped
pair candidates. C lifetimes, Steam/Magma changes and later animation remain in
the single queue. Rollback uses owned before-images after checking intervening
edits, never a whole-checkout reset.
