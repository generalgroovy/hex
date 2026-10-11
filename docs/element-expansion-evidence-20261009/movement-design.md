# Wall contact and character depth

Status: implemented and locally qualified in `p60-6d80c3bce71e`; see [integration evidence](integration.md) for Full/native/package results. References and automation do not establish human fun, balance or sustained performance.

## Concrete problem

The released native-pixel route mapped wallrun to the fixed jump fallback. Actual wall-side attachment, tangent travel and blockage were therefore poorly distinguished from an ordinary airborne body. Its sparks and remembered walljump origin also used the floor anchor while the displayed body could be elevated. The simulation already provides the wall normal, surface, actual tangent, remaining timer and control priority needed to fix this presentation gap.

## Evidence and transfer

| Decision | Primary established example | Transfer boundary |
|---|---|---|
| Give wall attachment a visible wall-directed pose and contact plane. | [Respawn's controls interview](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right) describes wall-side view tilt, anticipatory tilt and the pilot's hand contacting the wall. It also describes observer-readable slide poses and reported improvement from landing feedback without changing movement code. | H.E.X. uses a tangent-facing original body key, bounded rigid lean and elevated contact marker. The camera remains stable. The 11-degree moving/7-degree braced limits are local visual candidates, not Titanfall measurements or proven usability optima. |
| Keep timing and counterplay visible without adding mobility. | [Respawn's official mobility note](https://forums.ea.com/blog/apex-legends-game-info-hub-en/evolution-collection-event-patch-notes/9464059) explains the value of learnable constraints and the risks of opaque extreme-angle momentum preservation. | The current paid, nominal420ms wallrun remains unchanged. Three surface-aligned marks expose only its remaining time; no protection, recharge, extra direction snap or extension is granted. The historical proposed tap-strafe removal is not a claim about Apex's current implementation. |
| Keep distinct action beats and stable depth/contact cues. | [The Matrix's filmmakers and cinematographer](https://theasc.com/article/flashback-the-matrix-cinematography/) describe choreographed action beats instead of flash-cut fighting, directional modeling light, and side lighting that reveals surface relief. | Existing art stays intact and the floor shadow remains separate from elevated contact. This is a presentation analogy, not evidence that cinematic slow motion or camera orbit belongs in a competitive top-down game. Root owns coherent world lighting/depth integration. |

These sources document shipped techniques and creator observations. They do not provide controlled evidence that these exact H.E.X. values improve learning, balance or retention. Native and human review remain necessary.

## Implemented contract

`PixelWallrunPose.is_attached` requires positive remaining wall time, a real surface ID, nonzero normal, living state and ordinary/slowed control, with no overriding dodge, anticipation or impact state. Fullbody's existing action-priority resolver must independently select wallrun. Unsupported/malformed attachment data retains the explicit pre-existing fallback.

The new descriptor reuses the character's complete original native walk-contact/neutral key at the true wall tangent. It rotates the complete body around the original foot registration; it does not split, rescale or reshape anatomy. Immediate aim remains exposed separately. Distance phase owns contact changes; blocked attachment holds the neutral contact key with a7-degree wall-side brace. Reduced motion holds that neutral contact key while retaining the actual wall-side lean (11degrees moving,7degrees blocked). Screen-vertical wall normals do not invent a sideways tilt. No independent painted wallrun or casting hands are claimed.

Static review caught a real camera-transform defect before promotion: both the new wall draw and the inherited aerial nonmesh draw replaced the caller's current draw transform and reset it to zero. The live Bootstrap uses that transform for its nonzero camera origin and75%zoom. Both draws now submit explicit rotated world-coordinate quads with original atlas UVs and never alter caller state. Before-copies remain under `.godot/element-expansion-baseline/movement-transform-repair/`. `tests/visual/test_pose_camera_transform.gd` is a native regression using the actual inherited Bootstrap camera helper, wall/ball/flight poses and a later sentinel. It compares the local draw-transform route to an external viewport-transform reference, checks the sentinel at its expected camera position and rejects leakage into untransformed coordinates. A fresh `--output=res://.godot/pose-camera-native-NAME` is required. This isolated Bootstrap drawing context does not claim a complete world battle capture.

Contact, sparks and the remembered release burst now use the displayed body anchor instead of its floor projection. The floor shadow remains independently grounded. The surface-aligned three-segment strip is stable, uses current wall time, and disappears on the exact detach/expiry/interruption sample. It is not a surrounding shield or protection icon. Sparks require actual planar motion; blocked attachment cannot continue scraping.

Files: `pixel_wallrun_pose.gd`, narrow Fullbody/PixelFlipbook adapters and draw dispatch, and Cartoon wall-contact methods only. Exact pre-edit copies are under `.godot/element-expansion-baseline/movement/`. Original atlases and the qualified fallback are untouched.

## Falsifiable qualification

`test_wallrun_presentation.gd` covers all30 current identities, eight cardinal/hex normals, both tangent signs, independent aim, normal/reduced keys, whole-body source/pivot/bounds, blocked state, forced control, defeat, walljump departure, invalid inputs, exact finite-budget boundaries and complete authority immutability. It must reject a detached timer-only pose and any new protection claim.

`capture_wallrun_readability.gd` produces eight native boards: contact-state and full-roster boards, normal/reduced, at1x and0.75x. It captures actual production drawing with source/atlas hashes and before/after state witnesses. Wall sections and states are arranged fixtures, not an executed input trajectory or a campus occlusion test.

Reject or revise the candidate if native review finds detached feet/contact, smeared identity, excessive leaning, ambiguous brace/protection, unsafe drawing outside recorded bounds, or lost projectile readability. Passing descriptors or screenshots does not establish continuous movement feel. Root's real movement journeys and the existing movement/network suites must retain their guarantees unchanged.
