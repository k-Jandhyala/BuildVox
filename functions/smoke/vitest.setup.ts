import { vi } from "vitest";

vi.mock("firebase-admin", () => ({
  initializeApp: vi.fn(),
  messaging: () => ({
    sendEachForMulticast: vi.fn().mockResolvedValue({ successCount: 0 }),
  }),
}));
