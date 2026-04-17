import * as functions from "firebase-functions";
import { getSupabase } from "./supabaseAdmin";
import { UserDoc, UserRole } from "./types";

export async function getUserDoc(uid: string): Promise<UserDoc> {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("app_users")
    .select("*")
    .eq("id", uid)
    .maybeSingle();
  if (error || !data) {
    throw new functions.https.HttpsError(
      "not-found",
      "User profile not found."
    );
  }
  return rowToUserDoc(data as Record<string, unknown>);
}

export function rowToUserDoc(row: Record<string, unknown>): UserDoc {
  return {
    uid: row.id as string,
    name: (row.name as string) ?? "",
    email: (row.email as string) ?? "",
    role: (row.role as UserRole) ?? "worker",
    trade: row.trade as UserDoc["trade"],
    companyId: row.company_id as string | undefined,
    assignedProjectIds: (row.assigned_project_ids as string[]) ?? [],
    assignedSiteIds: (row.assigned_site_ids as string[]) ?? [],
    fcmTokens: (row.fcm_tokens as string[]) ?? [],
    createdAt: row.created_at as string,
  };
}
