import * as functions from "firebase-functions";
import { getSupabase } from "./supabaseAdmin";

export function setCors(res: functions.Response): void {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
}

export async function getSupabaseUserIdFromBearer(
  req: functions.Request
): Promise<string> {
  const h = req.headers.authorization;
  if (!h || !h.startsWith("Bearer ")) {
    throw new Error("Missing or invalid Authorization header");
  }
  const token = h.slice(7);
  const supabase = getSupabase();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(token);
  if (error || !user) {
    throw new Error("Invalid or expired session");
  }
  return user.id;
}

export function readJsonBody(req: functions.Request): unknown {
  if (req.body == null) return {};
  if (typeof req.body === "object") return req.body;
  if (typeof req.body === "string") return JSON.parse(req.body || "{}");
  return JSON.parse(Buffer.from(req.body as Buffer).toString("utf8") || "{}");
}
