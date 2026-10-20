import { requestRematch } from "@/lib/rooms";
import { api, body, token } from "../../_shared";
import type { RouteContext } from "../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: Request, context: RouteContext) {
  return api(request, "action", async (db) => requestRematch(db, (await context.params).code, token(request), await body(request)));
}
