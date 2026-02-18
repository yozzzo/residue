/**
 * Data migration script: JSON files → D1 SQL statements
 * Generates SQL that can be executed via wrangler d1 execute
 */
import * as fs from 'fs';
import * as path from 'path';

const DATA_DIR = path.resolve(__dirname, '../../data');
const OUT_FILE = path.resolve(__dirname, '../migrations/0002_seed_data.sql');

function esc(v: unknown): string {
  if (v === null || v === undefined) return 'NULL';
  if (typeof v === 'number') return String(v);
  const s = String(v).replace(/'/g, "''");
  return `'${s}'`;
}

function jsonEsc(v: unknown): string {
  if (v === null || v === undefined) return 'NULL';
  return esc(JSON.stringify(v));
}

const lines: string[] = [];

// Worlds
const worldsData = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'worlds/worlds.json'), 'utf-8'));
for (const w of worldsData.worlds) {
  lines.push(
    `INSERT OR REPLACE INTO worlds (world_id, name_ja, name_en, setting, theme_color) VALUES (${esc(w.world_id)}, ${esc(w.name_ja)}, ${esc(w.name_en)}, ${esc(w.blurb_ja)}, NULL);`
  );
}

// Events
const eventsData = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'events/events.json'), 'utf-8'));
for (const [worldId, events] of Object.entries<any[]>(eventsData.events_by_world)) {
  for (const e of events) {
    lines.push(
      `INSERT OR REPLACE INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES (${esc(e.event_id)}, ${esc(worldId)}, ${esc(e.type)}, ${esc(e.text)}, NULL, ${esc(e.speaker ?? null)}, ${jsonEsc(e.choices ?? null)}, ${jsonEsc(e.reaction_slots ?? null)}, ${jsonEsc(e.conditions ?? null)}, ${jsonEsc(e.effects ?? null)});`
    );
  }
}

// Nodes
for (const file of ['medieval_nodes.json', 'future_nodes.json']) {
  const fpath = path.join(DATA_DIR, 'worlds', file);
  if (!fs.existsSync(fpath)) continue;
  const data = JSON.parse(fs.readFileSync(fpath, 'utf-8'));
  const worldId = data.world_id;
  for (const n of data.nodes) {
    lines.push(
      `INSERT OR REPLACE INTO nodes (node_id, world_id, name_ja, name_en, node_type, description_ja, description_en, edges_json, event_ids_json, enemy_ids_json) VALUES (${esc(n.node_id)}, ${esc(worldId)}, ${esc(n.name)}, NULL, ${esc(n.node_type)}, ${esc(n.description)}, NULL, ${jsonEsc(n.edges)}, ${jsonEsc(n.event_ids)}, ${jsonEsc(n.enemy_ids ?? null)});`
    );
  }
}

// Enemies
const enemiesData = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'enemies/enemies.json'), 'utf-8'));
for (const e of enemiesData.enemies) {
  lines.push(
    `INSERT OR REPLACE INTO enemies (enemy_id, name_ja, name_en, hp, attack, defense, description_ja, description_en, rewards_json) VALUES (${esc(e.enemy_id)}, ${esc(e.name_ja)}, ${esc(e.name_en)}, ${e.hp}, ${e.attack}, ${e.defense}, ${esc(e.description_ja)}, ${esc(e.description_en)}, ${jsonEsc(e.rewards)});`
  );
}

// Jobs
const jobsData = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'jobs/jobs.json'), 'utf-8'));
for (const j of jobsData.jobs) {
  lines.push(
    `INSERT OR REPLACE INTO jobs (job_id, name_ja, name_en, origin_world, stat_modifiers_json, unlock_conditions_json, special_ability_json) VALUES (${esc(j.job_id)}, ${esc(j.name_ja)}, ${esc(j.name_en)}, ${esc(j.origin_world)}, ${jsonEsc(j.stat_modifiers)}, ${jsonEsc(j.unlock_conditions)}, ${jsonEsc(j.special_ability)});`
  );
}

fs.writeFileSync(OUT_FILE, lines.join('\n') + '\n');
console.log(`Generated ${lines.length} SQL statements → ${OUT_FILE}`);
