export interface Env {
  DB: D1Database;
  ASSETS: R2Bucket;
  ENVIRONMENT: string;
  AI: any; // Workers AI binding (kept as fallback)
  GEMINI_API_KEY: string;
}
