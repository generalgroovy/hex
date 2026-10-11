# Windows portrait delivery evidence

Build `p57-30b90507f932`, October 8, 2026. Player instructions and exact artifact
hashes: [Windows delivery](../PORTRAIT-WINDOWS-DELIVERY.md).

| Evidence | Meaning |
|---|---|
| [Portable receipt](portable.json), [export log](export.log), [native export smoke](export-smoke.log) | Actual Windows export, source/PCK identity and normal safe close |
| [Setup build](setup-build.json) | One-file unsigned setup embeds the exact portable ZIP; source package unchanged during build |
| [Installer suite](installer-suite.json), [process log](installer-suite.log) | 33 accepted checks; real payload installation plus synthetic safety/recovery cases |
| [Installed launch](installed-launch.json), [engine log](installed-launch.godot.log) | Stored launcher starts selected game with pixel cast, rendered startup and safe close; both processes exit 0, stderr empty, isolated profile, no shortcuts |
| [Packed portrait v2](portrait-probe-v2.log) | 30 imported textures loaded from copied PCK outside checkout; compiled scripts, actual catalog, 512px textures, two-entry LRU and Gallery release verified |
| [Packed portrait v1](portrait-probe-v1.log) | Failed test-harness assumption: exported `res://` has no physical path; corrected isolation test, no production change |
| [Real update v1](real-update-v1-disk-full.json), [stderr](real-update-v1-disk-full.stderr.log) | Real old installation passed; new update failed from disk exhaustion before replacing selection; not a successful update claim |
| [Real update v2](real-update-v2.json), [pre-resume installed log](real-update-v2-pre-resume-bootstrap.log) | Resumed from verified unchanged old install; actual new install, rollback and forward passed with both payloads and save sentinel verified; original v1 receipt/stage logs hash-preserved |
| [Updated installed launch](updated-installed-launch.json), [engine log](updated-installed-launch.godot.log) | Second native stored-launcher check after real update/rollback/forward: selected new game rendered, admitted pixel art, then closed normally; launcher/game exit 0 and stderr empty |

Following the disk failure, an independent read-only check verified the previous
protected selection and presentation arguments, all 9 manifest-listed files,
source/build/PCK identity, old stored launcher hash and unchanged saved-profile
sentinel. Only the old version remained, with no staged replacement or running
installer. That preservation check does not establish normal update success.
The subsequent v2 run establishes normal update/rollback/forward success. It
reuses the original isolated old installation to avoid another large duplicate;
its new receipt/logs live in a fresh sibling fixture. Ordinary installed
`bootstrap.log` appends are allowed, with its pre-resume bytes preserved first.
This checks file preservation, not cross-version compatibility of every save.

The source checkpoint's [222-suite Full evidence](../portrait-gallery-evidence-20261008/README.md)
predates packaging; it is not represented as newly rerun Full validation here.
Final source-only identity Check still found the exact 3,176 production records
and source SHA `30b90507f932d595b030f3d7ab347537120234b1aec687ec8bfc1beb29f0d2bc`.

## Reproduce in isolated destinations

```powershell
.\scripts\package-hex.ps1 -RunId <fresh-run-id> -PixelCast
.\scripts\build-hex-installer.ps1 -PackageDir <export/windows> -OutputDir <fresh-directory>
.\scripts\test-hex-installer.ps1 -Installer <new-setup.exe> -TestRoot <fresh-child-of-exports/hex-installer-tests>
.\scripts\test-hex-real-update.ps1 -PreviousInstaller <old-setup.exe> -Installer <new-setup.exe> -ExpectedPreviousBuildId <old-id> -ExpectedBuildId <new-id> -TestRoot <fresh-child-of-exports/hex-installer-tests>
.\scripts\smoke-hex-installed.ps1 -InstalledRoot <isolated-install> -ExpectedBuildId <new-id> -LogDirectory <fresh-child-of-.godot>
```

Root serializes engine work through the engine guard. The portrait resource
probe is an external script run by the pinned development engine against a
copied PCK in a physical directory outside the repository, containing no loose
runtime assets/configuration. Actual process working directory is that PCK's
parent; `--main-pack` and `--pack-path` refer to the same file, independently
hash-matched to the portable PCK. See the exact observed paths in the v2 log.
The real-update script's explicit `-ResumeFailedTestRoot` accepts only a verified
old-success/new-failure fixture matching the same exact installer pins, with no
running fixture process, staging or new version. It never reuses the prior result
destination; `-TestRoot` must be fresh, and prior stage evidence is pinned/rechecked.

No actual user-profile install, shortcuts, public release, remote download,
physical Internet gameplay, dense-load performance or human feel acceptance is
implied. A narrowly scoped redundant-staging cleanup was blocked by environment
policy; it was not retried through another mechanism. Source, final artifacts,
protected earlier builds, isolated test payloads and all failure receipts remain.
