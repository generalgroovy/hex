# Development and operations

Run all commands from **`tactics/`** in the GitHub repository. The Godot project at repository root has a separate toolchain.

## Reproducible checkout

Use Node **24** and the committed `package-lock.json`. Node 24.18.0 was used for release 45. `package.json` permits Node >=22.13, but that is not a claim that every allowed release was tested. On Windows, use `npm.cmd` if PowerShell execution policy blocks `npm.ps1`.

```sh
git clone https://github.com/generalgroovy/hex.git
cd hex/tactics
npm run install:ci
npm run docs:check
npm run db:local
npm run dev -- --hostname 127.0.0.1
```

Development defaults to port 5173. Story and solo Tower use browser-local progress; online Arena and cooperative Tower require the local D1 schema. Local mock hosting identity is for preview only. Private match seats still use their own protocol credentials.

For a smaller source checkout, Git supports a partial, sparse clone:

```sh
git clone --filter=blob:none --sparse https://github.com/generalgroovy/hex.git
cd hex
git sparse-checkout set tactics
cd tactics
npm run install:ci
```

`install:ci` invokes npm through its JavaScript entrypoint, includes optional/dev dependencies and checks that Vinext was installed. Native dependencies such as Sharp are platform-specific; do not copy `node_modules` between computers. Clean clones select the portable execution profile automatically. `.sites-runtime/execution-profile.json`, when present on a managed host, is local configuration and is intentionally untracked.

## Database

[wrangler.local.jsonc](../../wrangler.local.jsonc) describes **only a local** D1 database. Its placeholder ID matches the binding created by [vite.config.ts](../../vite.config.ts). `npm run db:local` applies the four SQL migrations in [drizzle/](../../drizzle) with Wrangler's migration ledger and can be rerun on a fresh ledger-managed database.

| Migration | Purpose |
|---|---|
| `0000_fair_franklin_richards.sql` | Historical two-seat rooms and rate-limit storage |
| `0001_tiny_master_mold.sql` | Multi-company Arena rooms |
| `0002_silly_franklin_storm.sql` | Earlier shared-squad Tower rooms |
| `0003_nervous_swarm.sql` | Current independent-squad Tower climbs |

Local state lives in `.wrangler/state/`. Never run development and built Worker servers against that directory simultaneously. Do not copy the local database to production or commit it.

If an older local database was created by executing SQL files directly, it has no migration ledger: do not blindly rerun `db:local` against it. Preserve that database and use a new checkout for the documented fresh setup, or inspect and explicitly reconcile its existing tables and ledger. Avoid changing the historical migrations after release.

## Build and verify

```sh
npm run typecheck
npm test
npm run build
npm run assets:check
npm start -- --port 8787
```

The build emits `dist/client/` and `dist/server/wrangler.json`. `assets:check` validates every referenced client asset in both RSC and SSR manifests. `npm start` uses the built Worker with local D1. It does not publish.

In another terminal, after the Worker is ready:

```sh
node --experimental-strip-types tests/http-v18-smoke.mjs http://127.0.0.1:8787
node --experimental-strip-types tests/http-tower-v23-smoke.mjs http://127.0.0.1:8787 --same-room
node --experimental-strip-types tests/http-tower-v23-smoke.mjs http://127.0.0.1:8787 --split-rooms
```

Run these network suites sequentially on a constrained local machine. They each exercise several concurrent seats internally. The Tower transport retries bounded transient failures with stable request identity; the older Arena smoke deliberately fails immediately on unexpected responses.

## Publishing

The live game uses **Sites + Cloudflare Workers + D1**, not GitHub Pages. A GitHub push or CI pass does not deploy it. [.openai/hosting.json](../../.openai/hosting.json) preserves the current project and DB binding, without credentials.

For the established Sites workflow, use the installed Sites skill and current connector tools to:

1. Inspect the existing project and open its current source revision.
2. Integrate the reviewed `tactics/` changes into that project root; preserve its hosting configuration and compatible data.
3. Install and run type, native, production build, asset, HTTP and browser checks for the changed scope.
4. Request a short-lived source credential through the connector. Pass it to the official workflow through hidden stdin, never a file, shell argument, Git URL or commit.
5. Let the workflow commit/push/package the matching source; save that site version and deploy it.
6. Wait for terminal deployment success. Verify live routes and representative asset hashes against the tested build.

The installed workflow's location is host-specific and is not a runtime dependency of this repository. Standalone local builds use `npm run build`. On the release Windows host, the official Sites build helper required a temporary npm command shim pointing to the installed Node/npm entrypoint and Git Bash `tar` with `TAR_OPTIONS=--force-local`. That is a publishing-tool workaround, not a requirement to run the game.

Deploying to another provider requires an explicit adaptation of Worker bindings, D1 persistence, migrations, routing and hosting identity. Copying `dist/client/` to a static host cannot support the multiplayer APIs. Changing public access, domain or production data is separate from committing source.

### Separate short Pages host

The separate Direct Upload project in [`../../../hosting/pages/wrangler.jsonc`](../../../hosting/pages/wrangler.jsonc) is live at [hex-9o4.pages.dev](https://hex-9o4.pages.dev). Its game modes are [Story](https://hex-9o4.pages.dev/story), [Tower solo](https://hex-9o4.pages.dev/tower), [Tower co-op](https://hex-9o4.pages.dev/tower?play=friends), and [Arena](https://hex-9o4.pages.dev/skirmish). Pages Advanced Mode runs the built Worker for server-rendered routes and `/api/*`, backed by its own Western Europe D1 database, `hex-multiplayer`. The original Sites host and its database remain independent; active rooms and private seat codes do not transfer between the hosts.

For a fresh deployment, use a Wrangler login scoped to `pages:write` and `d1:write`. From `tactics/`, run `npm run build` and `npm run pages:stage`. Then, from `hosting/pages/`, apply remote D1 migrations and run `wrangler pages deploy ../../tactics/dist/pages-release --project-name hex --branch main`. The config pins the Cloudflare account and D1 database. Direct Upload does not deploy automatically on Git pushes; verify the production URL, routes, and online room creation after deployment.

## Saves, privacy and recovery

Use `/saves` for validated export/import through the UI. Backups may include private multiplayer seat access; keep them out of Git and public issue attachments. Story/Tower progression, settings and tab-scoped seats are distinct from server room data. Read [Architecture](ARCHITECTURE.md) before changing storage keys or protocol versions.

Keep previous releases and source identities when shipping. A rollback must respect the existing database and browser save versions; replacing code does not erase or downgrade saves. Prefer additive compatibility and explicit legacy routes to silent reinterpretation.
