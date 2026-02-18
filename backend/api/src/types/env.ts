export interface Env {
  DB: D1Database;
  ASSETS: R2Bucket;
  ENVIRONMENT: string;
  AI: any; // Workers AI binding
}
