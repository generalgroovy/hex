# AI assistance and delegation for FLUX

Status: researched and prepared locally on 2026-09-09; five reusable roles validated, one local model downloaded and verified; game Full and isolated Windows checkpoint passed. No commit, push, installer release or hosted-model benchmark implied.

## Decision

Use the existing hosted coding agent for repository integration, a small number
of explicitly owned specialist slices, the built-in image generator for raster
candidates, and one small offline coding advisor for isolated questions. Do not
add a second autonomous editor or a collection of competing agent frameworks.
The user clarified that both reusable agent instructions and downloadable model
weights were wanted. These are different deliverables: role files are reusable
instructions; Qwen is the actual downloaded model.

The weekly stopping floor is now **33% remaining**, superseding earlier active
40%, 50% and 75% floors. The primary agent reads the account usage tool, reserves
validation/documentation headroom, and stops starting new work before crossing
that floor. Parallel agents share the account allowance; local inference does
not make the surrounding hosted integration/review work free.

## Selection table

| Resource | Useful FLUX role | Decision and evidence boundary |
|---|---|---|
| Existing hosted Codex model | Integrate gameplay, authority, content and tests | Keep the user's selected model for this wave; no silent model override or additional paid API setup |
| GPT-6 Astra / GPT-5.6 Sol | Candidate lead for difficult cross-system changes | Astra is documented for demanding multi-step work; Sol is available here as the general agentic workhorse; compare on FLUX before claiming a winner |
| GPT-5.6 Terra / Luna | Candidate narrow read/review workers | Consider Terra for bounded inspection and Luna for simple repeatable tasks; not selected or benchmarked in this wave |
| Native subagents + project role files | Independent feedback, sandbox, art, runtime and review | Prepared five roles; actual current delegation used bounded tool prompts; automatic role-file loading has not been runtime-tested |
| Native image generation | Charming pixel-art candidate production | Already available; generated one Small South stand/contact candidate, held for failed transparency and arm phases |
| Qwen2.5-Coder-1.5B-Instruct Q4_K_M | Offline suggestions on tiny code excerpts | Downloaded first-party weights, about 1.12 GB; checksum verified; inference deferred for insufficient free RAM |
| Qwen2.5-Coder-3B / Qwen3-1.7B | Possible later local comparison | Not downloaded: reviewed artifacts need more memory; see setup report for differing license and quantization choices |
| OpenAI gpt-oss-20b | Open-weight local reasoning on a larger host | Official 21B total / 3.6B active model; not downloaded on this memory-constrained laptop; no performance claim |
| New marketplace plugins | External accounts or specialist services | None needed for this wave; native tools already cover the scoped work; no plugin installed |

The hosted model guide and the subagent guide provide capability guidance, not
a FLUX benchmark. They are also not identical recommendation lists; model names
and availability should be rechecked when changing the selected model. Current
task-tool availability and explicit user choice take precedence over a copied
example configuration. [OpenAI model guidance](https://developers.openai.com/api/docs/guides/latest-model),
[OpenAI subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents),
[gpt-oss-20b](https://developers.openai.com/api/docs/models/gpt-oss-20b).

## Why this local download

The inspected machine has a Ryzen 3 7320U, four cores/eight logical processors,
7.28 GiB visible RAM, integrated graphics and roughly 48.5 GiB free disk before
preparation. Free RAM varied around 1.1-1.7 GiB. Memory headroom, not nominal
parameter count or disk capacity, is the immediate constraint.

The first-party Qwen coding repository offers Q4_K_M GGUF and an Apache 2.0
license. The selected file is 1,117,320,768 bytes. This is a conservative
engineering choice for this laptop, not evidence that a 2024 small model is the
best coding model in 2026. The model cannot inspect the checkout, browse, run
tests, use tools or apply edits in the prepared workflow. A useful small answer
still requires review by the integration owner.
[Selected model and variants](https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF),
[pinned file](https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/blob/f86cb2c1fa58255f8052cc32aeede1b7482d4361/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf).

The official portable llama.cpp Windows CPU archive is pinned to b10809, not a
mutable latest URL. Source inspection showed that this release's `llama-cli`
starts an internal server, so the wrapper selects direct `llama-completion`
instead, with explicit local weights and offline mode. There is no added
service, firewall rule, PATH change or account setup. Offline configuration is
not a firewall sandbox or packet-capture proof.
[Pinned release](https://github.com/ggml-org/llama.cpp/releases/tag/b10809),
[completion runner](https://github.com/ggml-org/llama.cpp/blob/b10809/tools/completion/README.md),
[CLI server source](https://github.com/ggml-org/llama.cpp/blob/b10809/tools/cli/cli-server.h).

The model and archive hashes match publisher metadata; all 51 extracted runtime
files match the verified archive. Runtime version startup and ten launcher
safety tests pass. The first inference attempt stopped before model startup at
1.39 GiB free RAM, below the unchanged 1.5 GiB guard. Therefore no local answer,
tokens-per-second, quality or coding competence result is claimed.
The complete pins, licenses, commands, side-effect record and limitations live
in [LOCAL-AI-SETUP](LOCAL-AI-SETUP.md). Installation is outside the game checkout
under `%LOCALAPPDATA%\FLUX-dev\local-ai`; it is not shipped to players.

## Delegation architecture

One primary integration owner and at most three workers fit the currently
available four total agent slots. Prefer separate modules or read-only review;
give shared-file writers exact function ownership. Serialize Full tests,
imports, exports, render batches and local inference on this small machine.
Do not duplicate the entire repository/history into every prompt.

OpenAI documents project-scoped custom agents as `.codex/agents/*.toml`, with
`name`, `description` and `developer_instructions`. The five prepared roles omit
model, effort and permission overrides so they inherit the user's settings.
The reviewer is instructed to be read-only; that instruction is not a separate
OS sandbox. Subagents can save wall-clock time for independent work but consume
additional tokens, so breadth must earn its integration cost.
[Agent configuration and tradeoffs](https://learn.chatgpt.com/docs/agent-configuration/subagents).

| Reusable role | Owns | Must return |
|---|---|---|
| `flux-runtime` | One simulation/network/performance slice | Determinism/compatibility proof, measured load and regression tests |
| `flux-feedback` | One VFX/UI/audio feedback slice | Real event semantics, bounded resources, normal/reduced rendered evidence |
| `flux-sandbox` | One practice/teaching/interaction loop | Discover-try-understand-retry flow, actual phases, counters and ownership |
| `flux-art` | One isolated candidate folder | Untouched source, prompt, registration/contact/native-scale review; accept or hold |
| `flux-reviewer` | Read-only independent diff review | Concrete risks, smallest fixes and missing acceptance evidence |

Role instructions are in [../.codex/agents](../.codex/agents). They are reusable
tools for the existing single queue, not a replacement design plan. Do not
add roles merely because a model name exists.

### Dispatch contract

Every worker receives: objective; exact allowed files/functions; frozen gameplay
invariants; acceptance tests; owned evidence directory; forbidden concurrent
operations; and a stop condition. It returns a short finding/diff summary plus
paths, commands/results and remaining limitations. The owner reviews the diff,
resolves shared integration, runs the checkpoint suite and writes the receipt.
Workers must not commit, push, install services, run model-generated commands or
delegate further without a bounded reason approved by the owner.

## Current executed wave

| Lane | Work | Result / acceptance |
|---|---|---|
| Local tooling | Compare, pin, download, verify, wrap | Complete download and ten guard checks; inference safely deferred |
| Combat feedback | Stop borrowed Beam/Spray/Field names and invented statuses | Implemented; 4,359 focused assertions and six actual 720p captures passed |
| Crucible coach | Teach depositing casts and actual local reaction phases | Integrated observer; 4,086 assertions and 13 actual-gameplay captures passed |
| Independent review | Compare all 36 compact descriptions with kernel | Found missing Crystal Lens capacity caveat; corrected before checkpoint |
| Small neutral art | One same-board stand/walk-A/walk-B source attempt | Held: opaque painted checkerboard and nonalternating arm phase; no runtime promotion |
| Integration owner | UI gating, suite registration, documentation, Full/export | Full88/441,503 and isolated Windows EXE/PCK boot passed; see checkpoint below |

[Integrated clarity checkpoint and test build](DELEGATED-CLARITY-CHECKPOINT.md).
The five TOML roles parsed successfully; ten local-model guard tests and the
pinned installation verifier were rerun by the integration owner. A guest
missing its own replicated actor initially borrowed the host fallback; the
integration test caught it and the explicit identity guard now passes.

The coach adds understanding without a new resource, reward or mechanic. It is
limited to living local players in Crucible free practice, hidden during menus,
rounds or spectating. It observes exact authoritative lifetimes and distinguishes
harmless matter, harmless formation, active effects and harmless decay. Oldest
deposit ownership is not a claim that both contributing spells were local.

## Next slices in the existing queue

| Order | Small next deliverable | Gate before expansion |
|---|---|---|
| R2a | Repair Small South genuine opposing arm contacts and transparent source | Same-board anatomy, alpha, native 58px registration and live gait review |
| R2b | Complete Small eight headings, then Middle and Large | No per-pose scaling; all action mappings, exact facing and real A/B contacts |
| B5 / R3 | User template acceptance, then one unique race/character page | Complete page review; no palette-only identity clones |
| Feedback follow-up | Readable positional audio vocabulary for cast/contact/chemistry | Small bounded pool, volume/mute, priority, interruption/reduced sensory load and real listening acceptance |
| R4 | Larger Wellspring with distinct practice loops and safe travel | Worldbone/spawn/camera/minimap agreement; routes tested for all body roles |
| R5 | Wider chemistry footprints and interactive tactical trials | Exact extent rendering, finite overlap budgets, replay and eight-player load proof |
| B6 / delivery | Fix source readiness, refresh Windows payload/installer | Isolated installed boot/update/close plus real friend host/join acceptance |

Audio is currently absent and remains a discrete next slice; this wave does not
pretend text labels constitute an audio implementation. Existing 120 Hz
configuration does not establish sustained 120 FPS under eight-player stress.
No larger map, all-cast art completion or new installer is claimed here.

## Method and uncertainty

Research combined current primary OpenAI/Qwen/llama.cpp documentation with local
hardware inspection, source review, published artifact hashes and bounded
validation. No GPT Store downloads, third-party agent marketplace dependency,
cloud credentials or cross-model benchmark were used. The final choices optimize
for recoverability, integration cost and the player's ability to understand
actions, rather than number of installed tools or generated assets.

A future model comparison should use the same three small FLUX tasks: identify
a misleading event label, propose edge tests for a pure observer, and review an
animation acceptance failure. Score correctness, invented facts, review effort,
elapsed time and allowance cost. First establish that the local model actually
loads under safe memory conditions. Do not compare a quick suggestion with a
fully integrated, tested change as though they were equivalent outputs.
