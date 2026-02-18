import { Hono } from 'hono';
import type { Env } from '../types/env';

const actionsRoutes = new Hono<{ Bindings: Env }>();

// POST /actions/log - Log player action
actionsRoutes.post('/actions/log', async (c) => {
  const body = await c.req.json();
  const { player_id, run_id, action_type, action_detail, world_id, node_id } = body;

  if (!player_id || !action_type) {
    return c.json({ error: 'player_id and action_type required' }, 400);
  }

  await c.env.DB.prepare(
    `INSERT INTO action_logs (player_id, run_id, world_id, node_id, action_type, action_detail_json)
     VALUES (?, ?, ?, ?, ?, ?)`
  ).bind(
    player_id,
    run_id || null,
    world_id || null,
    node_id || null,
    action_type,
    action_detail ? JSON.stringify(action_detail) : null
  ).run();

  // Update player profile stats
  await c.env.DB.prepare(
    `INSERT INTO player_profiles (player_id, total_choices, updated_at)
     VALUES (?, 1, datetime('now'))
     ON CONFLICT(player_id) DO UPDATE SET
       total_choices = total_choices + 1,
       updated_at = datetime('now')`
  ).bind(player_id).run();

  return c.json({ ok: true });
});

// GET /player/profile - Get player profile
actionsRoutes.get('/player/profile', async (c) => {
  const playerId = c.req.query('player_id') || '';
  if (!playerId) {
    return c.json({ error: 'player_id required' }, 400);
  }

  const profile = await c.env.DB.prepare(
    `SELECT * FROM player_profiles WHERE player_id = ?`
  ).bind(playerId).first();

  if (!profile) {
    return c.json({
      player_id: playerId,
      trait_tags: {},
      behavior: {},
      dynamic_flags: {},
      play_style: null,
      total_runs: 0,
      total_choices: 0,
    });
  }

  return c.json({
    player_id: profile.player_id,
    trait_tags: JSON.parse((profile.trait_tags_json as string) || '{}'),
    behavior: JSON.parse((profile.behavior_json as string) || '{}'),
    dynamic_flags: JSON.parse((profile.dynamic_flags_json as string) || '{}'),
    play_style: profile.play_style,
    total_runs: profile.total_runs,
    total_choices: profile.total_choices,
  });
});

// GET /endings/check - Check which endings are available
actionsRoutes.get('/endings/check', async (c) => {
  const playerId = c.req.query('player_id') || '';
  const worldId = c.req.query('world_id') || '';
  const flagsStr = c.req.query('flags') || '';
  const truthStage = parseInt(c.req.query('truth_stage') || '0');
  const hpZero = c.req.query('hp_zero') === 'true';

  const flags = flagsStr.split(',').filter(Boolean);

  const endings = await c.env.DB.prepare(
    `SELECT * FROM endings ORDER BY priority DESC`
  ).all();

  const matched: any[] = [];

  for (const ending of endings.results) {
    const conditions = JSON.parse((ending.conditions_json as string) || '{}');
    let met = true;

    if (conditions.requires_flag && !flags.includes(conditions.requires_flag)) met = false;
    if (conditions.requires_flags) {
      for (const f of conditions.requires_flags) {
        if (!flags.includes(f)) { met = false; break; }
      }
    }
    if (conditions.min_truth_stage && truthStage < conditions.min_truth_stage) met = false;
    if (conditions.hp_zero && !hpZero) met = false;
    if (conditions.requires_choice) met = false; // Client must handle choice-based endings

    if (met) {
      matched.push({
        ending_id: ending.ending_id,
        ending_layer: ending.ending_layer,
        title_ja: ending.title_ja,
        title_en: ending.title_en,
        epilogue_ja: ending.epilogue_ja,
        epilogue_en: ending.epilogue_en,
        priority: ending.priority,
      });
    }
  }

  return c.json({ endings: matched });
});

export { actionsRoutes };
