import { Hono } from 'hono';
import type { Env } from '../types/env';

export const scenariosRoutes = new Hono<{ Bindings: Env }>();

// GET /scenarios — all scenarios
scenariosRoutes.get('/scenarios', async (c) => {
  const { results } = await c.env.DB.prepare('SELECT * FROM scenarios ORDER BY priority DESC').all();
  return c.json({ scenarios: results });
});

// GET /scenarios/check?player_id=xxx — check which scenarios are unlockable
scenariosRoutes.get('/scenarios/check', async (c) => {
  const playerId = c.req.query('player_id');
  if (!playerId) {
    return c.json({ error: 'player_id required' }, 400);
  }

  const { results: scenarios } = await c.env.DB.prepare('SELECT * FROM scenarios ORDER BY priority DESC').all();

  // Get player's flags and loop count from latest run
  const run = await c.env.DB.prepare(
    'SELECT loop_count, memory_flags_json FROM runs WHERE player_id = ? ORDER BY created_at DESC LIMIT 1'
  ).bind(playerId).first();

  const loopCount = (run as any)?.loop_count ?? 1;
  let flags: string[] = [];
  try {
    const flagsJson = (run as any)?.memory_flags_json;
    if (flagsJson) flags = JSON.parse(flagsJson);
  } catch {}

  const checked = (scenarios ?? []).map((s: any) => {
    const conditions = JSON.parse(s.unlock_conditions_json || '{}');
    let unlockable = true;

    if (conditions.requires_flags) {
      for (const f of conditions.requires_flags) {
        if (!flags.includes(f)) { unlockable = false; break; }
      }
    }
    if (conditions.min_loop && loopCount < conditions.min_loop) {
      unlockable = false;
    }

    return {
      scenario_id: s.scenario_id,
      world_id: s.world_id,
      name_ja: unlockable ? s.name_ja : '???',
      description_ja: unlockable ? s.description_ja : null,
      entry_node_id: unlockable ? s.entry_node_id : null,
      unlockable,
    };
  });

  return c.json({ scenarios: checked });
});
