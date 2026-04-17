import * as admin from "firebase-admin";
import {
  GeminiExtractedItem,
  ProjectDoc,
  CompanyDoc,
  UserDoc,
  TradeType,
} from "./types";
import { getSupabase } from "./supabaseAdmin";
import { rowToUserDoc } from "./db";

function rowToProject(row: Record<string, unknown>): ProjectDoc {
  return {
    id: row.id as string,
    name: (row.name as string) ?? "",
    gcUserIds: (row.gc_user_ids as string[]) ?? [],
    companyIds: (row.company_ids as string[]) ?? [],
    jobSiteIds: (row.job_site_ids as string[]) ?? [],
    tradeSequence: (row.trade_sequence as TradeType[]) ?? [],
    createdAt: row.created_at as string | undefined,
  };
}

function rowToCompany(row: Record<string, unknown>): CompanyDoc {
  return {
    id: row.id as string,
    name: (row.name as string) ?? "",
    tradeType: (row.trade_type as TradeType) ?? "other",
    managerUserIds: (row.manager_user_ids as string[]) ?? [],
    activeProjectIds: (row.active_project_ids as string[]) ?? [],
  };
}

export async function loadProject(projectId: string): Promise<ProjectDoc | null> {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("projects")
    .select("*")
    .eq("id", projectId)
    .maybeSingle();
  if (error || !data) return null;
  return rowToProject(data as Record<string, unknown>);
}

export async function loadCompaniesForProject(
  projectId: string
): Promise<CompanyDoc[]> {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("companies")
    .select("*")
    .filter("active_project_ids", "cs", `{${projectId}}`);
  if (error || !data) return [];
  return data.map((d) => rowToCompany(d as Record<string, unknown>));
}

export async function loadUsersForProject(
  projectId: string
): Promise<UserDoc[]> {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("app_users")
    .select("*")
    .filter("assigned_project_ids", "cs", `{${projectId}}`);
  if (error || !data) return [];
  return data.map((d) => rowToUserDoc(d as Record<string, unknown>));
}

export async function determineRecipients(
  item: GeminiExtractedItem,
  projectId: string
): Promise<{ recipientUserIds: string[]; recipientCompanyIds: string[] }> {
  const [project, companies] = await Promise.all([
    loadProject(projectId),
    loadCompaniesForProject(projectId),
  ]);

  const recipientUserIds: string[] = [];
  const recipientCompanyIds: string[] = [];

  if (!project) {
    console.warn(
      `[routing] Project ${projectId} not found; no recipients determined`
    );
    return { recipientUserIds, recipientCompanyIds };
  }

  const gcUserIds = project.gcUserIds || [];

  const findCompanyByTrade = (trade: TradeType): CompanyDoc | undefined =>
    companies.find((c) => c.tradeType === trade);

  switch (item.tier) {
    case "issue_or_blocker": {
      recipientUserIds.push(...gcUserIds);
      const company = findCompanyByTrade(item.recommended_company_type);
      if (company) recipientCompanyIds.push(company.id);
      break;
    }

    case "material_request": {
      const company = findCompanyByTrade(item.recommended_company_type);
      if (company) recipientCompanyIds.push(company.id);
      break;
    }

    case "progress_update": {
      break;
    }

    case "schedule_change": {
      recipientUserIds.push(...gcUserIds);

      const seq = project.tradeSequence || [];
      const tradeIdx = seq.indexOf(item.trade);

      if (tradeIdx >= 0) {
        const downstreamTrades = seq.slice(tradeIdx + 1);
        downstreamTrades.forEach((trade) => {
          const company = findCompanyByTrade(trade);
          if (company && !recipientCompanyIds.includes(company.id)) {
            recipientCompanyIds.push(company.id);
          }
        });
      }

      item.downstream_trades.forEach((trade) => {
        const company = findCompanyByTrade(trade);
        if (company && !recipientCompanyIds.includes(company.id)) {
          recipientCompanyIds.push(company.id);
        }
      });
      break;
    }
  }

  return {
    recipientUserIds: [...new Set(recipientUserIds)],
    recipientCompanyIds: [...new Set(recipientCompanyIds)],
  };
}

export async function sendFcmNotifications(
  recipientUserIds: string[],
  recipientCompanyIds: string[],
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  const messaging = admin.messaging();
  const allTokens: string[] = [];
  const supabase = getSupabase();

  if (recipientUserIds.length > 0) {
    const slice = recipientUserIds.slice(0, 10);
    const { data: users } = await supabase
      .from("app_users")
      .select("*")
      .in("id", slice);
    (users ?? []).forEach((row) => {
      const u = rowToUserDoc(row as Record<string, unknown>);
      if (u.fcmTokens) allTokens.push(...u.fcmTokens);
    });
  }

  if (recipientCompanyIds.length > 0) {
    for (const companyId of recipientCompanyIds) {
      const { data: companyRow } = await supabase
        .from("companies")
        .select("*")
        .eq("id", companyId)
        .maybeSingle();
      if (!companyRow) continue;
      const company = rowToCompany(companyRow as Record<string, unknown>);
      if (!company.managerUserIds || company.managerUserIds.length === 0)
        continue;

      const slice = company.managerUserIds.slice(0, 10);
      const { data: managers } = await supabase
        .from("app_users")
        .select("*")
        .in("id", slice);
      (managers ?? []).forEach((row) => {
        const u = rowToUserDoc(row as Record<string, unknown>);
        if (u.fcmTokens) allTokens.push(...u.fcmTokens);
      });
    }
  }

  if (allTokens.length === 0) {
    console.log("[FCM] No tokens found, skipping push notifications");
    return;
  }

  const uniqueTokens = [...new Set(allTokens)];
  const chunks: string[][] = [];
  for (let i = 0; i < uniqueTokens.length; i += 500) {
    chunks.push(uniqueTokens.slice(i, i + 500));
  }

  for (const chunk of chunks) {
    try {
      const response = await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        data,
        android: {
          priority: "high",
          notification: {
            channelId: "buildvox_alerts",
            priority: "high",
          },
        },
      });
      console.log(
        `[FCM] Sent ${response.successCount}/${chunk.length} messages`
      );
    } catch (err) {
      console.error("[FCM] Error sending notifications:", err);
    }
  }
}

export async function createNotificationDocs(
  recipientUserIds: string[],
  recipientCompanyIds: string[],
  title: string,
  body: string,
  type: string,
  extractedItemId: string
): Promise<void> {
  const supabase = getSupabase();
  const rows: Record<string, unknown>[] = [];

  for (const userId of recipientUserIds) {
    rows.push({
      type,
      user_id: userId,
      extracted_item_id: extractedItemId,
      title,
      body,
      read: false,
    });
  }

  if (recipientCompanyIds.length > 0) {
    for (const companyId of recipientCompanyIds) {
      const { data: companyRow } = await supabase
        .from("companies")
        .select("*")
        .eq("id", companyId)
        .maybeSingle();
      if (!companyRow) continue;
      const company = rowToCompany(companyRow as Record<string, unknown>);
      for (const managerId of company.managerUserIds || []) {
        rows.push({
          type,
          user_id: managerId,
          extracted_item_id: extractedItemId,
          title,
          body,
          read: false,
        });
      }
    }
  }

  if (rows.length === 0) return;

  const { error } = await supabase.from("notifications").insert(rows);
  if (error) console.error("[notifications] insert failed:", error);
}

export function buildNotificationContent(
  tier: string,
  trade: string,
  summary: string,
  urgency: string
): { title: string; body: string; type: string } {
  switch (tier) {
    case "issue_or_blocker":
      return {
        type: "new_blocker",
        title: `🚧 ${urgency.toUpperCase()} Blocker — ${trade}`,
        body: summary.substring(0, 120),
      };
    case "material_request":
      return {
        type: "material_request",
        title: `📦 Material Request — ${trade}`,
        body: summary.substring(0, 120),
      };
    case "schedule_change":
      return {
        type: "new_schedule_change",
        title: `📅 Schedule Change — ${trade}`,
        body: summary.substring(0, 120),
      };
    default:
      return {
        type: "progress_update",
        title: `✅ Progress Update — ${trade}`,
        body: summary.substring(0, 120),
      };
  }
}
