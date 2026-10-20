# Reliability and input audit

Audit baseline: rules 6 source `98d70bba`. Scope was the player path from joining a friend, through planning and input, to reconnecting and continuing a match. Server secrecy, deterministic seeds, older-match compatibility and malformed submissions were inspected alongside client behavior.

## Findings and accepted changes

| Finding | Evidence and player impact | Bounded change | Acceptance |
| --- | --- | --- | --- |
| A lost successful join response permanently strands a friend outside their claimed seat. | Production `joinRoom` against SQLite committed an active room; discarding the response and retrying returned `409 ROOM_FULL`. The browser never learned the generated secret. | Retain a browser-generated pending key before sending. The server recovers only the guest seat whose stored hash matches that key, including concurrent duplicate requests. | Same-key retry returns the same seat and room revision; a different key, host key or malformed key cannot take it. Existing callers without the field still join normally. |
| Reloading discards online orders that have not yet been sealed. | The old autosave effect covered only local modes. Server recovery correctly retained sealed orders, but editable online drafts had no persistence. | Retain explicit drafts locally and revalidate them against the current engine on recovery. | Room, match ID, round and owner must all match. Invalid orders are rejected; authoritative sealed orders take precedence. Drafts are cleared after resolution or sealing. |
| A player-key storage warning disappears during successful setup. | `saveSeat` wrote an ephemeral notice; `acceptRoom` then called `selectUnit`, which cleared it. | Report persistence independently of transient planning notices and refresh it during auto-reconnect. | A session-only or memory-only key produces a persistent explanation. Credential reads stay available in this tab if storage later fails. |
| Hover can contradict a pending aimed target. | The displayed candidate preferred hover while Confirm committed the clicked draft. | A clicked draft takes precedence until explicit re-aiming or cancellation. | Moving the pointer after clicking cannot change the displayed confirmation footprint or its ally warning. |
| Browser shortcuts can edit the team plan. | Global M/G/1–4 handlers ignored Ctrl, Meta and Alt. | A shared input filter rejects browser modifiers, editable controls, composition and repeat events. Undo and cancellation follow the same guard. | Native modified commands remain untouched. Plain supported keys still work when the battle permits input and no modal is active. |

## Verification and cooperative review

- `tests/rooms.test.ts`: 34 passing cases, using production SQL against SQLite. The three new cases cover lost-response recovery, concurrent same-key joining, and malformed keys. Released-match, sealed-plan, retry, seed and rematch cases continue to pass.
- `tests/client-session.test.ts`: six passing cases cover pending-key persistence and reload, denied storage, fallback levels, earlier seat keys, later storage failure, draft identity and engine validation, plus keyboard filtering.
- Root integration: all 208 automated tests and TypeScript checks passed.
- `tests/http-v6-smoke.mjs`: all 28 check groups passed against the local development server, including the original simultaneous-match, private-plan and seeded-rematch coverage. The match completed in 12 resolutions, 8–5. New checks use the production client credential helper, perform concurrent joins with one retained key, discard successful responses before installing a seat, recover from a fresh client store, and reject another key.
- Actual browser recovery: the host moved from waiting to an active match after a CLI guest joined; seed `AUDIT-RECOVERY` and its map matched. Oh Tipi's planned move to `(-4, 1)` survived a real page reload as one explicit order, accompanied by the restoration notice. Review company showed the recovered move, and sealing succeeded.
- Isolated local production runtime: all 28 HTTP groups passed, completing 12 resolutions, 8–5. An earlier production probe returned a D1-related 503 while development and production workers shared local state; an immediate fixture retry then reached the existing creation quota. Stopping development and restarting production with a fresh, migrated scratch database removed both conditions. This is consistent with shared local database contention, not proof of its cause or evidence of a remote-service fault. The harness now reports status and safe error-code metadata before accessing a room, without logging credentials, dumping bodies or retrying failed reads.
- Public-site verification remains pending its integration receipt; local results above do not establish published success.
- The mechanics specialist independently reviewed the session, input and room changes. The reliability specialist reviewed the planning insights, status ownership fix, shared feedback timeline and audio lifecycle. No blocking finding remained in those reviews. Integration review additionally required a finished-match guard around draft saving and serialized audio toggling.

## Limits

- A lost host-creation response can still leave an unused waiting room. The host can create another; this change targets the join failure that otherwise prevents both friends from playing.
- Browser storage cannot survive every privacy policy, manual deletion or device change. The UI states the available persistence level; a new credential-transfer flow was not added.
- Editable drafts do not synchronize live between multiple tabs. Sealed orders and game state remain server-authoritative.
- The HTTP lost-response scenario drops the response at the client installation boundary; it does not emulate physical network packet loss. Browser interaction, published HTTP results and physical-device testing are separate evidence.
- This reliability work does not migrate the game protocol or change authoritative combat rules. The separately audited combat correction is documented by the mechanics work.
