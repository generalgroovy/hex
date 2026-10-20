import { joinRoom } from "@/lib/rooms";
import { api, body } from "../../_shared";
import type { RouteContext } from "../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: Request, context: RouteContext) {
  return api(request, "join", async (db) => joinRoom(db, (await context.params).code, await body(request)));
}
