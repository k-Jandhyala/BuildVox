import { describe, it, expect } from "vitest";
import { buildGeminiLikeItem, isUuidV4 } from "./reviewPayload";

describe("isUuidV4", () => {
  it("accepts standard lowercase v4 UUIDs", () => {
    expect(
      isUuidV4("550e8400-e29b-41d4-a716-446655440000")
    ).toBe(true);
  });

  it("rejects field_note ids", () => {
    expect(isUuidV4("field_note_1713458920000")).toBe(false);
  });

  it("rejects manual_ ids", () => {
    expect(isUuidV4("manual_1713458920000")).toBe(false);
  });
});

describe("buildGeminiLikeItem", () => {
  it("maps blocker to issue_or_blocker", () => {
    const g = buildGeminiLikeItem(
      {
        transcriptSegment: "x",
        summary: "Blocked",
        category: "blocker",
        priority: "high",
        location: "",
        relatedTrade: "electrical",
        notes: "",
        isBlocker: true,
        isMaterialRequest: false,
      },
      "electrical"
    );
    expect(g.tier).toBe("issue_or_blocker");
    expect(g.needs_gc_attention).toBe(true);
  });

  it("flags work orders for trade manager attention", () => {
    const g = buildGeminiLikeItem(
      {
        transcriptSegment: "Install panel",
        summary: "Panel install",
        category: "workOrder",
        priority: "medium",
        location: "",
        relatedTrade: "electrical",
        notes: "",
        isBlocker: false,
        isMaterialRequest: false,
      },
      "electrical"
    );
    expect(g.needs_trade_manager_attention).toBe(true);
  });
});
