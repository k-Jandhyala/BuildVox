import { GoogleGenerativeAI, SchemaType } from "@google/generative-ai";
import { getGeminiApiKey, isDemoMode, GEMINI_MODEL, MAX_INLINE_AUDIO_BYTES } from "./config";
import { validateGeminiResponse } from "./validators";
import { GeminiExtractionResult } from "./types";

// ─── Gemini JSON schema for structured output ─────────────────────────────────

const extractionResponseSchema = {
  type: SchemaType.OBJECT,
  properties: {
    overall_summary: { type: SchemaType.STRING },
    language: { type: SchemaType.STRING },
    items: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          source_text: { type: SchemaType.STRING },
          normalized_summary: { type: SchemaType.STRING },
          trade: { type: SchemaType.STRING },
          tier: { type: SchemaType.STRING },
          urgency: { type: SchemaType.STRING },
          project_ref: { type: SchemaType.STRING },
          job_site_ref: { type: SchemaType.STRING },
          unit_or_area: { type: SchemaType.STRING },
          needs_gc_attention: { type: SchemaType.BOOLEAN },
          needs_trade_manager_attention: { type: SchemaType.BOOLEAN },
          downstream_trades: {
            type: SchemaType.ARRAY,
            items: { type: SchemaType.STRING },
          },
          recommended_company_type: { type: SchemaType.STRING },
          action_required: { type: SchemaType.BOOLEAN },
          suggested_next_step: { type: SchemaType.STRING },
        },
        required: [
          "source_text",
          "normalized_summary",
          "trade",
          "tier",
          "urgency",
          "needs_gc_attention",
          "needs_trade_manager_attention",
          "action_required",
          "suggested_next_step",
        ],
      },
    },
  },
  required: ["overall_summary", "language", "items"],
};

// ─── System prompt ────────────────────────────────────────────────────────────

const SYSTEM_PROMPT = `You are a construction site communication assistant.

Your job is to listen to a voice memo from a construction worker and extract ALL distinct action items, issues, or updates mentioned.

For each item, classify:
- trade: which trade is involved (electrical, plumbing, framing, drywall, paint, general, inspection, other)
- tier:
  * issue_or_blocker — a problem that is blocking work or needs GC attention
  * material_request — a request for materials or supplies
  * progress_update — a status update on completed or ongoing work (no action needed)
  * schedule_change — a change in timeline that affects other trades
- urgency: low, medium, high, critical
- needs_gc_attention: true if the GC should be notified
- needs_trade_manager_attention: true if the trade company manager should be notified
- downstream_trades: list of trades that would be impacted by a schedule change
- recommended_company_type: which trade company should handle this item

Return ALL distinct items. One memo may contain multiple items.
Be specific and accurate in summaries. Do not invent information not in the audio.`;

// ─── Real Gemini integration path ─────────────────────────────────────────────

/**
 * REAL PATH: Downloads audio from provided URL, sends to Gemini,
 * returns validated structured extraction result.
 *
 * Tradeoff: inline base64 works for files up to ~20MB.
 * For larger files, use the Gemini Files API (not implemented in MVP).
 */
export async function extractFromAudio(
  audioUrl: string,
  mimeType: string
): Promise<GeminiExtractionResult> {
  if (isDemoMode()) {
    console.log("[DEMO MODE] Returning canned extraction result");
    return generateDemoExtraction();
  }

  const apiKey = getGeminiApiKey();

  // Download audio bytes from Supabase public/signed URL
  const response = await fetch(audioUrl);
  if (!response.ok) {
    throw new Error(
      `Failed to download audio from URL (status ${response.status}).`
    );
  }

  const contentLengthHeader = response.headers.get("content-length");
  const headerSize = contentLengthHeader ? parseInt(contentLengthHeader, 10) : 0;
  const buffer = Buffer.from(await response.arrayBuffer());
  const fileSizeBytes = headerSize > 0 ? headerSize : buffer.byteLength;

  if (fileSizeBytes > MAX_INLINE_AUDIO_BYTES) {
    throw new Error(
      `Audio file is too large (${fileSizeBytes} bytes). ` +
      `Maximum supported size is ${MAX_INLINE_AUDIO_BYTES} bytes for inline processing. ` +
      `Consider trimming the recording.`
    );
  }

  console.log(`[Gemini] Downloaded audio (${fileSizeBytes} bytes)`);
  const base64Audio = buffer.toString("base64");

  // Call Gemini with structured output
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: GEMINI_MODEL,
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: extractionResponseSchema as any,
    },
  });

  const audioPart = {
    inlineData: {
      mimeType: mimeType,
      data: base64Audio,
    },
  };

  console.log("[Gemini] Sending audio to Gemini for extraction...");
  const result = await model.generateContent([SYSTEM_PROMPT, audioPart]);
  const responseText = result.response.text();

  console.log("[Gemini] Raw response length:", responseText.length);
  console.log("[Gemini] Raw response preview:", responseText.substring(0, 500));

  // Parse and validate
  let parsed: unknown;
  try {
    parsed = JSON.parse(responseText);
  } catch (e) {
    throw new Error(
      `Gemini returned invalid JSON: ${responseText.substring(0, 200)}`
    );
  }

  return validateGeminiResponse(parsed);
}

// ─── FALLBACK: Demo extraction (DEMO_MODE=true or local testing) ───────────────
//
// This path does NOT call Gemini. It returns a realistic fake extraction.
// Label: DEMO FALLBACK — not production behaviour.
//

export function generateDemoExtraction(): GeminiExtractionResult {
  return {
    overall_summary:
      "[DEMO] Electrician reported a conduit blockage in unit 4B blocking rough-in, " +
      "requested additional junction boxes, and noted framing is complete in units 1-3.",
    language: "en",
    items: [
      {
        source_text:
          "We've got a conduit blockage in unit 4B, the framing crew left debris inside the wall cavity.",
        normalized_summary:
          "Conduit blockage in unit 4B caused by framing debris — blocking electrical rough-in.",
        trade: "electrical",
        tier: "issue_or_blocker",
        urgency: "high",
        project_ref: null,
        job_site_ref: null,
        unit_or_area: "Unit 4B",
        needs_gc_attention: true,
        needs_trade_manager_attention: true,
        downstream_trades: [],
        recommended_company_type: "electrical",
        action_required: true,
        suggested_next_step:
          "GC to coordinate with framing crew to clear debris. Electrical rough-in is blocked.",
      },
      {
        source_text:
          "Also need about 20 more junction boxes, standard 4-inch. Running low on site.",
        normalized_summary: "Request for 20 additional 4-inch junction boxes.",
        trade: "electrical",
        tier: "material_request",
        urgency: "medium",
        project_ref: null,
        job_site_ref: null,
        unit_or_area: null,
        needs_gc_attention: false,
        needs_trade_manager_attention: true,
        downstream_trades: [],
        recommended_company_type: "electrical",
        action_required: true,
        suggested_next_step:
          "Electrical manager to order 20 standard 4-inch junction boxes.",
      },
      {
        source_text:
          "Framing is completely done in units 1, 2, and 3. Ready for electrical rough-in there.",
        normalized_summary:
          "Framing complete in units 1–3. Electrical rough-in can begin.",
        trade: "framing",
        tier: "progress_update",
        urgency: "low",
        project_ref: null,
        job_site_ref: null,
        unit_or_area: "Units 1-3",
        needs_gc_attention: false,
        needs_trade_manager_attention: false,
        downstream_trades: ["electrical", "plumbing"],
        recommended_company_type: "framing",
        action_required: false,
        suggested_next_step: "Log for daily digest. Notify electrical crew to begin rough-in.",
      },
    ],
  };
}
