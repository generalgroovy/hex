# Prepared tactical positions

These four reproducible positions check whether public information changes a useful tactical answer. They compare a small, stated set of plans against a fixed opposing plan. They do not establish globally optimal play, roster balance, long-term strategic depth, or player enjoyment.

Run:

```powershell
node --experimental-strip-types --test tests/tactical-positions.test.ts
```

| Position and immediate objective | Comparison | Observed consequence |
| --- | --- | --- |
| Clear a guarded enemy with 1 HP from a well | Treevor's Stone versus Shatter | With no Ward, both defeat the holder, but Stone costs 2 Flux and Shatter costs 4. With Ward 3, Stone leaves the holder alive to score; Shatter bypasses Ward and earns the defeat point. |
| Clear the same well with only 2 Flux | The same Stone/Water Jet kit on Treevor and Grace | Treevor can afford Stone at 2 but not Water Jet at 3. Grace can afford Water Jet at 2 but not Stone at 3. Each affordable option defeats the guarded holder. Affinity changes a legal response without restricting spell ownership. |
| Maximize Oh Tipi's health after this exchange, starting at 2 HP | Mend versus Cleansing Tide | Without ailments, Mend ends at 5 HP and Tide at 4. With existing Burn 1 and Wither 1, Mend ends at 3 HP with Wither remaining; Tide ends at 4 HP, removes both ailments, and grants Wet. |
| Survive a fixed Ember aimed at a 1-HP well holder, then maximize this round's score | Guard on the well versus move away and Guard | On plain ground, holding is lethal; retreat survives without scoring. On existing Steam, holding survives and scores 1, while retreat still scores 0. Fresh Burn remains after holding, so the immediate point creates a problem to solve next round. |

The fixtures deliberately isolate the decision being measured. Other allies Guard, the rival's plan is fixed, and the test does not give a live player access to a hidden plan. Actual matches require predicting the opponent and accounting for the following rounds.

The source is `tests/tactical-positions.test.ts`. All **4 tests passed locally** against the v4 engine containing the complete 15-pair reaction catalogue. This is engine evidence; it does not substitute for browser interaction checks or paired human playtests.

Source fingerprints at that run:

- `lib/tactics.ts`: `abeed5ec76277081350b51b5eb8f643c8e7b819df1d4ca29205f41a0f2aa4802`
- `lib/spells.ts`: `7a4d157246339f858101f4417dc87664e35a778dc5a9dc316071dff343223f79`
