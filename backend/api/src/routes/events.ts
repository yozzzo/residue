import { Hono } from 'hono';
import type { Env } from '../types/env';
import { buildConditionKey, generateEvent } from './generate';

const eventsRoutes = new Hono<{ Bindings: Env }>();

// GET /events/resolve - Resolve or generate event for player state
eventsRoutes.get('/events/resolve', async (c) => {
  const worldId = c.req.query('world_id') || '';
  const nodeId = c.req.query('node_id') || '';
  const playerId = c.req.query('player_id') || '';
  const truthStage = parseInt(c.req.query('truth_stage') || '0');
  const traits = (c.req.query('traits') || '').split(',').filter(Boolean);
  const flags = (c.req.query('flags') || '').split(',').filter(Boolean);

  if (!worldId || !nodeId) {
    return c.json({ error: 'world_id and node_id required' }, 400);
  }

  const topTrait = traits[0] || 'none';
  const conditionKey = buildConditionKey(worldId, nodeId, truthStage, topTrait, flags);

  // Try existing
  const existing = await c.env.DB.prepare(
    `SELECT * FROM generated_events WHERE condition_key = ? AND status = 'active' ORDER BY quality_score DESC LIMIT 1`
  ).bind(conditionKey).first();

  if (existing) {
    // Increment usage
    await c.env.DB.prepare(
      `UPDATE generated_events SET usage_count = usage_count + 1 WHERE gen_event_id = ?`
    ).bind(existing.gen_event_id).run();

    return c.json({
      gen_event_id: existing.gen_event_id,
      text_ja: existing.text_ja,
      text_en: existing.text_en,
      choices: JSON.parse((existing.choices_json as string) || '[]'),
      quality_score: existing.quality_score,
      generated_by: existing.generated_by,
      cached: true,
    });
  }

  // Get node info for generation
  const node = await c.env.DB.prepare(
    `SELECT name_ja, description_ja FROM nodes WHERE node_id = ? AND world_id = ?`
  ).bind(nodeId, worldId).first();

  // Get player profile
  const profile = await c.env.DB.prepare(
    `SELECT play_style FROM player_profiles WHERE player_id = ?`
  ).bind(playerId).first();

  // Get loop count from profile or default
  const loopCount = profile ? ((profile as any).total_runs || 1) : 1;

  try {
    const event = await generateEvent(c.env, {
      worldId,
      nodeId,
      nodeName: (node?.name_ja as string) || nodeId,
      nodeDescription: (node?.description_ja as string) || '',
      truthStage,
      loopCount,
      traits,
      playStyle: (profile?.play_style as string) || '',
      flags,
      conditionKey,
    }, 0, (p) => c.executionCtx.waitUntil(p));

    return c.json({ ...event, cached: false });
  } catch (e: any) {
    console.error('Event generation failed:', e.message);
    return c.json({ error: 'Generation failed', detail: e.message }, 500);
  }
});

export { eventsRoutes };
