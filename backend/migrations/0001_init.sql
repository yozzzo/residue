-- ワールド定義
CREATE TABLE IF NOT EXISTS worlds (
  world_id TEXT PRIMARY KEY,
  name_ja TEXT NOT NULL,
  name_en TEXT,
  setting TEXT,
  theme_color TEXT
);

-- イベント定義
CREATE TABLE IF NOT EXISTS events (
  event_id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  type TEXT NOT NULL,
  text_ja TEXT NOT NULL,
  text_en TEXT,
  speaker TEXT,
  choices_json TEXT,
  reaction_slots_json TEXT,
  conditions_json TEXT,
  effects_json TEXT,
  FOREIGN KEY (world_id) REFERENCES worlds(world_id)
);

-- ノードマップ
CREATE TABLE IF NOT EXISTS nodes (
  node_id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  name_ja TEXT NOT NULL,
  name_en TEXT,
  node_type TEXT DEFAULT 'explore',
  description_ja TEXT,
  description_en TEXT,
  edges_json TEXT,
  event_ids_json TEXT,
  enemy_ids_json TEXT,
  FOREIGN KEY (world_id) REFERENCES worlds(world_id)
);

-- 敵定義
CREATE TABLE IF NOT EXISTS enemies (
  enemy_id TEXT PRIMARY KEY,
  name_ja TEXT NOT NULL,
  name_en TEXT,
  hp INTEGER NOT NULL,
  attack INTEGER NOT NULL,
  defense INTEGER DEFAULT 0,
  description_ja TEXT,
  description_en TEXT,
  rewards_json TEXT
);

-- ジョブ定義
CREATE TABLE IF NOT EXISTS jobs (
  job_id TEXT PRIMARY KEY,
  name_ja TEXT NOT NULL,
  name_en TEXT,
  origin_world TEXT,
  stat_modifiers_json TEXT,
  unlock_conditions_json TEXT,
  special_ability_json TEXT
);

-- ランの状態
CREATE TABLE IF NOT EXISTS runs (
  run_id TEXT PRIMARY KEY,
  player_id TEXT,
  world_id TEXT NOT NULL,
  job_id TEXT NOT NULL,
  seed_root INTEGER,
  started_at TEXT DEFAULT (datetime('now')),
  ended_at TEXT,
  status TEXT DEFAULT 'active',
  loop_count INTEGER DEFAULT 1
);

-- イベントログ
CREATE TABLE IF NOT EXISTS run_events (
  event_id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  turn_index INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (run_id) REFERENCES runs(run_id)
);

-- プレイヤーの永続状態
CREATE TABLE IF NOT EXISTS player_state (
  player_id TEXT PRIMARY KEY,
  soul_points INTEGER DEFAULT 0,
  loop_count INTEGER DEFAULT 1,
  unlocked_jobs_json TEXT DEFAULT '["wanderer"]',
  trait_tags_json TEXT DEFAULT '{}',
  memory_flags_json TEXT DEFAULT '{}',
  world_truth_stages_json TEXT DEFAULT '{}',
  cross_link_items_json TEXT DEFAULT '[]',
  cross_link_completed_json TEXT DEFAULT '[]',
  updated_at TEXT DEFAULT (datetime('now'))
);
