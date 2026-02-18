import { Hono } from 'hono';
import type { Env } from '../types/env';

export const worldsRoutes = new Hono<{ Bindings: Env }>();

worldsRoutes.get('/worlds', async (c) => {
  const { results } = await c.env.DB.prepare('SELECT * FROM worlds').all();
  return c.json({ worlds: results });
});

worldsRoutes.get('/worlds/:worldId/events', async (c) => {
  const worldId = c.req.param('worldId');
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM events WHERE world_id = ?'
  ).bind(worldId).all();
  return c.json({ events: results });
});

worldsRoutes.get('/worlds/:worldId/nodes', async (c) => {
  const worldId = c.req.param('worldId');
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM nodes WHERE world_id = ?'
  ).bind(worldId).all();
  return c.json({ nodes: results });
});
