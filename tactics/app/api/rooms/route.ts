import { createRoom } from "@/lib/rooms";
import { api, body } from "./_shared";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  return api(request, "create", async (db) => createRoom(db, await body(request)), 201);
}
