import * as admin from "firebase-admin";
import { getDemoPassword } from "./config";

const db = () => admin.firestore();
const auth = () => admin.auth();

/**
 * Seeds the Firebase project with demo data:
 *  - 5 Auth users (gc, electrician, plumber, manager, admin)
 *  - 2 companies (Volt Electric, AquaFlow Plumbing)
 *  - 1 project (Downtown Mixed-Use Tower)
 *  - 2 job sites
 *  - User docs linked to companies and projects
 *
 * This is idempotent — running it twice will not duplicate data.
 * Call via the Admin screen in the app OR the seedDemoData Cloud Function.
 */
export async function seedDemoData(): Promise<{
  message: string;
  created: string[];
}> {
  const created: string[] = [];
  const password = getDemoPassword();
  const batch = db().batch();

  // ─── 1. Create Auth users ─────────────────────────────────────────────────

  const demoUsers = [
    { email: "gc@demo.com", displayName: "Alex Rivera (GC)", role: "gc" },
    { email: "electrician@demo.com", displayName: "Jordan Lee (Electrician)", role: "worker" },
    { email: "plumber@demo.com", displayName: "Sam Kowalski (Plumber)", role: "worker" },
    { email: "manager@demo.com", displayName: "Morgan Blake (Manager)", role: "manager" },
    { email: "admin@demo.com", displayName: "Chris Admin", role: "admin" },
  ];

  const userIds: Record<string, string> = {};

  for (const u of demoUsers) {
    try {
      const existing = await auth().getUserByEmail(u.email);
      userIds[u.email] = existing.uid;
      console.log(`[seed] Auth user already exists: ${u.email}`);
    } catch {
      const created_user = await auth().createUser({
        email: u.email,
        password,
        displayName: u.displayName,
        emailVerified: true,
      });
      userIds[u.email] = created_user.uid;
      created.push(`auth:${u.email}`);
      console.log(`[seed] Created auth user: ${u.email}`);
    }
  }

  // ─── 2. Create companies ──────────────────────────────────────────────────

  const voltId = "company_volt_electric";
  const aquaId = "company_aquaflow_plumbing";

  const voltRef = db().collection("companies").doc(voltId);
  const aquaRef = db().collection("companies").doc(aquaId);

  batch.set(voltRef, {
    name: "Volt Electric Inc.",
    tradeType: "electrical",
    managerUserIds: [userIds["manager@demo.com"]],
    activeProjectIds: ["project_downtown_tower"],
  }, { merge: true });

  batch.set(aquaRef, {
    name: "AquaFlow Plumbing LLC",
    tradeType: "plumbing",
    managerUserIds: [],
    activeProjectIds: ["project_downtown_tower"],
  }, { merge: true });

  created.push("company:volt_electric", "company:aquaflow_plumbing");

  // ─── 3. Create project ────────────────────────────────────────────────────

  const projectId = "project_downtown_tower";
  const projectRef = db().collection("projects").doc(projectId);

  batch.set(projectRef, {
    name: "Downtown Mixed-Use Tower",
    gcUserIds: [userIds["gc@demo.com"]],
    companyIds: [voltId, aquaId],
    jobSiteIds: ["site_floor_1_5", "site_floor_6_10"],
    tradeSequence: ["framing", "electrical", "plumbing", "drywall", "paint"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  created.push("project:downtown_tower");

  // ─── 4. Create job sites ──────────────────────────────────────────────────

  const site1Ref = db().collection("job_sites").doc("site_floor_1_5");
  batch.set(site1Ref, {
    projectId,
    name: "Floors 1–5",
    address: "123 Main St, Downtown — Floors 1–5",
    activeTrades: ["electrical", "plumbing"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const site2Ref = db().collection("job_sites").doc("site_floor_6_10");
  batch.set(site2Ref, {
    projectId,
    name: "Floors 6–10",
    address: "123 Main St, Downtown — Floors 6–10",
    activeTrades: ["framing"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  created.push("site:floors_1_5", "site:floors_6_10");

  // ─── 5. Create user docs ──────────────────────────────────────────────────

  const now = admin.firestore.FieldValue.serverTimestamp();

  // GC
  batch.set(db().collection("users").doc(userIds["gc@demo.com"]), {
    uid: userIds["gc@demo.com"],
    name: "Alex Rivera",
    email: "gc@demo.com",
    role: "gc",
    companyId: null,
    assignedProjectIds: [projectId],
    assignedSiteIds: ["site_floor_1_5", "site_floor_6_10"],
    fcmTokens: [],
    createdAt: now,
  }, { merge: true });

  // Electrician
  batch.set(db().collection("users").doc(userIds["electrician@demo.com"]), {
    uid: userIds["electrician@demo.com"],
    name: "Jordan Lee",
    email: "electrician@demo.com",
    role: "worker",
    trade: "electrical",
    companyId: voltId,
    assignedProjectIds: [projectId],
    assignedSiteIds: ["site_floor_1_5"],
    fcmTokens: [],
    createdAt: now,
  }, { merge: true });

  // Plumber
  batch.set(db().collection("users").doc(userIds["plumber@demo.com"]), {
    uid: userIds["plumber@demo.com"],
    name: "Sam Kowalski",
    email: "plumber@demo.com",
    role: "worker",
    trade: "plumbing",
    companyId: aquaId,
    assignedProjectIds: [projectId],
    assignedSiteIds: ["site_floor_1_5"],
    fcmTokens: [],
    createdAt: now,
  }, { merge: true });

  // Manager
  batch.set(db().collection("users").doc(userIds["manager@demo.com"]), {
    uid: userIds["manager@demo.com"],
    name: "Morgan Blake",
    email: "manager@demo.com",
    role: "manager",
    trade: "electrical",
    companyId: voltId,
    assignedProjectIds: [projectId],
    assignedSiteIds: ["site_floor_1_5", "site_floor_6_10"],
    fcmTokens: [],
    createdAt: now,
  }, { merge: true });

  // Admin
  batch.set(db().collection("users").doc(userIds["admin@demo.com"]), {
    uid: userIds["admin@demo.com"],
    name: "Chris Admin",
    email: "admin@demo.com",
    role: "admin",
    companyId: null,
    assignedProjectIds: [projectId],
    assignedSiteIds: ["site_floor_1_5", "site_floor_6_10"],
    fcmTokens: [],
    createdAt: now,
  }, { merge: true });

  created.push(
    "user:gc", "user:electrician", "user:plumber", "user:manager", "user:admin"
  );

  await batch.commit();

  return {
    message: `Seed complete. ${created.length} resources created/updated.`,
    created,
  };
}
