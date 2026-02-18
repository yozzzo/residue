import { Hono } from 'hono';
import type { Env } from '../types/env';

export const jobsRoutes = new Hono<{ Bindings: Env }>();

jobsRoutes.get('/jobs', async (c) => {
  const { results } = await c.env.DB.prepare('SELECT * FROM jobs').all();
  return c.json({ jobs: results });
});
