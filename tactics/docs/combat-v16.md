# Combat 16: interceptions and readable areas

Rules 16 retains team elimination, permanent defeat within the battle, Flux springs, the simultaneous-wipe draw, and the 20-round draw. Historical rules 15 remain separate and keep their original spell footprints and resolution. Story affinity and learned signatures are unchanged.

## One shared flight clock

Movement completes before spells release. Every travelling spell uses a straight path from its actual post-movement position to its aimed hex, with the same normalized flight duration. Two projectiles intercept only when their positions are exactly equal at the same flight fraction strictly between release and arrival. Paths crossing at different times do not intercept. Two spells aimed at the same endpoint still land normally.

The geometry solver uses integer relative-motion cross-products, rather than frame sampling or a visual proximity threshold. Meetings are processed earliest first. All projectiles meeting at one location and time form one group. Consumed projectiles cannot participate again. Caster IDs, element ordering, nearest-hex ties, and event order are canonical, so input array order does not decide the outcome.

Offensive travelling spells can intercept allied or opposing projectiles. Stationary spells, healing/protection spells, walls, and an allied-target Radiant Bolt do not become projectile shields. Damage, hostile status, theft, or displacement spells are eligible when travelling.

## What a meeting does

A two-projectile meeting creates a seven-hex neutral field. Three or more projectiles create a nineteen-hex field. The visual meeting point can lie between hex centres; the field is centred on the nearest hex using the actual hex-plane distance, with a stable coordinate tie break.

The participating spell effects at their original targets are canceled. This includes original direct damage, healing, status, force, drain, theft, and line footprints. Flux and cooldown costs still apply. Explicit self-recoil and self-status effects still apply to the caster. No new spell is created, and the reaction cannot recursively launch projectiles.

All participating elements form one complete recipe. Identical elements produce that element's field rather than multiplying direct damage. Natural ground, existing fields, other arriving spells, and public elemental creatures still join the complete mixture at each affected hex. Thus Fire + Water creates Steam over plain ground but Hot Spring over Earth. A frozen Water projectile preserves Ice where the resulting field supports it. The field affects either team using existing bounded field mechanics; it does not acquire all the original spells' damage.

The public `clash` event contains participant caster IDs, exact fractional `meeting`, `flightFraction`, integer field coordinates, radius, canonical elements, and recipe. Original cast events retain their original aim. Rendering must stop intercepted projectiles at their meeting time and must omit their original target effects. Saved-state validation recomputes clashes from the public cast trajectories and rejects altered participants, time, point, recipe, radius, missing meetings, and duplicated meetings.

## Area choices

Direct damage, costs, cooldowns, affinity scaling, and access thresholds are unchanged. Existing burst radii grow by one: small bursts cover nineteen hexes and large fields cover thirty-seven. Remote rings grow by one radius while retaining their safe inner hole. Fans gain one hex on each side, and walls span five hexes. Self-centred rings retain their original radius.

Frostbite, Lightning Flash, Cleansing Tide, and Thunderclap now cover seven hexes. Ember, Water Jet, Stone, execution spells, and other precision tools retain their one-hex roles. A broader spell can cover evasive landings or influence a route, but hostile areas still expose allies where their rules allow friendly fire. Ring interiors remain safe. Walls preserve occupied hexes and springs. Spell descriptions state the actual computed footprint, including the revised five-hex barrier.

Planning forecasts must use actual known allied movement, exclude consumed original footprints, retain frozen clash fields, and distinguish neutral fields from direct casts when countering public elemental creatures. Rival orders remain hidden. The AI rejects known allied self-interceptions instead of counting canceled direct damage as a useful attack; deliberate allied neutral-field interception is currently a player technique rather than an authored AI policy.

## Verification and limits

Seventeen mechanics tests cover midpoint Steam, real three-cast Hot Spring, identical elements, exact fractional meetings, paths crossing at different times, shared endpoints, earliest consumption, three/six-way input-order invariance, support/self exclusions, actual post-movement origins, consumed line footprints, frozen collisions, natural substrate, paid costs/cooldowns/self-recoil, footprint size, planning warnings, and forged saved events.

Four bounded AI-versus-AI matches used the default squads, restored every authoritative result, and verified zero planned allied self-interceptions:

| Seed | End | Characters standing | Total damage events | Interceptions |
| --- | --- | --- | --- | --- |
| CLASH-TACTICS | Round 20 draw | 2–1 | 66 damage | 7 |
| SPRING-CLASH | Round 18, team 0 wins | 3–0 | 109 damage | 11 |
| RUINS | Round 15, team 0 wins | 3–0 | 63 damage | 9 |
| WATERLINE | Round 20, team 0 wins | 3–0 | 107 damage | 13 |

The four matches took approximately 8.8–20.5 seconds each on the development host while other work ran. These are deterministic mechanical checks, not human pacing, competitive balance, or physical-phone performance evidence. Interception lengthens some exchanges and three of these four matches reached elimination; the remaining match reached the explicit draw limit. Broader areas increase positional influence without raising individual damage, but their aggregate balance still benefits from human playtesting with different loadouts and affinity budgets.
