# H.E.X. tactics handbook

This is the continuation guide for the **web tactics game, release 45**, published on 20 October 2026 at [hex.onetruepath.chatgpt.site](https://hex.onetruepath.chatgpt.site). In the GitHub monorepo it lives in `tactics/`. The repository root contains the separate original Godot game. They share a world and characters, not executable rules or save formats.

The shipped baseline is Sites source commit `947019572508ad0e20bb1dbbfe19c0ebeeee7148`. The GitHub import adds this handbook, portable development commands, raw art inputs, provenance and CI. Those additions do not change combat rules or deploy a new website version. The [source import inventory](../source-import-r45.json) records the original Git blobs and imported hashes; [handoff evidence](../handoff-evidence/README.md) records fresh setup and artwork reproduction separately from the historical release checks.

## Read by purpose

| Need | Start here |
|---|---|
| Understand the experience and design constraints | [Game design](GAME-DESIGN.md) |
| Rebuild the combat, progression and multiplayer rules | [Mechanics](MECHANICS.md) |
| Find the responsible modules and state boundaries | [Architecture](ARCHITECTURE.md) |
| Preserve readable decisions, controls and phone layouts | [UX and accessibility](UX-AND-ACCESSIBILITY.md) |
| Match pixels, animation, terrain, speech and sound | [Art and audio](ART-AND-AUDIO.md) |
| Add a character, creature, spell, recipe or map | [Content pipeline](CONTENT-PIPELINE.md) |
| Install, run, migrate, build and publish | [Development](DEVELOPMENT.md) |
| Choose checks and interpret evidence honestly | [Testing and release](TESTING-AND-RELEASE.md) |
| Resume work with priorities and a ready-to-use brief | [Continuation](CONTINUATION.md) |
| Find current player-facing rules and mode overview | [Project README](../../README.md) |

## Authority and compatibility

1. Actual versioned resolvers, catalogues and validation functions define implemented behavior.
2. This handbook explains the current design and its implementation. A conflict with executable code is a documentation bug to investigate, not permission to silently rewrite old saves.
3. [Release 45 notes](../release-v45.md) and [its evidence](../release45-evidence/verification.json) qualify what was tested and published.
4. Older versioned documents explain history. In particular, early references to Confluence, scoring wells, respawning, single-element roles or earlier affinity budgets are not the present game's contract.
5. The original Godot specification applies to that game. The tactics adaptation has six ingredients, simultaneous exchanges, its own spell numbers and versioned save protocols.

Do not merge old resolvers into a new unversioned implementation. Current routes intentionally use different rules: Story 20, Tower 22 within the Tower 23 session protocol, and Arena 18. New encounters use `focused-v44`; saved profiles remain explicit. See the mode matrix in [Architecture](ARCHITECTURE.md).

## Reconstruction package

The checkout includes application/server source, lockfile, migrations, runtime art, authored data, tests, prompts, asset audits and the accepted raw inputs used by the current sprite packers. [Asset source instructions](../../asset-sources/README.md) distinguish deterministic packing from non-deterministic artwork generation. The browser game runs from committed runtime files; packing is not an install step.

No player saves, private seat keys, browser data, dependency caches, local database or hosting credentials are part of this source handoff. The hosting project identifier is configuration, not an access token. Public source availability does not create a new asset or software license; existing provenance and third-party notices remain applicable.
