import { env } from "cloudflare:workers";
import { RoomError, SIM_PROTOCOL_VERSION, takeRateLimit } from "@/lib/rooms";
import type { RoomDatabase } from "@/lib/rooms";

export type RouteContext = { params: Promise<{ code: string }> };
const MAX_BODY_BYTES = 4096;
const responseHeaders = {
  "Cache-Control": "no-store, private",
  "X-Content-Type-Options": "nosniff",
  "X-Confluence-Protocol": String(SIM_PROTOCOL_VERSION),
};

export function protocol(request: Request): unknown {
  const value = request.headers.get("X-Confluence-Protocol");
  return value === null || value === "1" ? 1 : value === "2" ? 2 : value === "3" ? 3 : value === "4" ? 4 : value === "5" ? 5 : value === "6" ? 6 : value === "7" ? 7 : value === "8" ? 8 : value === "9" ? 9 : value === "10" ? 10 : value === "11" ? 11 : value === "12" ? 12 : value === "13" ? 13 : value === "14" ? 14 : value === "15" ? 15 : value === "16" ? 16 : value;
}

export async function body(request: Request): Promise<unknown> {
  if (!request.headers.get("content-type")?.toLowerCase().includes("application/json")) {
    throw new RoomError(415, "JSON_REQUIRED", "Send this request as JSON.");
  }
  if (Number(request.headers.get("content-length")) > MAX_BODY_BYTES) {
    throw new RoomError(413, "BODY_TOO_LARGE", "The request is too large.");
  }
  const reader = request.body?.getReader();
  if (!reader) throw new RoomError(400, "INVALID_JSON", "Send a JSON request body.");
  let bytes = 0;
  const decoder = new TextDecoder();
  let text = "";
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > MAX_BODY_BYTES) {
        await reader.cancel();
        throw new RoomError(413, "BODY_TOO_LARGE", "The request is too large.");
      }
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
    return JSON.parse(text);
  } catch (error) {
    if (error instanceof RoomError) throw error;
    throw new RoomError(400, "INVALID_JSON", "The request body must be valid JSON.");
  } finally {
    reader.releaseLock();
  }
}

export function token(request: Request): string {
  const authorization = request.headers.get("authorization") ?? "";
  const match = /^Bearer ([a-f0-9]{64})$/.exec(authorization);
  if (!match) throw new RoomError(401, "UNAUTHORIZED", "Reopen this match in the browser you joined with.");
  return match[1];
}

export async function api(
  request: Request,
  scope: "create" | "join" | "read" | "action",
  action: (db: RoomDatabase) => Promise<unknown>,
  successStatus = 200,
): Promise<Response> {
  try {
    const origin = request.headers.get("origin");
    if (origin && origin !== new URL(request.url).origin) {
      throw new RoomError(403, "ORIGIN_REJECTED", "Open the game directly to play.");
    }
    const db = (env as Cloudflare.Env).DB;
    if (!db) throw new RoomError(503, "SERVICE_UNAVAILABLE", "Online matches are temporarily unavailable. Local play still works.");
    const ip = request.headers.get("cf-connecting-ip") ?? "local-preview";
    const quota = { create: [12, 3_600_000], join: [60, 600_000], read: [400, 60_000], action: [120, 60_000] }[scope];
    await takeRateLimit(db, ip, scope, quota[0], quota[1]);
    return Response.json(await action(db), { status: successStatus, headers: responseHeaders });
  } catch (error) {
    if (error instanceof RoomError) {
      return Response.json({ error: error.message, code: error.code,
        ...(error.reload ? { reload: true, requiredProtocolVersion: error.requiredProtocolVersion } : {}),
      }, {
        status: error.status,
        headers: { ...responseHeaders, ...(error.status === 429 ? { "Retry-After": "60" } : {}) },
      });
    }
    // Keep DB errors, tokens, and request bodies out of responses and logs.
    console.error("Room service request failed", { scope });
    return Response.json({ error: "Online matches are temporarily unavailable. Try again shortly.", code: "SERVICE_UNAVAILABLE" }, {
      status: 503, headers: responseHeaders,
    });
  }
}
