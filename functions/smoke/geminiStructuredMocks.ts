import { validateGeminiResponse } from "../src/validators";
import type { GeminiExtractionResult } from "../src/types";

/** Deterministic “Gemini” JSON for electrician blocker → GC routing. */
export function mockElectricianBlockerExtraction(): GeminiExtractionResult {
  const raw = {
    overall_summary: "Electrical rough-in blocked by missing outlet boxes.",
    language: "en",
    items: [
      {
        source_text:
          "Unit 4 electrical rough-in cannot start because the outlet boxes never arrived. Drywall is waiting on us.",
        normalized_summary:
          "Rough-in blocked: outlet boxes missing for Unit 4; impacts drywall schedule.",
        trade: "electrical",
        tier: "issue_or_blocker",
        urgency: "high",
        project_ref: null,
        job_site_ref: null,
        unit_or_area: "Unit 4",
        needs_gc_attention: true,
        needs_trade_manager_attention: true,
        downstream_trades: [] as string[],
        recommended_company_type: "electrical",
        action_required: true,
        suggested_next_step: "GC to expedite outlet box delivery.",
      },
    ],
  };
  return validateGeminiResponse(raw);
}

export function mockPlumberScheduleImpactExtraction(): GeminiExtractionResult {
  const raw = {
    overall_summary: "Water line pressure issue blocking inspection.",
    language: "en",
    items: [
      {
        source_text:
          "Water line pressure issue in Building B is blocking inspection and bathroom fixture installation.",
        normalized_summary:
          "Pressure issue in Building B blocking inspection and fixture install.",
        trade: "plumbing",
        tier: "schedule_change",
        urgency: "critical",
        project_ref: null,
        job_site_ref: null,
        unit_or_area: "Building B",
        needs_gc_attention: true,
        needs_trade_manager_attention: true,
        downstream_trades: ["electrical", "drywall"] as string[],
        recommended_company_type: "plumbing",
        action_required: true,
        suggested_next_step: "GC to coordinate pressure test and inspection reschedule.",
      },
    ],
  };
  return validateGeminiResponse(raw);
}

export function mockMaterialRequestExtraction(): GeminiExtractionResult {
  const raw = {
    overall_summary: "Request for outlet boxes.",
    language: "en",
    items: [
      {
        source_text: "Need 20 more outlet boxes for Unit 4.",
        normalized_summary: "Need 20 outlet boxes for Unit 4.",
        trade: "electrical",
        tier: "material_request",
        urgency: "medium",
        project_ref: null,
        job_site_ref: null,
        unit_or_area: "Unit 4",
        needs_gc_attention: false,
        needs_trade_manager_attention: true,
        downstream_trades: [] as string[],
        recommended_company_type: "electrical",
        action_required: true,
        suggested_next_step: "Electrical manager to order materials.",
      },
    ],
  };
  return validateGeminiResponse(raw);
}

export function mockRoutineProgressExtraction(): GeminiExtractionResult {
  const raw = {
    overall_summary: "Progress in Unit 6.",
    language: "en",
    items: [
      {
        source_text:
          "Completed wiring in Unit 6 and starting panel checks tomorrow.",
        normalized_summary:
          "Wiring complete in Unit 6; panel checks scheduled tomorrow.",
        trade: "electrical",
        tier: "progress_update",
        urgency: "low",
        project_ref: null,
        job_site_ref: null,
        unit_or_area: "Unit 6",
        needs_gc_attention: false,
        needs_trade_manager_attention: false,
        downstream_trades: [] as string[],
        recommended_company_type: "electrical",
        action_required: false,
        suggested_next_step: "Log for daily digest.",
      },
    ],
  };
  return validateGeminiResponse(raw);
}
