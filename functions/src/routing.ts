import * as admin from "firebase-admin";
import {
  GeminiExtractedItem,
  ProjectDoc,
  CompanyDoc,
  UserDoc,
  TradeType,
} from "./types";

const db = () => admin.firestore();

// ─── Load helpers ─────────────────────────────────────────────────────────────

export async function loadProject(projectId: string): Promise<ProjectDoc | null> {
  const snap = await db().collection("projects").doc(projectId).get();
  if (!snap.exists) return null;
  return { id: snap.id, ...snap.data() } as ProjectDoc;
}

export async function loadCompaniesForProject(
  projectId: string
): Promise<CompanyDoc[]> {
  const snap = await db()
    .collection("companies")
    .where("activeProjectIds", "array-contains", projectId)
    .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() } as CompanyDoc));
}

export async function loadUsersForProject(
  projectId: string
): Promise<UserDoc[]> {
  const snap = await db()
    .collection("users")
    .where("assignedProjectIds", "array-contains", projectId)
    .get();
  return snap.docs.map((d) => ({ uid: d.id, ...d.data() } as UserDoc));
}

// ─── Core routing logic ───────────────────────────────────────────────────────

/**
 * Determines which users and companies should receive this extracted item
 * based on its notification tier and the project's trade relationships.
 *
 * Routing rules:
 *   issue_or_blocker   → GC users + relevant trade company
 *   material_request   → relevant trade company only
 *   progress_update    → no immediate notification (logged to digest)
 *   schedule_change    → GC users + all downstream trade companies
 */
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
    console.warn(`[routing] Project ${projectId} not found; no recipients determined`);
    return { recipientUserIds, recipientCompanyIds };
  }

  const gcUserIds = project.gcUserIds || [];

  // Helper: find company matching a given trade type
  const findCompanyByTrade = (trade: TradeType): CompanyDoc | undefined =>
    companies.find((c) => c.tradeType === trade);

  switch (item.tier) {
    case "issue_or_blocker": {
      // GC must be notified
      recipientUserIds.push(...gcUserIds);
      // The relevant trade company must also be notified
      const company = findCompanyByTrade(item.recommended_company_type);
      if (company) recipientCompanyIds.push(company.id);
      break;
    }

    case "material_request": {
      // Only the trade company — GC is not involved in material requests
      const company = findCompanyByTrade(item.recommended_company_type);
      if (company) recipientCompanyIds.push(company.id);
      break;
    }

    case "progress_update": {
      // No push notifications. Will be picked up by daily digest.
      break;
    }

    case "schedule_change": {
      // GC must know
      recipientUserIds.push(...gcUserIds);

      // Find the reporting trade's position in the sequence
      const seq = project.tradeSequence || [];
      const tradeIdx = seq.indexOf(item.trade);

      if (tradeIdx >= 0) {
        // All trades that come AFTER the reporting trade in sequence are downstream
        const downstreamTrades = seq.slice(tradeIdx + 1);
        downstreamTrades.forEach((trade) => {
          const company = findCompanyByTrade(trade);
          if (company && !recipientCompanyIds.includes(company.id)) {
            recipientCompanyIds.push(company.id);
          }
        });
      }

      // Also add any explicitly listed downstream trades from Gemini
      item.downstream_trades.forEach((trade) => {
        const company = findCompanyByTrade(trade);
        if (company && !recipientCompanyIds.includes(company.id)) {
          recipientCompanyIds.push(company.id);
        }
      });
      break;
    }
  }

  // Deduplicate
  return {
    recipientUserIds: [...new Set(recipientUserIds)],
    recipientCompanyIds: [...new Set(recipientCompanyIds)],
  };
}

// ─── FCM notification dispatch ────────────────────────────────────────────────

/**
 * Sends FCM push notifications to the given recipient user IDs.
 * Also resolves company manager tokens when recipientCompanyIds are provided.
 */
export async function sendFcmNotifications(
  recipientUserIds: string[],
  recipientCompanyIds: string[],
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  const messaging = admin.messaging();
  const allTokens: string[] = [];

  // Collect FCM tokens for direct recipient users
  if (recipientUserIds.length > 0) {
    const userSnaps = await db()
      .collection("users")
      .where(admin.firestore.FieldPath.documentId(), "in", recipientUserIds.slice(0, 10))
      .get();
    userSnaps.docs.forEach((doc) => {
      const user = doc.data() as UserDoc;
      if (user.fcmTokens) allTokens.push(...user.fcmTokens);
    });
  }

  // Collect FCM tokens for company managers
  if (recipientCompanyIds.length > 0) {
    for (const companyId of recipientCompanyIds) {
      const companySnap = await db().collection("companies").doc(companyId).get();
      if (!companySnap.exists) continue;
      const company = companySnap.data() as CompanyDoc;
      if (!company.managerUserIds || company.managerUserIds.length === 0) continue;

      const managerSnaps = await db()
        .collection("users")
        .where(admin.firestore.FieldPath.documentId(), "in", company.managerUserIds.slice(0, 10))
        .get();
      managerSnaps.docs.forEach((doc) => {
        const user = doc.data() as UserDoc;
        if (user.fcmTokens) allTokens.push(...user.fcmTokens);
      });
    }
  }

  if (allTokens.length === 0) {
    console.log("[FCM] No tokens found, skipping push notifications");
    return;
  }

  // FCM allows max 500 tokens per sendEachForMulticast call
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

// ─── Notification doc creation ────────────────────────────────────────────────

export async function createNotificationDocs(
  recipientUserIds: string[],
  recipientCompanyIds: string[],
  title: string,
  body: string,
  type: string,
  extractedItemId: string
): Promise<void> {
  const batch = db().batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  // Direct user notifications
  for (const userId of recipientUserIds) {
    const ref = db().collection("notifications").doc();
    batch.set(ref, {
      type,
      userId,
      extractedItemId,
      title,
      body,
      read: false,
      createdAt: now,
    });
  }

  // Manager notifications for companies
  if (recipientCompanyIds.length > 0) {
    for (const companyId of recipientCompanyIds) {
      const companySnap = await db().collection("companies").doc(companyId).get();
      if (!companySnap.exists) continue;
      const company = companySnap.data() as CompanyDoc;
      for (const managerId of (company.managerUserIds || [])) {
        const ref = db().collection("notifications").doc();
        batch.set(ref, {
          type,
          userId: managerId,
          extractedItemId,
          title,
          body,
          read: false,
          createdAt: now,
        });
      }
    }
  }

  await batch.commit();
}

// ─── Notification title/body builders ─────────────────────────────────────────

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
