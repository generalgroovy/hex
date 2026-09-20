# Local AI development helper

Status: pinned download and safety checks verified locally, 2026-09-09; inference deferred by the free-memory gate; not part of the game build.

## Delivery status

One small coding model and one portable Windows CPU runtime are prepared outside the FLUX checkout. They are development aids only: neither is bundled with the game, connected to Godot, installed as a service, registered on PATH, or allowed to apply model-generated edits. No account, API key, paid inference, administrator access, or firewall change is required by the prepared workflow.

The first inference attempt was deferred before model startup because free RAM was 1.39 GiB, below the launcher's conservative 1.5 GiB gate. Download integrity and runtime startup are verified; model answer quality and useful coding performance are not yet established. A successful download or runtime version command is not a model inference test.

## Selection

The verified host is an AMD Ryzen 3 7320U, four cores/eight logical processors, integrated Radeon graphics with 512 MiB reported dedicated video memory, and 7.28 GiB visible system RAM. Approximately 48.5 GiB of disk space was free before download. Available RAM varied between approximately 1.1 and 1.7 GiB during preparation. These are local observations, not vendor performance claims.

| Model candidate | Official artifact reviewed | License label | Assessment for this host |
| --- | --- | --- | --- |
| Qwen2.5-Coder-1.5B-Instruct | First-party Q4_K_M GGUF, 1,117,320,768 bytes | Apache 2.0 | Selected. Small coding-specific advisor for test ideas and tiny excerpts. |
| Qwen2.5-Coder-3B-Instruct | First-party Q4_K_M GGUF, about 2.10 GB | Qwen Research | Not downloaded. Higher memory demand and a different license; not a drop-in Apache-licensed upgrade. |
| Qwen3-1.7B | First-party GGUF repository contains Q8_0, 1,834,426,016 bytes | Apache 2.0 | Not downloaded. More general-purpose; reviewed first-party repository did not supply Q4. Community quantizations exist but were not needed for this preparation. |

The quantization offerings, file sizes, and license labels come from the respective first-party repositories. Model weights consume memory in addition to context caches and runtime buffers; a file that fits on disk is not proof that it can run comfortably alongside the editor or game. The selection is a resource-aware engineering judgment, not a claim that this older small model outperforms newer models. No cross-model benchmark was run. [1][2][3]

The existing Ollama 0.30.6 client was detected. A model-inventory command unexpectedly launched its desktop application, server, and updater check. Only the processes created by that inspection were stopped; no Ollama installation or user settings were removed or updated. The prepared path instead uses the official portable llama.cpp bundle. Its v0.4.0 release points to nightly build b10809, which is pinned here rather than following an ever-changing latest URL. [4]

This llama.cpp version's `llama-cli` starts an internal HTTP server. The wrapper deliberately uses `llama-completion.exe`, the direct in-process text runner, with an explicit local model and `--offline`. It does not run `llama-cli.exe`, `llama-server.exe`, or an RPC server. [5][6]

## Installed files and provenance

Base directory on the prepared machine:

```text
C:\Users\sende\AppData\Local\FLUX-dev\local-ai
  downloads\llama-b10809-bin-win-cpu-x64.zip
  runtime\b10809\llama-completion.exe
  runtime\b10809\LICENSE-llama.cpp
  models\Qwen2.5-Coder-1.5B-Instruct\f86cb2c1fa58255f8052cc32aeede1b7482d4361\
    qwen2.5-coder-1.5b-instruct-q4_k_m.gguf
    LICENSE
  installed-manifest.json
  preparation-evidence.json
```

The runtime bundle also contains its supporting DLLs, utilities, and LLVM OpenMP license. Only the direct completion executable is selected by the launcher. The archive is retained so every extracted file can be verified against its original bytes before an inference run.

| Item | Pinned identity | SHA-256 |
| --- | --- | --- |
| Runtime ZIP, 18,407,457 bytes | b10809, commit `5266f24da75dc449bd56cbed7addb9c8e4a6a73e` | `9df3158ed228a641a4b127942d7f459f24c9e13f04682659d05c00c80099b6b5` |
| Model GGUF, 1,117,320,768 bytes | Qwen repository revision `f86cb2c1fa58255f8052cc32aeede1b7482d4361` | `cc324af070c2ecbfd324a30884d2f951a7ff756aba85cb811a6ec436933bb046` |
| Completion executable | Extracted from the pinned official ZIP | `63ba8391bfb721c0dc826d8e3a7c2691c912648e43666268a40c57847edae6d9` |

The archive digest was compared with the release asset metadata and published attestation page. The model digest was compared with the first-party Hugging Face LFS metadata. The GGUF magic header and all 51 extracted archive entries were checked locally. This is digest verification, not a claim that a separate cryptographic attestation-verification client was run. Licenses are retained alongside both artifacts. [7][8]

## Commands

Run in PowerShell 7.4 or newer from the FLUX repository; preparation used 7.6.5. The scripts discover the current user's Local AppData directory; another machine does not need to use the literal user path above.

Verify an existing installation without downloading or starting inference:

```powershell
pwsh -NoProfile -File .\scripts\local-ai-setup.ps1
```

Prepare or resume the pinned downloads on another Windows x64 machine:

```powershell
pwsh -NoProfile -File .\scripts\local-ai-setup.ps1 -Download
```

The installer resumes `.partial` downloads and preserves any existing file whose size or checksum does not match. It fails instead of overwriting a mismatched model or runtime. Updates require reviewing and deliberately changing the source pins; there is no automatic model/runtime update.

Run guardrail tests without loading model weights:

```powershell
pwsh -NoProfile -File .\scripts\local-ai-test.ps1
```

Ask for a short advisory answer when the game and tests are stopped and at least 1.5 GiB RAM is free:

```powershell
pwsh -NoProfile -File .\scripts\local-ai-ask.ps1 -Prompt 'Give three regression-test ideas for a purely visual projectile effect. It must not change authoritative simulation or network outcomes.'
```

For a selected text file rather than a command-line prompt:

```powershell
pwsh -NoProfile -File .\scripts\local-ai-ask.ps1 -PromptFile .\selected-excerpt.txt -MaxTokens 128
```

The excerpt is an explicit user-selected input, not automatic repository ingestion. The prompt is limited to 1,536 UTF-8 bytes. Generated output defaults to 96 tokens and cannot exceed 192 tokens through this wrapper. A long answer may be cut off at the cap; ask a narrower question rather than treating a truncated suggestion as complete. The context is fixed at 2,048 tokens, CPU generation and prompt processing use two threads, and GPU offload/repacking are disabled. The default timeout is 120 seconds, with a maximum of 180 seconds. The launcher's owned process tree is stopped on timeout or interruption.

`-SaveEvidence` additionally records the supplied prompt, answer, runtime log, resource sample, and execution metadata under the external `evidence` directory. Do not include secrets: prompts can be visible in process arguments while a run is active, and evidence explicitly persists them. Without this switch, the wrapper does not intentionally save prompts or answers. Offline mode is configured, not an operating-system firewall sandbox or a claim based on packet capture. [6]

## FLUX workflow and acceptance boundary

Use this model for inexpensive, isolated suggestions: a few test cases for a pure function, a short explanation of a pasted snippet, a checklist, or alternative wording. It has no shell, browser, repository-writing tool, network tool, or build/test tool. It cannot know unprovided FLUX state or verify current Godot APIs. Do not ask it to autonomously modify, migrate, or review the whole project.

The developer or primary coding agent must inspect every suggestion, implement useful changes deliberately, and run the relevant FLUX tests. No local-model output may become simulation authority, alter network results, or bypass visual acceptance. Do not run this helper concurrently with Godot, full test suites, asset rendering, or another local model on this machine. The wrapper refuses when it observes a Godot or completion process already running, but cannot prevent another application starting after its check.

A short successful response would establish only that the pinned model can load and produce text under the recorded conditions. It would not establish coding accuracy, architectural understanding, acceptable game behavior, or performance across different prompts. Those require task-specific review and independent validation.

## Verification record

Preparation was performed on 9 September 2026, Europe/Berlin.

The external `installed-manifest.json` records the pinned sources and local artifact paths. `preparation-evidence.json` records the observed hardware, digest checks, runtime startup, guard-test results, the deferred inference, and the temporary Ollama inventory side effect.

| Check | Result |
| --- | --- |
| Runtime and model download | Complete; one model only |
| ZIP/model published digest comparison | Passed |
| Extracted runtime files compared with verified ZIP | Passed, 51 files |
| GGUF magic header | Passed |
| Runtime version command | Passed: `0.4.0-dev (build 10809, commit 5266f24da)`, Clang 20.1.8, Windows x86_64 |
| Launcher syntax and guardrail tests | Passed: 10 checks, including oversized/UTF-8/blank prompts, token/time caps, low memory, and active Godot |
| Advisory inference | Deferred by 1.5 GiB free-memory gate; 1.39 GiB available at first attempt; no model started |
| Automatic repository edits, execution of model output, or game integration | None |
| Service, PATH, firewall, account, paid API setup | None |

The setup files are local working-tree additions. Nothing in this preparation establishes a Git commit, push, installer release, or deployment.

## Sources

All sources below were inspected on 9 September 2026. License names are recorded from the publisher; this document is not legal advice.

1. Qwen. [Qwen2.5-Coder-1.5B-Instruct GGUF model card and variants](https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF). Model repository last modified 12 November 2024 at the pinned revision.
2. Qwen. [Qwen2.5-Coder-3B-Instruct GGUF model card and variants](https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF), and [its license](https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/blob/main/LICENSE).
3. Qwen. [Qwen3-1.7B GGUF files](https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/tree/90862c4b9d2787eaed51d12237eafdfe7c5f6077) and [model card](https://huggingface.co/Qwen/Qwen3-1.7B-GGUF).
4. ggml-org. [llama.cpp v0.4.0 release](https://github.com/ggml-org/llama.cpp/releases/tag/v0.4.0), 4 September 2026; [linked build b10809](https://github.com/ggml-org/llama.cpp/releases/tag/b10809).
5. ggml-org. [Pinned CLI context implementation](https://github.com/ggml-org/llama.cpp/blob/b10809/tools/cli/cli-context.cpp) and [internal server implementation](https://github.com/ggml-org/llama.cpp/blob/b10809/tools/cli/cli-server.h).
6. ggml-org. [Pinned completion runner documentation](https://github.com/ggml-org/llama.cpp/blob/b10809/tools/completion/README.md) and [implementation](https://github.com/ggml-org/llama.cpp/blob/b10809/tools/completion/completion.cpp).
7. ggml-org. [Build b10809 artifact attestation and digest](https://github.com/ggml-org/llama.cpp/attestations/45314398), [release API metadata](https://api.github.com/repos/ggml-org/llama.cpp/releases/tags/b10809), and [MIT license](https://github.com/ggml-org/llama.cpp/blob/b10809/LICENSE).
8. Qwen. [First-party model file metadata](https://huggingface.co/api/models/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF?blobs=true), [pinned Q4 file](https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/blob/f86cb2c1fa58255f8052cc32aeede1b7482d4361/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf), and [Apache 2.0 license](https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/blob/f86cb2c1fa58255f8052cc32aeede1b7482d4361/LICENSE).
