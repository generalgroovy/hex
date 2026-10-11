# Movement animation follow-up

Status: COMPLETE AS A VERIFIED LOCAL WINDOWS PLAYTEST, `p59-a289f67c1acf`.

October 9, 2026. This follows the separately qualified `p59-6336a7ba6067`
portable. Its Full and native receipts remain historical evidence for that build.
No simulation, input, resource, collision, element or network policy is changed.

## Decisions and reference boundaries

| Decision | Established example | Application and evidence limit |
| --- | --- | --- |
| Keep compact jump silhouettes and allow movement follow-ups through existing controls. | Nintendo's [Sonic design description](https://www.smashbros.com/wii/en_us/characters/sonic.html) explicitly praises the simple controls and describes spin, jump and midair follow-ups. | H.E.X. keeps native tucked anatomy and its own paid chains. This is a relevant action grammar; it does not prove this game's timing or artwork quality. |
| Separate the brief safe dodge opening from vulnerable recovery. | Nintendo's [shielding and dodging guide](https://www.smashbros.com/wii/en_us/howto/basic/basic06.html) distinguishes shielding from directional evasion and describes momentary protection. | Immediate translucency, split marks and three discrete remaining-window pips distinguish timed combat avoidance from the opaque spawn shield. The exact opacity, symbols and durations are local design choices. |
| Retain momentum routes with a place to practice and clear state feedback. | Respawn's [Arsenal firing-range design](https://www.ea.com/ea-play/news/arsenal-season-game-updates) explicitly provides agility practice for sliding, jumping, climbing and other traversal. [STRAFTAT's developer description](https://store.steampowered.com/app/2386720/STRAFTAT/) establishes quick arena confrontations and changing environments. | Keep existing paid Slide, slide jump, air turn, fast-fall landing and wall routes. Neither source establishes Melee frame data or a causal proof of exact H.E.X. tuning. |
| Give existing native keys longer visible holds. | The above action grammars require readable, distinct actions; no cited source specifies these H.E.X. timing numbers. | The user directly requested slower animation. Holds are measured against native keys and 30 FPS sampling, then inspected in native captures. Human preference and continuous gameplay quality remain separate. |

Primary pages above were opened again on October 9. Their descriptions establish
the referenced techniques; they do not establish causal balance or fun for this
game. The parent [reference record](../REFERENCE-IDENTITY-REFINEMENT.md) retains
the broader Melee, Apex/Titanfall, STRAFTAT, Noita and Magicka adaptation context.

## Source contract

Ground walk cadence now caps at 2.0 cycles/s; sprint and wall travel cap at
2.5 cycles/s. Native contact keys hold 5/16 of a cycle and neutral transitions
hold 3/16: at the caps that gives 156/94 ms for walking and 125/75 ms for
sprinting. Actual distance still drives the phase below the caps, and blocked
bodies do not march in place. Speed, steering, input and simulation are unchanged.

`PixelAerialPose.pose_ticks` derives a pure physical pose phase from actual
vertical velocity for tucked bodies. A fresh accepted impulse starts at the
opening key regardless of the global render clock. Charged lift holds that
opening slightly longer; this is deliberately not claimed as exact elapsed
action time. Slide jumps need no nonexistent cooldown reset. Wall exits use
their actual descending velocity. The last descent key holds without looping;
fast-fall selects it immediately. Landing and forced control still win at once.

Ball key boundaries are 9, 21 and 33 nominal 60 Hz units (150, 350 and 550 ms
of the phase). A normal short jump does not last long enough to show all four
keys: the actual landing takes priority. These are nominal phase windows, not
guaranteed minimum screen holds. Landing or interruption can shorten or omit a
later key; an ordinary jump may briefly show or skip the inverted key. The
compact ball remains the action silhouette throughout. Double jump keeps the reverse rotation
and deeper folded limbs through descent using the accepted hop origin, even
when the public action changes to `fall`. Reduced motion holds the tuck.

Flight uses its actual consumed paid budget, with 200 ms held wing keys.
Original outer native strips move by at most three pixels; torso and face
remain fixed. The four flight races still use an ordinary first jump and a
fresh second Jump press followed by held flight. There is no generic wing graft,
new texture, infinite budget or protection attached to flight.

Timed dodge body alpha is 0.62 throughout precisely the authoritative protected
window. The ordinary opaque body returns on the first vulnerable sample, while
the action may still be recovering. Split markers remain opaque, and 3/2/1 pips
show the remaining protection budget. Spawn protection keeps precedence, an
opaque body and its separate shield shape. Both effect modes have the same
boundaries; there is no flashing, smoothing, ghost body or protection tail.

Original artwork, hurt bodies and all state remain unchanged. This is assembled
native art, not newly authored complete animation cycles. Independent aerial
casting hands remain incomplete; existing spell effects and aiming still work.

## Qualification

The new runtime identity is `p59-a289f67c1acf`, protocol 59, with 3,199 canonical
production records. SHA-256:
`a289f67c1acffafad54e0be64365e947b9135d1c730e3802acd54566eeb99fb6`.

- [Focused regression](animation-followup-focused.json): nine suites,
  3,018,786 assertions, zero failures. The first continuity run's 1,344 obsolete
  global-clock expectations remain preserved; its replacement checks real
  vertical phase and paid flight progress, with all original matrices retained.
- [Final native review](animation-followup-native-review.md): 21 images,
  including all 30 identities, normal/reduced states, a full wing-key sequence,
  exact protection boundaries, and real admitted floor pixels at 1x and 75% zoom.
  The first terrain board's clipped fixture labels were repaired. Its 19 other
  images are byte-identical to the final capture and the two changed images
  were individually re-reviewed. Fine costume/pip detail remains compact at 75%.
- [Independent protection review](animation-followup-protection-review.md)
  confirms exact phase semantics and actual render-path propagation. Movement
  review also checked control priority, flight expiry, geometry-cache isolation
  and the new cadence's 30 FPS key dwell. No simulation changes were needed.
- [Fresh Full gate](full-animation-followup-v1.json): 227 suites,
  5,729,341 assertions, zero failures and zero stderr; clean import, canonical
  identity and 120 Hz-configured startup passed on this source.
- [Actual Bootstrap/input journeys](animation-followup-journeys.json) passed on
  the complete matching source hash:
  12 advanced routes / 7,751 checks and 192 independent travel/aim samples plus
  24 paid cast-transition routes / 11,547 checks. The latter also exercises
  three focus-loss and three low-resource cases. Both have zero stderr. Receipts:
  `.godot/movement-advanced-animation-followup-v1/receipt.json` and
  `.godot/movement-cast-animation-followup-v1/receipt.json`.

- [Windows package receipt](../../exports/hex-animation-20261009/receipt.json):
  exact-source export, executed content summary, all-30 pixel/action-key admission,
  native startup and safe close passed. The portable contains 30 champions,
  24 runtime spells, 63 reactions and 12 weave positions with chemistry enabled.
- [Independent archive verification](animation-followup-portable-verification.json):
  all nine unique payload checksums and all ten decoded ZIP members match;
  complete source hashes agree before and after export. The launcher explicitly
  enables `--fullbody-art --pixel-cast`, and native logs prove that mode was
  admitted. The ZIP is 127,615,418 bytes (121.7 MiB). PCK SHA-256:
  `8e7937d8c8a97e5bf60a092a8def83a5e5372ab3d348fddb2d7f74a3f4d10577`.
  ZIP SHA-256:
  `467e415e0bea29a42072926a4dfd695edef3c2f4c7a3d87ca11979d93454caac`.

[Play the extracted build](../../exports/hex-animation-20261009/windows/PLAY-HEX.cmd)
or [extract the complete ZIP](../../exports/hex-animation-20261009/HEX-p59-a289f67c1acf-Windows-x64.zip)
and run `PLAY-HEX.cmd`. The [preceding portable](../../exports/hex-six-elements-20261009/windows/PLAY-HEX.cmd)
remains intact as a fallback. This is a local package, not a public release or a
new installer.

Root serialized all engine runs; three agents cross-reviewed the changes. The
preceding source copies, failed expectation run, first native annotation defect
and original qualification remain preserved under `.godot/` and earlier records.
Packaging review also closed a verifier gap that could accept skeleton mode,
added unique/exact checksum coverage and compared the executed full source hash.
Human continuous-motion feel, balance, dedicated animation artwork, dense-load
performance and physical multiplayer remain separate product acceptance gates.
