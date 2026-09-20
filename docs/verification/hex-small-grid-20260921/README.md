# H.E.X. smaller-grid evidence

Status: functional/native/package checks passed; multiplayer lifecycle FAILED.
Date: September 21, 2026. Build **p55-c7b7694f8d23**.

Checkpoint: [HEX-SMALL-GRID-CHECKPOINT.md](../../HEX-SMALL-GRID-CHECKPOINT.md).
Runtime bytes are pinned by `source-identity.json`. Successful and failed
attempts are preserved. No isolated user profile, engine cache or binary payload
is included; the nested `.godot/windows-tests` folders contain only named
receipts, reports and logs.

Receipt log paths resolve relative to this directory as well as the original
checkout. Recorded log/current-state/asset-inventory hashes can be rechecked
without publishing the original isolated APPDATA.

| Receipt | Interpretation |
| --- | --- |
| `hex-small-v1.json` | Preflight rejected stale protocol 54 guard; failed before suites |
| `hex-small-v2.json` | Old 64 px fixtures exposed by 48 px geometry; failed |
| `hex-small-v3.json` | PASS: 9 geometry suites / 62,515 assertions / zero stderr |
| `hex-small-full-v1.json` | Unfiltered Full exposed additional old-grid/title/protocol fixtures; failed |
| `hex-small-v4.json` | Invalid requested suite ID; no suites executed; failed |
| `hex-small-v5.json` | PASS: 7 follow-up suites / 7,741 assertions / zero stderr |
| `hex-small-full-v2.json` | One stale session-transport protocol 54 expectation; failed |
| `hex-small-full-v3.json` | PASS: 157 suites / 803,865 assertions / zero failures or stderr; import, asset audit and 120 Hz boot |

## Other evidence

| Directory/file | Scope |
| --- | --- |
| `native/` | 7 actual paid-cast/contact frames, receipt, source identity and zero-stderr capture log; all frames reviewed |
| `package/` | Export/native safe-close logs, receipt, build metadata, launcher and SHA256SUMS; ZIP audit compares all 7 entries to tested bytes |
| `network/` | FAILED same-export lifecycle; 3 peer logs and receipt; unchanged 300 s deadline; zero stderr does not override timeout |
| `final-current-state.json` | Source/document invariants after branding edits; same frozen runtime |
| `source-identity.json` | Final production identity; earlier attempts may name an earlier candidate |

Native normal/reduced Steam frames have the same authority/world hashes.
The light solo capture's 885 us simulation p95 is not dense or rendered capacity.
The network trace shows connection, prediction, reconnect, late spectator and
return-to-Hearth progress, but not complete second-round/stewardship acceptance.

Previous p54 sight evidence remains in `../hex-vision-20260920`; historical
integration evidence remains in `../hex-integration-20260920`. Neither substitutes
for fresh verification of 48 px geometry. No installer, external binary release,
physical two-PC/Internet test, pointer promotion or human acceptance is claimed.
