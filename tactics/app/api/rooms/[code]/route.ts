import { getRoom } from "@/lib/rooms";
import { api, protocol, token } from "../_shared";
import type { RouteContext } from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: Request, context: RouteContext) {
  return api(request, "read", async (db) => getRoom(db, (await context.params).code, token(request), Date.now(), protocol(request)));
}
