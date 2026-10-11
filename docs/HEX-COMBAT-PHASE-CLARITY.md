# H.E.X. — combat phase clarity

Status: locally validated playtest checkpoint, 2026-09-28; return for human feedback.

Build: `p56-0f3f12334cff` (2,940 production records). Open
[PLAY-HEX.cmd](../exports/hex-combat-clarity-20260928/windows/PLAY-HEX.cmd), or extract
[the portable ZIP](../exports/hex-combat-clarity-20260928/HEX-p56-0f3f12334cff-Windows-x64.zip).
Keep EXE/PCK together. Focused regression passed 7 suites / 77,497 assertions;
42 native frames cover seven pairs in three phases and both effects settings,
with 12 representative frames visually reviewed. Separate Windows export,
identity-consistent native art boot and safe close passed.
[Fresh receipts and review limits](combat-phase-evidence-20260928/README.md).

The user asked to continue after the responsive-combat checkpoint. Native review
there identified subtle warning/active contrast, especially pale fields on the
beige ground. Preserve `p56-eefcd94291c1` as the verified gameplay fallback.

This slice changes only the seven revised reaction materials: Thermal Shock,
Plasma Arc, Solar Flare, Superconduct, Arcflash, Radiance and Penumbra. It does not
change their combat policies, geometry, payment, phases, timing or eligibility.

| Phase | Presentation |
|---|---|
| Forming, harmless | Smaller dark-ink material stamp, element-colored fill and full warning boundary; avoids Light's sand-colored outline disappearing into terrain |
| Active | Full-size bright material stamp and existing active boundary |
| Decaying, harmless | Tiny dim material remnants, weaker fill and boundary |

The same static size/contrast difference survives Reduced Effects; it does not
rely on flashing or movement. No additional particle, geometry query, mark count
or draw call is added. Stamps shrink inside their original cells; only authority
decides which hexes are affected. Other elements, utility pairs and cover keep
their existing visual grammar. No new textures or generated bitmap assets.

## Acceptance

Focused presentation/chemistry/movement regression, fresh native captures of all
three phases in normal/reduced settings, and separate Windows export/identity/
art-admission/safe-close checks passed. The preceding gameplay checkpoint passed
the full 171 suites / 1,531,093 assertions; the full suite was not rerun for this
presentation-only continuation. Its fresh evidence is separate.
Human warning recognition, dense overlap/color-vision, performance and physical
two-PC acceptance remain open. Return for feedback after this small continuation.

The first native candidate was rejected even though its style tests passed:
Radiance's warning was too close to the ground color. A fixed dark warning ink
and explicit luminance bounds now guard that case. Preserve the failed visual
receipt and representative frame alongside the successful rerun, not as acceptance.

For the playtest, cast Light + Light and Fire + Light at a nearby empty endpoint,
then repeat with Reduced Effects. Check whether the forming region is recognizable
before it becomes bright/active, and whether the dim remnants clearly read as
harmless. Repeat the movement route from the combat checkpoint; no new tuning
has changed that route or its resource cost.
