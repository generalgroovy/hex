# FLUX delegation packet
Status: PREPARED, NOT DISPATCHED. Prepared 2026-09-20.
This is an external handoff packet, not a second implementation queue or a runnable game.

## Start three tasks, not every task at once

| Task | Where / recommended effort | Start condition | Prompt |
| --- | --- | --- | --- |
| Integration lead | Local Codex, GPT-6 Astra / High | Start first | 02-CODEX-INTEGRATOR.md |
| Element visual pilot | ChatGPT, a reasoning-capable mode plus image generation where available | Start alongside lead | 05-CHAT-VFX.md |
| First-four chemistry review | Separate ChatGPT reasoning task | Start alongside lead | 06-CHAT-CHEMISTRY.md |
| Runtime specialist | Lead-managed Codex subagent, inherit model / High | Lead grants exact file ownership | 03-CODEX-RUNTIME.md |
| Independent reviewer | Lead-managed read-only Codex subagent / High | Candidate and evidence exist | 04-CODEX-REVIEW.md |
| Motion template review | Separate ChatGPT task | After first visual direction is chosen; source-sheet critique can start earlier | 07-CHAT-ANIMATION.md |
| Wellspring / player UX | Separate ChatGPT task | After chemistry review; use actual campus source | 08-CHAT-MAP-UX.md |
| Results integration | Existing local Codex lead / High | A return ZIP exists | 09-CODEX-INGEST-RESULTS.md |

Model/effort choices are recommendations, not measured FLUX model benchmarks. Keep account-configured settings unless the user selects a change.

## Inputs

Upload FLUX-SOURCE-PACKET.zip to the ChatGPT project/tasks and ask the task to unpack and inspect it. The ZIP contains these prompts, the shared contract, selected source files, historical evidence, actual screenshots, active body sheets and labeled concept references.
If archive access is unavailable, extract it locally and upload 01-SHARED-CONTRACT.md, 11-AUDIT-SNAPSHOT.md, and the task-specific files listed in the prompt; use .txt copies of source files if the UI rejects .gd.
A normal ChatGPT project does not automatically read C:\Users\sende\Projects\flux. A source manifest and explicit acknowledgment prevent imaginary repository access.

Local Codex must inspect the live checkout. A ZIP snapshot is never a reason to overwrite newer source. The archive is selective and does not contain a buildable project.
Archive manifest hashes prove copy identity, not a newly executed Godot test.

## Scope and returns

Preparation changed no game files. Do not start more than two write-owning subagents under one integrator. Only that integrator schedules shared Godot/import/test/capture/profile/export operations.
Each chat delivers one ZIP named FLUX-<TASK>-v1.zip with HANDOFF.md and manifest.json; use 10-HANDOFF-SCHEMA.json. Save returned ZIPs next to this folder in HEX Handoff and send their paths to the existing lead. A shared-folder upload does not automatically notify or run another task.

Suggested results: FLUX-VFX-v1.zip, FLUX-CHEMISTRY-v1.zip, FLUX-ANIMATION-v1.zip, FLUX-MAP-UX-v1.zip.
Each return must name the input packet/source hashes and clearly separate proposal, offline preview, static check, Godot run and human acceptance.
Do not attach a filename for an asset that was not actually produced.

## Documentation consulted

Official OpenAI guidance informed explicit delegation, shared source context and bounded verification; project-specific constraints come from FLUX.
- https://learn.chatgpt.com/docs/projects
- https://learn.chatgpt.com/docs/agent-configuration/subagents
- https://developers.openai.com/api/docs/guides/latest-model

