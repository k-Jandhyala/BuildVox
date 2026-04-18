import { GoogleGenerativeAI, SchemaType } from "@google/generative-ai";
import { getGeminiApiKey, isDemoMode, GEMINI_MODEL } from "./config";
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

/** Typed field notes (primary product flow): user pastes/types text; same extraction schema as audio. */
const TEXT_FIELD_NOTE_PROMPT = `You are a construction site communication assistant.

The user typed a construction field note, update, request, or report on a job site. Extract ALL distinct action items, issues, blockers, material requests, work orders, schedule impacts, or progress updates mentioned in the text.

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

Return ALL distinct items. One message may contain multiple items.
Be specific and accurate in summaries. Do not invent information not present in the text.`;

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

const GEMINI_FILE_STATE_ACTIVE = "ACTIVE";
const GEMINI_FILE_STATE_PROCESSING = "PROCESSING";
const GEMINI_FILE_STATE_FAILED = "FAILED";
const FILE_POLL_INTERVAL_MS = 2000;
const FILE_POLL_TIMEOUT_MS = 60_000;

interface GeminiFileResource {
  name: string;
  uri?: string;
  mimeType?: string;
  state?: {
    name?: string;
  };
}

async function uploadAudioToGeminiFiles(
  apiKey: string,
  audioBytes: Buffer,
  mimeType: string
): Promise<GeminiFileResource> {
  const startResp = await fetch(
    `https://generativelanguage.googleapis.com/upload/v1beta/files?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: {
        "X-Goog-Upload-Protocol": "resumable",
        "X-Goog-Upload-Command": "start",
        "X-Goog-Upload-Header-Content-Length": String(audioBytes.byteLength),
        "X-Goog-Upload-Header-Content-Type": mimeType,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        file: {
          display_name: `voice-memo-${Date.now()}`,
        },
      }),
    }
  );

  if (!startResp.ok) {
    const text = await startResp.text();
    throw new Error(
      `Gemini file upload start failed (${startResp.status}): ${text.substring(0, 200)}`
    );
  }

  const uploadUrl = startResp.headers.get("x-goog-upload-url");
  if (!uploadUrl) {
    throw new Error("Gemini file upload URL missing from response headers.");
  }

  const finalizeResp = await fetch(uploadUrl, {
    method: "POST",
    headers: {
      "X-Goog-Upload-Offset": "0",
      "X-Goog-Upload-Command": "upload, finalize",
      "Content-Type": mimeType,
    },
    body: audioBytes,
  });

  if (!finalizeResp.ok) {
    const text = await finalizeResp.text();
    throw new Error(
      `Gemini file upload finalize failed (${finalizeResp.status}): ${text.substring(0, 200)}`
    );
  }

  const finalizeJson = (await finalizeResp.json()) as unknown;
  const uploaded =
    finalizeJson &&
    typeof finalizeJson === "object" &&
    "file" in finalizeJson &&
    (finalizeJson as { file?: GeminiFileResource }).file
      ? (finalizeJson as { file: GeminiFileResource }).file
      : (finalizeJson as GeminiFileResource);

  if (!uploaded?.name) {
    throw new Error("Gemini file upload returned no file name.");
  }

  return uploaded;
}

async function waitForGeminiFileReady(
  apiKey: string,
  fileName: string
): Promise<GeminiFileResource> {
  const startedAt = Date.now();
  let latest: GeminiFileResource | null = null;

  while (Date.now() - startedAt < FILE_POLL_TIMEOUT_MS) {
    const pollResp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/${fileName}?key=${encodeURIComponent(apiKey)}`
    );
    if (!pollResp.ok) {
      const text = await pollResp.text();
      throw new Error(
        `Gemini file poll failed (${pollResp.status}): ${text.substring(0, 200)}`
      );
    }

    latest = (await pollResp.json()) as GeminiFileResource;
    const state = latest.state?.name || "";

    if (state === GEMINI_FILE_STATE_ACTIVE) {
      return latest;
    }
    if (state === GEMINI_FILE_STATE_FAILED) {
      throw new Error("Gemini audio file processing failed.");
    }

    await new Promise((resolve) => setTimeout(resolve, FILE_POLL_INTERVAL_MS));
  }

  throw new Error(
    `Timed out waiting for Gemini file processing (${fileName}).`
  );
}

/**
 * REAL PATH: Downloads audio from provided URL, uploads to Gemini Files API,
 * waits for processing, and extracts structured action items.
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

  const buffer = Buffer.from(await response.arrayBuffer());
  console.log(`[Gemini] Downloaded audio (${buffer.byteLength} bytes)`);

  console.log("[Gemini] Uploading audio to Gemini Files API...");
  const uploadedFile = await uploadAudioToGeminiFiles(apiKey, buffer, mimeType);
  const uploadedName = uploadedFile.name;
  console.log(`[Gemini] Uploaded file: ${uploadedName}`);

  const currentState = uploadedFile.state?.name || "";
  const readyFile =
    currentState === GEMINI_FILE_STATE_ACTIVE
      ? uploadedFile
      : currentState === GEMINI_FILE_STATE_PROCESSING || !currentState
        ? await waitForGeminiFileReady(apiKey, uploadedName)
        : (() => {
            throw new Error(
              `Gemini uploaded file is not usable (state: ${currentState}).`
            );
          })();

  if (!readyFile.uri) {
    throw new Error("Gemini file is ready but missing URI.");
  }

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
    fileData: {
      mimeType: readyFile.mimeType || mimeType,
      fileUri: readyFile.uri,
    },
  };

  console.log("[Gemini] Sending audio to Gemini for extraction...");
  const result = await model.generateContent([SYSTEM_PROMPT, audioPart]);
  const responseText = result.response.text();

  console.log("[Gemini] Raw response length:", responseText.length);

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

/**
 * Primary typed-input flow: send raw field-note text to Gemini with the same JSON schema as audio.
 */
export async function extractFromText(
  userText: string
): Promise<GeminiExtractionResult> {
  const trimmed = userText.trim();
  if (!trimmed) {
    throw new Error("extractFromText: empty text");
  }

  if (isDemoMode()) {
    console.log("[DEMO MODE] extractFromText: returning canned extraction");
    return generateDemoExtraction();
  }

  const apiKey = getGeminiApiKey();
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: GEMINI_MODEL,
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: extractionResponseSchema as any,
    },
  });

  console.log("[Gemini] extractFromText: sending text to Gemini...");
  const result = await model.generateContent([
    TEXT_FIELD_NOTE_PROMPT,
    { text: `Construction field note:\n\n${trimmed}` },
  ]);
  const responseText = result.response.text();
  console.log("[Gemini] extractFromText: response length:", responseText.length);

  let parsed: unknown;
  try {
    parsed = JSON.parse(responseText);
  } catch {
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
