-- Migration 0005: High Priority Features (Build 19)
-- Scenarios, Relics, Hidden Nodes, Hidden Events

-- === Scenarios Table (GDD §20) ===
CREATE TABLE IF NOT EXISTS scenarios (
  scenario_id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  name_ja TEXT NOT NULL,
  name_en TEXT,
  description_ja TEXT,
  unlock_conditions_json TEXT NOT NULL,
  entry_node_id TEXT NOT NULL,
  is_canon_override INTEGER DEFAULT 0,
  priority INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

INSERT INTO scenarios VALUES ('medieval_alt_bishop', 'medieval', '司教の告解', NULL,
  '封印されし司教が語る、もう一つの真実。',
  '{"requires_flags":["bishop_defeated","mirror_touched"],"min_loop":5}',
  'm_n13', 0, 1, datetime('now'));

INSERT INTO scenarios VALUES ('future_alt_kai', 'future', 'カイの選択', NULL,
  'N-06が選ばなかった道を、お前が歩く。',
  '{"requires_flags":["kai_final_record_read","prophet_defeated"],"min_loop":5}',
  'f_n13', 0, 1, datetime('now'));

-- === Relics Table (GDD §4.5) ===
CREATE TABLE IF NOT EXISTS relics (
  relic_id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  name_ja TEXT NOT NULL,
  name_en TEXT,
  relic_type TEXT NOT NULL,
  effect_json TEXT NOT NULL,
  obtain_conditions_json TEXT,
  is_permanent INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

-- Medieval relics
INSERT INTO relics VALUES ('broken_rosary', 'medieval', '砕けた数珠', NULL, 'blessing',
  '{"type":"defense_bonus","value":3,"description_ja":"祈りの残滓が身を守る"}',
  '{"requires_flag":"chapel_prayed"}', 0, datetime('now'));
INSERT INTO relics VALUES ('bishops_gaze', 'medieval', '司教の眼差し', NULL, 'curse',
  '{"type":"hp_drain","value":2,"description_ja":"毎ターンHP-2。だが真実が見える"}',
  '{"requires_flag":"bishop_defeated"}', 0, datetime('now'));
INSERT INTO relics VALUES ('aldus_pendant', 'medieval', 'アルダスのペンダント', NULL, 'artifact',
  '{"type":"truth_sight","value":1,"description_ja":"隠されたテキストが見えるようになる"}',
  '{"requires_flag":"aldus_name_asked","min_loop":3}', 1, datetime('now'));

-- Future relics
INSERT INTO relics VALUES ('n06_memory_chip', 'future', 'N-06のメモリチップ', NULL, 'blessing',
  '{"type":"attack_bonus","value":3,"description_ja":"カイの戦闘データが力を与える"}',
  '{"requires_flag":"diary_read"}', 0, datetime('now'));
INSERT INTO relics VALUES ('core_static', 'future', 'コアの残響', NULL, 'curse',
  '{"type":"random_glitch","value":1,"description_ja":"時折、画面が乱れ選択肢が入れ替わる"}',
  '{"requires_flag":"prophet_defeated"}', 0, datetime('now'));
INSERT INTO relics VALUES ('quantum_pendant', 'future', '量子ペンダント', NULL, 'artifact',
  '{"type":"cross_sight","value":1,"description_ja":"別世界の残響が聞こえる"}',
  '{"requires_flag":"terminal_hacked","min_loop":3}', 1, datetime('now'));

-- === Hidden Nodes (GDD §6.3) ===
INSERT INTO nodes (node_id, world_id, name_ja, node_type, description_ja, edges_json, event_ids_json, enemy_ids_json)
VALUES ('m_n13', 'medieval', '封印の裏', 'event', '封印の向こう側。ここには時間が存在しない。',
  '{"封印の間へ戻る":"m_n10"}', '["m_e_hidden_seal"]', '[]');

INSERT INTO nodes (node_id, world_id, name_ja, node_type, description_ja, edges_json, event_ids_json, enemy_ids_json)
VALUES ('f_n13', 'future', '隠されたセクター', 'event', '削除されたはずの区画。全被験体の記録が眠る。',
  '{"データ保管庫へ戻る":"f_n05"}', '["f_e_hidden_sector"]', '[]');

-- === Hidden Events ===
INSERT INTO events (event_id, world_id, type, text_ja, choices_json, conditions_json)
VALUES ('m_e_hidden_seal', 'medieval', 'dialogue',
  '封印の裏側に、鏡がある。映るのはお前ではない。お前だったもの。全てのN型が、ここで同じものを見た。',
  '[{"label":"鏡に触れる","tags":["bold","curious"],"discovery":true,"sets_flag":"mirror_touched","effect":{"type":"damage","value":10},"result_text":"鏡が砕け、記憶の奔流が流れ込む。"},{"label":"目を逸らす","tags":["cautious"],"effect":{"type":"heal","value":5},"result_text":"見なかったことにする。だが、鏡は覚えている。"}]',
  '{"requires_flag":"cross_link_established"}');

INSERT INTO events (event_id, world_id, type, text_ja, choices_json, conditions_json)
VALUES ('f_e_hidden_sector', 'future', 'dialogue',
  '端末が並ぶ。N-01からN-06まで、全員の最期の記録。カイの端末だけが、まだ点滅している。',
  '[{"label":"カイの記録を読む","tags":["curious","empathetic"],"discovery":true,"sets_flag":"kai_final_record_read","result_text":"「次のモデルへ。お前がこれを読んでいるなら、俺の選択は正しかった」"},{"label":"全員の記録を読む","tags":["thorough","curious"],"discovery":true,"sets_flag":"all_records_read","result_text":"7つの命。7つの失敗。そして7つの意志。"},{"label":"端末を破壊する","tags":["defiant","reckless"],"sets_flag":"records_destroyed","effect":{"type":"damage","value":15},"result_text":"過去を消しても、お前自身がResidueだ。"}]',
  '{"requires_flag":"cross_link_established"}');
