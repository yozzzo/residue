import { Hono } from 'hono';
import type { Env } from '../types/env';

export const runsRoutes = new Hono<{ Bindings: Env }>();

runsRoutes.post('/runs', async (c) => {
  const body = await c.req.json<{
    player_id?: string;
    world_id: string;
    job_id: string;
    seed_root?: number;
  }>();

  if (!body.world_id || !body.job_id) {
    return c.json({ error: 'world_id and job_id are required' }, 400);
  }

  const runId = crypto.randomUUID();
  const seed = body.seed_root ?? Math.floor(Math.random() * 2147483647);

  await c.env.DB.prepare(
    `INSERT INTO runs (run_id, player_id, world_id, job_id, seed_root)
     VALUES (?, ?, ?, ?, ?)`
  ).bind(runId, body.player_id ?? null, body.world_id, body.job_id, seed).run();

  return c.json({ run_id: runId, seed_root: seed, status: 'active' }, 201);
});

runsRoutes.get('/runs/:runId/state', async (c) => {
  const runId = c.req.param('runId');

  const run = await c.env.DB.prepare(
    'SELECT * FROM runs WHERE run_id = ?'
  ).bind(runId).first();

  if (!run) {
    return c.json({ error: 'Run not found' }, 404);
  }

  const { results: events } = await c.env.DB.prepare(
    'SELECT * FROM run_events WHERE run_id = ? ORDER BY turn_index ASC'
  ).bind(runId).all();

  return c.json({ run, events });
});

runsRoutes.post('/runs/:runId/events', async (c) => {
  const runId = c.req.param('runId');
  const body = await c.req.json<{
    turn_index: number;
    event_type: string;
    payload: Record<string, unknown>;
  }>();

  if (body.turn_index === undefined || !body.event_type || !body.payload) {
    return c.json({ error: 'turn_index, event_type, and payload are required' }, 400);
  }

  const run = await c.env.DB.prepare(
    'SELECT run_id FROM runs WHERE run_id = ?'
  ).bind(runId).first();

  if (!run) {
    return c.json({ error: 'Run not found' }, 404);
  }

  const result = await c.env.DB.prepare(
    `INSERT INTO run_events (run_id, turn_index, event_type, payload_json)
     VALUES (?, ?, ?, ?)`
  ).bind(runId, body.turn_index, body.event_type, JSON.stringify(body.payload)).run();

  return c.json({ event_id: result.meta.last_row_id }, 201);
});
