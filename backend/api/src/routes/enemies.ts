import { Hono } from 'hono';
import type { Env } from '../types/env';

export const enemiesRoutes = new Hono<{ Bindings: Env }>();

enemiesRoutes.get('/enemies', async (c) => {
  const { results } = await c.env.DB.prepare('SELECT * FROM enemies').all();
  return c.json({ enemies: results });
});
