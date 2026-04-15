import * as functions from "firebase-functions";

/**
 * Reads GEMINI_API_KEY from:
 *  1. process.env (set via `firebase functions:config:set` or .env for emulators)
 *  2. Firebase functions config (legacy, kept for compatibility)
 *
 * Set it for local emulators by creating functions/.env with:
 *   GEMINI_API_KEY=your_key_here
 *
 * Set it for production with:
 *   firebase functions:config:set gemini.key="your_key_here"
 *   OR use Firebase Secret Manager (recommended for production).
 */
export function getGeminiApiKey(): string {
  const key =
    process.env.GEMINI_API_KEY ||
    (functions.config().gemini && functions.config().gemini.key);

  if (!key) {
    throw new Error(
      "GEMINI_API_KEY is not configured. " +
      "For local testing, set DEMO_MODE=true in functions/.env " +
      "to skip real Gemini calls."
    );
  }
  return key;
}

/**
 * When DEMO_MODE=true, the backend returns canned extraction results
 * instead of calling Gemini. Use this for local testing without an API key.
 */
export function isDemoMode(): boolean {
  return process.env.DEMO_MODE === "true";
}

export function getDemoPassword(): string {
  return process.env.DEMO_PASSWORD || "BuildVox2024!";
}

/** Gemini model to use for audio extraction. */
export const GEMINI_MODEL = "gemini-1.5-pro";

/** Max audio file size to send inline to Gemini (20 MB). */
export const MAX_INLINE_AUDIO_BYTES = 20 * 1024 * 1024;
