import { Hono } from 'hono';
import type { Env } from '../types/env';

export const turnsRoutes = new Hono<{ Bindings: Env }>();

turnsRoutes.post('/turns', async (c) => {
  const body = await c.req.json<{
    run_id: string;
    choice_index: number;
    turn_index: number;
  }>();

  if (!body.run_id || body.choice_index === undefined || body.turn_index === undefined) {
    return c.json({ error: 'run_id, choice_index, and turn_index are required' }, 400);
  }

  // Get current run
  const run = await c.env.DB.prepare(
    'SELECT * FROM runs WHERE run_id = ? AND status = ?'
  ).bind(body.run_id, 'active').first<{
    run_id: string; world_id: string; job_id: string; seed_root: number;
  }>();

  if (!run) {
    return c.json({ error: 'Active run not found' }, 404);
  }

  // Record the player's choice as an event
  await c.env.DB.prepare(
    `INSERT INTO run_events (run_id, turn_index, event_type, payload_json)
     VALUES (?, ?, 'player_choice', ?)`
  ).bind(body.run_id, body.turn_index, JSON.stringify({ choice_index: body.choice_index })).run();

  // Get next events for this world (simple: return next event by turn_index)
  const { results: worldEvents } = await c.env.DB.prepare(
    'SELECT * FROM events WHERE world_id = ? LIMIT 1 OFFSET ?'
  ).bind(run.world_id, body.turn_index).all();

  const nextEvent = worldEvents[0] ?? null;

  return c.json({
    turn_index: body.turn_index + 1,
    next_event: nextEvent,
    run_status: nextEvent ? 'active' : 'completed',
  });
});
