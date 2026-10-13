# Optional coach terminal probe — unreproduced

The bounded three-offset probe passed its integrity checks but **did not reproduce the suspected same-tick avoidance/saved-victory issue**. Production remains unchanged; no wider search is authorized by this result.

Root checked-parse and the headless run passed with **14,831 checks and empty stderr**. All three offsets followed exactly the same complete recorded trace and stopped at tick **1411**, after a real early avoidance advanced the tactical coach from step 2 to step 3. Each encounter admitted **55 player Light Rapid casts, zero Spray casts and three rival casts**; final Health was **99,085 / 2,400**. Both the planned-finisher and terminal records are empty.

The actual introduction, paid movement-chain and mixed-hit prerequisites, normal paid encounter and early protected contact were covered. **No offset-specific finisher, terminal result, earned save, reloaded reward or frozen terminal callback was reached.** The 14,831 integrity checks therefore provide no terminal-completion evidence. Three identical pre-finisher paths are not three independent samples of the hypothesized terminal timing.

The source observation remains a hypothesis: the coach advances one lesson per new tick while a finished trial freezes later ticks. This probe does not establish a reachable player-facing failure at that boundary. Keep the game's observer unchanged unless separate ordinary-play evidence demonstrates the actual issue.

The archive preserves the exact executed helper and all 26 pinned inputs, source manifest/README, root wrapper, raw full traces, parser/runtime logs and independent review. The original source README retains its pre-run intended coverage; the receipt and this review state which branches actually ran. No progress file was created in the fresh output directory. No mechanics, resource, enemy-AI or guide-step assignments were introduced.
