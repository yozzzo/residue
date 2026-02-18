-- 生成済みコンテンツプール
CREATE TABLE IF NOT EXISTS generated_events (
  gen_event_id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  node_id TEXT NOT NULL,
  condition_key TEXT NOT NULL,
  layer TEXT NOT NULL,
  chain_id TEXT,
  chain_step INTEGER DEFAULT 0,
  text_ja TEXT NOT NULL,
  text_en TEXT,
  choices_json TEXT,
  effects_json TEXT,
  generated_by TEXT,
  quality_score REAL DEFAULT 0.0,
  usage_count INTEGER DEFAULT 0,
  skip_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active',
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_generated_events_lookup
  ON generated_events(condition_key, status);

CREATE INDEX IF NOT EXISTS idx_generated_events_world_node
  ON generated_events(world_id, node_id);

-- プレイヤープロファイル
CREATE TABLE IF NOT EXISTS player_profiles (
  player_id TEXT PRIMARY KEY,
  trait_tags_json TEXT DEFAULT '{}',
  behavior_json TEXT DEFAULT '{}',
  dynamic_flags_json TEXT DEFAULT '{}',
  play_style TEXT,
  total_runs INTEGER DEFAULT 0,
  total_choices INTEGER DEFAULT 0,
  updated_at TEXT DEFAULT (datetime('now'))
);

-- イベントチェーン定義
CREATE TABLE IF NOT EXISTS event_chains (
  chain_id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  chain_type TEXT NOT NULL,
  title_ja TEXT,
  premise_ja TEXT,
  total_steps INTEGER DEFAULT 0,
  ending_type TEXT,
  status TEXT DEFAULT 'active',
  created_at TEXT DEFAULT (datetime('now'))
);

-- エンディング定義
CREATE TABLE IF NOT EXISTS endings (
  ending_id TEXT PRIMARY KEY,
  ending_layer TEXT NOT NULL,
  title_ja TEXT NOT NULL,
  title_en TEXT,
  description_ja TEXT,
  conditions_json TEXT NOT NULL,
  epilogue_ja TEXT,
  epilogue_en TEXT,
  priority INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

-- 行動ログ
CREATE TABLE IF NOT EXISTS action_logs (
  log_id INTEGER PRIMARY KEY AUTOINCREMENT,
  player_id TEXT NOT NULL,
  run_id TEXT,
  world_id TEXT,
  node_id TEXT,
  action_type TEXT NOT NULL,
  action_detail_json TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_action_logs_player
  ON action_logs(player_id, created_at);
