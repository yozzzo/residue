import { Hono } from 'hono';
import type { Env } from '../types/env';

export const relicsRoutes = new Hono<{ Bindings: Env }>();

// GET /relics — all relics
relicsRoutes.get('/relics', async (c) => {
  const worldId = c.req.query('world_id');
  let query = 'SELECT * FROM relics';
  const binds: string[] = [];
  if (worldId) {
    query += ' WHERE world_id = ?';
    binds.push(worldId);
  }
  const stmt = binds.length > 0
    ? c.env.DB.prepare(query).bind(...binds)
    : c.env.DB.prepare(query);
  const { results } = await stmt.all();
  return c.json({ relics: results });
});

// GET /relics/check?player_id=xxx — check obtainable relics
relicsRoutes.get('/relics/check', async (c) => {
  const playerId = c.req.query('player_id');
  if (!playerId) {
    return c.json({ error: 'player_id required' }, 400);
  }

  const { results: relics } = await c.env.DB.prepare('SELECT * FROM relics').all();

  const run = await c.env.DB.prepare(
    'SELECT loop_count, memory_flags_json FROM runs WHERE player_id = ? ORDER BY created_at DESC LIMIT 1'
  ).bind(playerId).first();

  const loopCount = (run as any)?.loop_count ?? 1;
  let flags: string[] = [];
  try {
    const flagsJson = (run as any)?.memory_flags_json;
    if (flagsJson) flags = JSON.parse(flagsJson);
  } catch {}

  const checked = (relics ?? []).map((r: any) => {
    let conditions: any = {};
    try { conditions = JSON.parse(r.obtain_conditions_json || '{}'); } catch {}
    let obtainable = true;

    if (conditions.requires_flag && !flags.includes(conditions.requires_flag)) {
      obtainable = false;
    }
    if (conditions.min_loop && loopCount < conditions.min_loop) {
      obtainable = false;
    }

    return {
      relic_id: r.relic_id,
      world_id: r.world_id,
      name_ja: r.name_ja,
      relic_type: r.relic_type,
      effect_json: r.effect_json,
      is_permanent: r.is_permanent,
      obtainable,
    };
  });

  return c.json({ relics: checked });
});
