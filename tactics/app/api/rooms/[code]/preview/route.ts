import { roomPreview } from "@/lib/rooms";
import { api, protocol } from "../../_shared";
import type { RouteContext } from "../../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: Request, context: RouteContext) {
  return api(request, "read", async db => roomPreview(db, (await context.params).code, Date.now(), protocol(request)));
}
