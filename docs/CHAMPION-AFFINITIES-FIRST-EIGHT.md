# Champion affinity contract — first-eight phase

Status: **design-locked migration target**. The currently executable champions also obey this rule in `foundation_champions_v1.json`.

Every champion receives exactly **3 innate affinity points** during the first-eight phase and owns **two or three** affinities. Affinity points define alignment without creating a hidden elemental damage wheel.

Two-affinity specialists distribute the three points as **2 + 1**:

- `2` = primary/dominant affinity;
- `1` = secondary affinity.

Three-affinity generalists distribute the same budget as **1 + 1 + 1**. They
gain more reaction/build routes but no strength-2 discount. This is a normal
bounded profile, not a Treevor-only exception.

No current champion receives `3` points in a single element. The three-point budget is for distribution across affinities, not mono-element specialization.

Affinity combinations may repeat when body, kit, geometry and economy create a
different play pattern. Forcing unique pairs would make roster identity depend
on combinatorial bookkeeping instead of gameplay.

Only the currently promoted element families may receive affinity points during this phase:

`Earth, Fire, Water, Wind, Ice, Charge, Light, Dark`

`Spirit`, `Chaos`, `Gravity`, and `Time` remain runtime-gated until the first-eight fundamental chemistry acceptance gate. Existing concepts may reserve one of those identities, but the gated point is omitted rather than silently converted to a first-eight family. Legacy `Void` maps to Chaos where the concept means raw unreality; it never aliases Dark/Death.

Sources and rollout contracts:

- machine-readable roster: [`content/champions/champion_affinities_first_eight_v1.json`](../content/champions/champion_affinities_first_eight_v1.json);
- implementation order and acceptance: [`../.agent/OVERHAUL-IMPLEMENTATION.md`](../.agent/OVERHAUL-IMPLEMENTATION.md) and [`FOUNDATION-SYSTEMS.md`](FOUNDATION-SYSTEMS.md); the older champion-affinity implementation file is historical only;
- identity compatibility migrations: [`content/champions/champion_identity_migrations_v1.json`](../content/champions/champion_identity_migrations_v1.json);
- chemistry implementation: [`ELEMENT-REACTIONS-IMPLEMENTATION-PLAN.md`](ELEMENT-REACTIONS-IMPLEMENTATION-PLAN.md).

## Strength semantics

Affinity strength is deliberately bounded and readable.

| Strength | Meaning | Current mechanical consequence |
| ---: | --- | --- |
| **0** | No innate affinity | No affinity-based build discount for that element. |
| **1** | Secondary affinity | May claim up to 1 point of an ability's authored `affinity_discount`. |
| **2** | Primary affinity | May claim up to 2 points of an ability's authored `affinity_discount`. |

The effective active-build discount is:

```text
effective_discount = min(champion_affinity_strength, ability.affinity_discount)
effective_active_cost = max(1, authored_points - effective_discount)
```

Existing foundation actives currently author `affinity_discount = 1`, so the weighted model **does not silently rebalance the current 13-point foundation loadout**. Primary affinity strength becomes mechanically distinct as later abilities deliberately author a larger affinity-discount ceiling.

Affinity strength does **not** automatically multiply raw damage, status magnitude, reaction damage, reaction radius or reaction duration. Those remain explicit ability/reaction parameters with visible counterplay.

## Roster

| Champion | Weighted affinities | Identity |
| --- | --- | --- |
| **Oh Tipi** | **Water 2 · Charge 1** | Strong current/water specialist with secondary conductive alignment. |
| **S. Wayne** | **Dark 2 · Light 1** | Eclipse tactician leaning toward concealment/attrition while retaining Light boundary play. |
| **The Red Baron** | **Fire 2 · Ice 1** | Thermal aerial controller with Fire as the dominant pressure element. |
| **Steezo** | **Charge 1 · Fire 1 · Light 1** | Volatile engineer combining acceleration, detonation and readable illumination without a dominant affinity. |
| **Treevor the Mason** | **Earth 1 · Wind 1 · Fire 1** | Masonry, shaping and combustion liability are equally structural to the concept. |
| **Oll' I** | **Earth 1 · Fire 1 · Light 1** | Heavy werewolf breaker combining mass, aggression and visible protective pressure. |
| **Fluup** | **Wind 1 · Charge 1 · Ice 1** | Storm bruiser combining airflow, electrical landing and cold control. |
| **Wa Bidi** | **Charge 1 · Wind 1 · Fire 1** | Fast route specialist combining acceleration, vector control and combustion. |
| **Grace Reava** | **Wind 1 · Water 1 · Light 1** | Aerial sylph duelist combining airflow, fluid redirection and luminous support. |
| **Waka Aren Si** | **Charge 2 · Light 1** | Precision device engineer with Light as optical/support alignment; technical migration key remains `nico_lai` until the explicit compatibility slice. |
| **Spai Si** | **Wind 1 · Earth 1 · Light 1** | Demon redirect duelist balancing pressure, grounded geometry and deceptive radiance. |
| **Leaf the Hidden** | **Water 1 · Earth 1 · Light 1** | Grove/route shaper combining growth conditions, terrain and reveal/recovery play. |
| **Ha Rekt** | **Ice 1 · Wind 1 · Fire 1** | Wyrmborn thermal hunter balancing cold control, aerial routing and heat reversal. |
| **Dr. Apex** | **Earth 1 · Light 1 · Water 1** | Stoneborn combat medic combining fortification, recovery and cooling/displacement. |
| **Haara** | **Light 2 · Wind 1** | Nymph bloom/resource planner; Spirit remains a deferred future route. |
| **Hesus Christo** | **Earth 2 · Water 1** | Renewal vanguard with structure first and Water-assisted rebuilding. |
| **Grimm Bow** | **Earth 2 · Water 1** | Troll terrain archer whose reserved Chaos identity is omitted—not converted to Dark—until Chaos promotion. |
| **Biggy Bob** | **Earth 1 · Fire 1 · Light 1** | Forge-line masonry breacher balancing structure, heat and visible protection. |
| **Jan Wicked** | **Ice 1 · Dark 1 · Charge 1** | Black-ice pursuit specialist combining control, attrition and acceleration. |
| **Ba Djoh** | **Earth 1 · Fire 1 · Water 1** | Large terrain breaker combining mass, heat and displacement. |
| **Urzh** | **Earth 1 · Fire 1 · Charge 1** | Stoneborn bulwark combining grounding, heat and conductive pressure. |
| **Don Doko Don** | **Earth 1 · Fire 1 · Water 1** | Dwarf forge-rhythm shaper using structure, heat and Steam-capable Water; `donnok` is a migration ID. |
| **Djonah Thaan** | **Dark 1 · Charge 1 · Fire 1** | Vampire pursuit controller combining grave pressure, acceleration and heat. |
| **Unnamed Angel** | **Light 2 · Wind 1** | Unapproved placeholder; Spirit remains deferred. |

## Validation invariants

For every current champion:

```text
sum(affinity_points) == 3
all affinity point values are positive
all affinity IDs are known and runtime-enabled
```

For every champion:

```text
affinity_count in [2, 3]
two affinities -> point distribution == 2 + 1
three affinities -> point distribution == 1 + 1 + 1
duplicate combinations are legal when the full champion play pattern differs
```

The compatibility `affinities` list remains in champion/loadout JSON during migration, but `affinity_points` is the authoritative strength representation. Validators require both representations to contain the same element IDs so they cannot drift.

Waka Aren Si and Don Doko Don are the canonical player-facing names. Technical
keys `nico_lai` and `donnok` are temporary compatibility details and migrate only
through the explicit versioned identity contract; old saves/replays resolve
through a documented adapter or fail clearly rather than silently selecting
another character.

## Gameplay intent

The weighted system adds identity without creating matchup multipliers. A primary affinity should mean **deeper access/efficiency in authored content**, while a secondary affinity establishes a meaningful second reaction route.

Examples:

- Oh Tipi's **Water 2 + Charge 1** emphasizes Water abilities while retaining Conductive Flood synergy;
- S. Wayne's **Dark 2 + Light 1** emphasizes concealment/attrition while preserving Penumbra boundary play;
- Don Doko Don's **Earth 1 + Fire 1 + Water 1** supplies broad forge, Steam and terrain routes without a strength-2 discount;
- Fluup's **Wind 1 + Charge 1 + Ice 1** trades a dominant discount for airflow, electrical landing and cold-control routes;
- Waka Aren Si's **Charge 2 + Light 1** emphasizes device/conductor play with optical support;
- Ha Rekt's **Ice 1 + Wind 1 + Fire 1** trades a dominant discount for cold control, aerial routing and thermal reversal.

The wider reaction network still comes from loadout choice, teammates and manipulating existing map states rather than giving each champion exclusive ownership of their affinity reactions.
