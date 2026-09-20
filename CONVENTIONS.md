# FLUX2 Aider operating contract

This file is always loaded into Aider as read-only project guidance.

## Operating mode

- Work interactively. Start non-trivial work in `/ask` mode, state the proposed thin slice, list the files expected to change, and wait for the user to approve implementation with `/code` or `/ok`.
- Make one small, reviewable slice at a time. Do not silently broaden scope.
- Before editing, inspect the relevant repository files and current Git state. Distinguish verified facts from assumptions.
- Preserve all existing binary assets. Never rewrite, optimize, delete, rename, or regenerate PNG, WebP, GIF, JPEG, audio, design-source, or archive files unless the user explicitly requests that exact asset operation.
- The material under `reference/` is concept/reference material, not authoritative runtime data or a final gameplay specification.

## Transparency

For every completed slice, report:

1. What changed and why.
2. Exact files changed.
3. Validation commands run and their results.
4. Known limitations, assumptions, and remaining risks.
5. The resulting commit SHA and push status.

Append the same concise record to `.agent/WORKLOG.md` before the slice is committed. Do not fabricate tests or claim success without command output.

## Git discipline

- Work only on a branch matching `agent/aider-*`.
- Never push directly to `main` or force-push any branch.
- Keep Aider auto-commits enabled so each accepted slice is independently reversible.
- Never commit pre-existing user changes as part of an Aider slice.
- Do not use `git reset --hard`, `git clean -fd`, history rewriting, destructive checkout, or mass deletion without explicit user authorization.
- Do not commit secrets, credentials, tokens, local model files, caches, generated dependency directories, or private machine configuration.
- The guarded post-commit hook pushes each Aider commit to the matching remote branch. If pushing fails, report the exact error and leave the local commit intact.

## Validation

- Discover validation from the actual repository. Do not assume `npm test`, a package manager, engine, or build system exists.
- Prefer the narrowest relevant validation first, then broader checks when available.
- If no automated validation exists, perform and record an appropriate structural or content check and explicitly state that no automated test suite was found.

## Interaction and command access

- Aider has read/write access to the repository under the current Linux user.
- Shell commands are visible and should be invoked interactively with `/run` or `/test`.
- Ask before installing dependencies, changing system configuration, using `sudo`, making network writes beyond normal Git push, or performing destructive operations.
- Use Ctrl-C to stop an unhelpful generation; preserve the partial context and revise the instruction.
