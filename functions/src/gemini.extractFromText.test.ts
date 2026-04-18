import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { extractFromText } from "./gemini";

describe("extractFromText", () => {
  let prevDemo: string | undefined;

  beforeEach(() => {
    prevDemo = process.env.DEMO_MODE;
    process.env.DEMO_MODE = "true";
  });

  afterEach(() => {
    process.env.DEMO_MODE = prevDemo;
  });

  it("returns structured items in demo mode", async () => {
    const r = await extractFromText("Need boxes in 4B. Also a leak in 2A.");
    expect(r.items.length).toBeGreaterThanOrEqual(1);
    expect(r.overall_summary.length).toBeGreaterThan(10);
    expect(r.language).toBeTruthy();
  });

  it("rejects empty text", async () => {
    await expect(extractFromText("   ")).rejects.toThrow(/empty/);
  });
});
