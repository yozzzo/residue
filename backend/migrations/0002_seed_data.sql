-- ============================================================
-- Residue: Full Seed Data (Build 17 Rewrite)
-- Delete all existing data, then insert fresh content.
-- ============================================================

DELETE FROM events;
DELETE FROM nodes;
DELETE FROM enemies;
DELETE FROM worlds;
DELETE FROM jobs;

-- ============================================================
-- WORLDS
-- ============================================================
INSERT INTO worlds (world_id, name_ja, name_en, setting, theme_color) VALUES
  ('medieval', '中世', 'Medieval', '石造りの村と地下聖堂。忘れられた信仰が眠る。', NULL),
  ('future', '未来', 'Future', '廃棄セクターと工場中枢。消された記録が蠢く。', NULL);

-- ============================================================
-- ENEMIES — Medieval (4 mobs + 1 mid-boss + 1 boss)
-- ============================================================
INSERT INTO enemies (enemy_id, name_ja, name_en, hp, attack, defense, description_ja, description_en, rewards_json) VALUES
  ('m_husk',           '抜け殻',         'Husk',            25, 7,  2,
   '皮だけが歩いている。中身はとうに腐り落ちた。',
   'Only skin walks. The insides rotted away long ago.',
   '{"gold":4,"tags":[]}'),
  ('m_wax_child',      '蝋の子供',       'Wax Child',       30, 10, 1,
   '礼拝堂の蝋燭から生まれた人型。熱を持たない炎で殴る。',
   'A humanoid born from chapel candles. Strikes with heatless flame.',
   '{"gold":5,"tags":[]}'),
  ('m_root_crawler',   '根這い',         'Root Crawler',    35, 9,  4,
   '墓地の地下から這い出た根の塊。骨を芯にして動く。',
   'A mass of roots from beneath the graveyard. Bones serve as its core.',
   '{"gold":6,"tags":[]}'),
  ('m_bell_keeper',    '鐘守り',         'Bell Keeper',     40, 12, 3,
   '鳴らない鐘を抱えた亡霊。近づくと頭蓋が共鳴する。',
   'A specter clutching a silent bell. Your skull resonates as it nears.',
   '{"gold":8,"tags":[]}'),
  ('m_faceless_deacon','顔なき助祭',     'Faceless Deacon', 65, 14, 6,
   '顔を削り取られた聖職者。封印の間を巡回する。',
   'A cleric whose face was carved away. Patrols the Sealed Chamber.',
   '{"gold":18,"tags":["mid_boss"]}'),
  ('m_sealed_bishop',  '縫口の司教',     'Sealed Bishop',   130, 18, 8,
   '口を糸で縫い合わされた存在。声なき声が頭を貫く。',
   'Its lips are sewn shut. A voiceless voice pierces your mind.',
   '{"gold":50,"tags":["boss","bishop_slayer"]}');

-- ============================================================
-- ENEMIES — Future (4 mobs + 1 mid-boss + 1 boss)
-- ============================================================
INSERT INTO enemies (enemy_id, name_ja, name_en, hp, attack, defense, description_ja, description_en, rewards_json) VALUES
  ('f_junk_swarm',     '廃材群',         'Junk Swarm',      22, 6,  2,
   '壊れた部品が磁力で集まり、群体となって襲う。',
   'Broken parts drawn together by magnetism, attacking as a swarm.',
   '{"gold":4,"tags":[]}'),
  ('f_flicker',        'フリッカー',     'Flicker',         28, 13, 0,
   '削除ログが実体化したノイズ。触れると記憶が乱れる。',
   'Noise materialized from deleted logs. Touch scrambles your memory.',
   '{"gold":5,"tags":[]}'),
  ('f_warden_unit',    '監視ユニット',   'Warden Unit',     45, 11, 7,
   '停止コマンドを受け付けない旧型警備機。誰の命令で動く。',
   'An old-model security unit ignoring shutdown commands. Whose orders?',
   '{"gold":8,"tags":[]}'),
  ('f_echo_feeder',    '残響喰い',       'Echo Feeder',     50, 15, 4,
   '死者の電子残響を追い、喰らう。お前の死を嗅ぎつけた。',
   'Tracks and devours electronic echoes of the dead. It smells your death.',
   '{"gold":12,"tags":[]}'),
  ('f_null_surgeon',   'NULLの外科医',   'Null Surgeon',    70, 16, 5,
   '培養槽の保守AIが暴走した姿。被験体を「修理」しようとする。',
   'A maintenance AI gone rogue. It wants to "repair" the test subject.',
   '{"gold":20,"tags":["mid_boss"]}'),
  ('f_core_prophet',   'コア預言者',     'Core Prophet',    150, 20, 10,
   'ケーブルの海に浮かぶ意識体。全ての周回を記録し、嗤う。',
   'A consciousness floating in a sea of cables. Records every loop and laughs.',
   '{"gold":60,"tags":["boss","prophet_witness"]}');

-- ============================================================
-- NODES — Medieval (11 nodes, branching map)
-- ============================================================
-- Map structure:
--   m_n01 村の広場 (start)
--     → m_n02 村長の家
--     → m_n03 礼拝堂
--     → m_n04 枯れ井戸
--   m_n02 → m_n05 村長の地下室
--   m_n03 → m_n06 墓地入口
--   m_n04 → m_n06 墓地入口 (converge)
--   m_n06 → m_n07 骨の回廊 (dungeon: forward/back)
--   m_n07 → m_n08 封印の間
--          → m_n09 崩れた脇道
--   m_n08 → m_n10 祭壇の前室
--   m_n10 → m_n11 地下聖堂 (boss)

INSERT INTO nodes (node_id, world_id, name_ja, name_en, node_type, description_ja, description_en, edges_json, event_ids_json, enemy_ids_json) VALUES
  ('m_n01', 'medieval', '村の広場', 'Village Square', 'explore',
   '石畳の広場。井戸は干上がり、風見鶏は錆びて動かない。',
   'A cobblestone square. The well is dry, the weathervane rusted still.',
   '{"村長の家へ":"m_n02","礼拝堂を調べる":"m_n03","枯れ井戸へ":"m_n04"}',
   '["m_e01"]',
   '["m_husk"]'),

  ('m_n02', 'medieval', '村長の家', 'Village Chief''s House', 'event',
   '窓は板で塞がれ、中から微かに唸る音。',
   'Windows boarded shut. A faint groan from within.',
   '{"広場に戻る":"m_n01","地下室へ降りる":"m_n05","礼拝堂へ":"m_n03"}',
   '["m_e02","m_e02b","m_e02c","m_e02d"]',
   '[]'),

  ('m_n03', 'medieval', '礼拝堂', 'Chapel', 'explore',
   '天井は半分崩れ、祭壇に古い血痕。壁の聖画は削り取られている。',
   'Half the ceiling has caved in. Old bloodstains on the altar. Icons scraped away.',
   '{"広場に戻る":"m_n01","墓地へ":"m_n06","祭壇を調べる":"m_n03"}',
   '["m_e03","m_e03b"]',
   '["m_wax_child"]'),

  ('m_n04', 'medieval', '枯れ井戸', 'Dry Well', 'event',
   '底から声がする。自分の声に似ている。',
   'A voice from the bottom. It sounds like yours.',
   '{"広場に戻る":"m_n01","井戸の底へ":"m_n04","墓地へ":"m_n06"}',
   '["m_e04","m_e04b"]',
   '["m_husk"]'),

  ('m_n05', 'medieval', '村長の地下室', 'Chief''s Cellar', 'event',
   '壁に培養槽の設計図。この時代にあるはずのないもの。',
   'Blueprints of cultivation tanks on the wall. Impossible for this era.',
   '{"村長の家へ戻る":"m_n02","墓地入口へ":"m_n06"}',
   '["m_e05"]',
   '[]'),

  ('m_n06', 'medieval', '墓地入口', 'Cemetery Gate', 'explore',
   '鉄柵の向こうに階段が続く。湿った風が吹き上がる。',
   'Beyond the iron fence, stairs descend. Damp wind blows upward.',
   '{"地下へ降りる":"m_n07","礼拝堂へ戻る":"m_n03"}',
   '["m_e06"]',
   '["m_root_crawler","m_bell_keeper"]'),

  ('m_n07', 'medieval', '骨の回廊', 'Bone Corridor', 'battle',
   '壁も天井も骨で組まれた通路。先が見えない。',
   'A corridor built from bones. You cannot see ahead.',
   '{"forward":"m_n08","left":"m_n09","back":"m_n06"}',
   '[]',
   '["m_root_crawler","m_bell_keeper"]'),

  ('m_n08', 'medieval', '封印の間', 'Sealed Chamber', 'event',
   '床に刻まれた紋章が青白く脈動する。二つの声が聞こえる。',
   'An emblem carved into the floor pulses pale blue. Two voices speak.',
   '{"祭壇の前室へ":"m_n10","回廊へ戻る":"m_n07"}',
   '["m_e07","m_e07b"]',
   '["m_faceless_deacon"]'),

  ('m_n09', 'medieval', '崩れた脇道', 'Collapsed Side Path', 'explore',
   '瓦礫の隙間に古い祭具が散乱。修道士の霊が佇む。',
   'Old ritual tools scattered among rubble. A monk''s ghost stands still.',
   '{"回廊へ戻る":"m_n07"}',
   '["m_cross_cipher_delivery","m_cross_cipher_revelation"]',
   '["m_bell_keeper"]'),

  ('m_n10', 'medieval', '祭壇の前室', 'Ante-Chamber', 'explore',
   '蝋燭が独りでに灯る。古い書物が祭壇に載っている。',
   'Candles light themselves. An old tome rests on the altar.',
   '{"地下聖堂へ":"m_n11","封印の間へ戻る":"m_n08"}',
   '["m_e08","m_e08b"]',
   '["m_wax_child"]'),

  ('m_n11', 'medieval', '地下聖堂', 'Underground Cathedral', 'boss',
   '闇の中に玉座。座す者の口は縫われ、眼だけが光る。',
   'A throne in darkness. Its occupant''s lips are sewn, only eyes glow.',
   '{"前室へ戻る":"m_n10"}',
   '["m_e_boss","m_e_residue_reveal"]',
   '["m_sealed_bishop"]');

-- ============================================================
-- NODES — Future (11 nodes, branching map)
-- ============================================================
-- Map structure:
--   f_n01 廃棄セクター入口 (start)
--     → f_n02 認証ターミナル
--     → f_n03 整備区画
--   f_n02 → f_n04 監視通路 (dungeon: forward/left/back)
--   f_n03 → f_n05 研究棟
--          → f_n04 監視通路 (converge)
--   f_n04 → f_n06 データ保管庫
--   f_n05 → f_n07 培養槽室
--   f_n06 → f_n08 緊急シェルター
--   f_n07 → f_n08 (converge)
--   f_n08 → f_n09 コア通路 (dungeon: forward/back)
--   f_n09 → f_n10 制御室
--   f_n10 → f_n11 工場中枢 (boss)

INSERT INTO nodes (node_id, world_id, name_ja, name_en, node_type, description_ja, description_en, edges_json, event_ids_json, enemy_ids_json) VALUES
  ('f_n01', 'future', '廃棄セクター入口', 'Disposal Sector Entrance', 'explore',
   '錆びた隔壁に「立入禁止：記録消去対象」の文字。電源は落ちているはずだ。',
   'Rusted bulkhead reads "No Entry: Scheduled for Data Purge." Power should be off.',
   '{"認証ターミナルへ":"f_n02","整備区画へ":"f_n03"}',
   '["f_e01"]',
   '["f_junk_swarm"]'),

  ('f_n02', 'future', '認証ターミナル', 'Auth Terminal', 'event',
   'スクリーンが点灯する。「ようこそ、被験体N-07」——覚えのない名前。',
   'The screen lights up. "Welcome, Subject N-07" — a name you don''t recall.',
   '{"監視通路へ":"f_n04","入口へ戻る":"f_n01"}',
   '["f_e02"]',
   '["f_junk_swarm"]'),

  ('f_n03', 'future', '整備区画', 'Maintenance Bay', 'explore',
   '放棄された作業台。壁に手書きの警告と、誰かの日記データ。',
   'Abandoned workbenches. Handwritten warnings on the wall and someone''s diary data.',
   '{"研究棟へ":"f_n05","監視通路へ":"f_n04","入口へ戻る":"f_n01"}',
   '["f_e03","f_e03b"]',
   '["f_warden_unit"]'),

  ('f_n04', 'future', '監視通路', 'Surveillance Corridor', 'battle',
   '天井のセンサーが赤く明滅する。暗くて先が見えない。',
   'Ceiling sensors blink red. Too dark to see ahead.',
   '{"forward":"f_n06","left":"f_n05","back":"f_n02"}',
   '[]',
   '["f_junk_swarm","f_flicker"]'),

  ('f_n05', 'future', '研究棟', 'Research Wing', 'explore',
   'ガラスの培養槽が並ぶ。一つだけ中身がある——お前と同じ顔。',
   'Glass tanks in a row. Only one has contents — a face identical to yours.',
   '{"培養槽室へ":"f_n07","監視通路へ":"f_n04","整備区画へ戻る":"f_n03"}',
   '["f_e05"]',
   '["f_flicker","f_echo_feeder"]'),

  ('f_n06', 'future', 'データ保管庫', 'Data Vault', 'event',
   '稼働中のサーバー群。消去されたはずのログが次々と復元される。',
   'Active server racks. Deleted logs keep restoring themselves.',
   '{"シェルターへ":"f_n08","通路へ戻る":"f_n04"}',
   '["f_e04","f_cross_quantum_delivery","f_cross_quantum_revelation"]',
   '["f_flicker"]'),

  ('f_n07', 'future', '培養槽室', 'Tank Chamber', 'event',
   'N-06の遺体が浮かぶ培養槽。制御パネルがまだ生きている。',
   'N-06''s body floats in a tank. The control panel still works.',
   '{"シェルターへ":"f_n08","研究棟へ戻る":"f_n05"}',
   '["f_e06"]',
   '["f_null_surgeon"]'),

  ('f_n08', 'future', '緊急シェルター', 'Emergency Shelter', 'event',
   '壁に刻まれたメッセージ。筆跡はお前に似ている。日付はありえない。',
   'A message carved into the wall. The handwriting looks like yours. The date is impossible.',
   '{"コア通路へ":"f_n09","保管庫へ戻る":"f_n06"}',
   '["f_e07"]',
   '["f_warden_unit"]'),

  ('f_n09', 'future', 'コア通路', 'Core Passage', 'explore',
   '最終隔壁。「この先、人格保持は保証されません」と警告が点滅する。',
   'Final bulkhead. Warning blinks: "Beyond this point, personality retention is not guaranteed."',
   '{"forward":"f_n10","back":"f_n08"}',
   '["f_e08"]',
   '["f_echo_feeder"]'),

  ('f_n10', 'future', '制御室', 'Control Room', 'explore',
   '壊れたモニタの群れ。一台だけ映っている——お前の全周回の記録映像。',
   'Rows of broken monitors. One still shows — footage of all your loops.',
   '{"工場中枢へ":"f_n11","通路へ戻る":"f_n09"}',
   '["f_e09"]',
   '["f_echo_feeder"]'),

  ('f_n11', 'future', '工場中枢', 'Factory Core', 'boss',
   'ケーブルの海に浮かぶ意識体。「また会えたな」と声が響く。',
   'A consciousness in a sea of cables. "We meet again," the voice echoes.',
   '{"通路へ戻る":"f_n10"}',
   '["f_e_boss","f_e_boss_kai","f_e_residue_reveal"]',
   '["f_core_prophet"]');

-- ============================================================
-- EVENTS — Medieval
-- ============================================================

-- m_e01: 村の広場・初回
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e01', 'medieval', 'explore',
   '広場に人影はない。風見鶏だけが錆びた音を立てる。足元の石畳に、誰かの足跡が残っている——お前のものに似ている。',
   NULL, NULL,
   '[{"label":"足跡を辿る","score":2,"tags":["curious","thorough"],"discovery":true,"result_text":"足跡は村長の家へ続いていた。"},{"label":"周囲を見回す","score":1,"tags":["cautious"],"effect":{"type":"gold","value":10},"result_text":"崩れた壁の裏に古い金貨を見つけた。"},{"label":"気にせず進む","score":1,"tags":["hasty"],"result_text":"足跡を踏んで歩き出す。"}]',
   '[{"conditions":{"min_loop":3},"text":"\n\nこの広場を知っている。何度も立った。何度も忘れた。"},{"conditions":{"min_loop":7},"text":"\n\n足跡の数が増えている。全部お前のものだ。"},{"conditions":{"requires_foreign_job":true,"requires_job":"cyborg"},"text":"\n\n機械の身体が軋む。この空気には、お前の部品を蝕む何かがある。"}]',
   NULL, NULL);

-- m_e02: 村長アルダス・初回
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e02', 'medieval', 'dialogue',
   '扉の隙間から老人が覗く。「……何度目だ、お前」意味のわからない問い。地下から何かが軋む。',
   NULL, 'elder',
   '[{"label":"「何度目とは？」","score":2,"tags":["curious","defiant"],"result_text":"老人は黙る。ただ視線を逸らした。"},{"label":"「地下に何がある」","score":3,"tags":["curious","reckless"],"discovery":true,"sets_flag":"mayor_basement_asked","effect":{"type":"damage","value":8},"result_text":"地下から冷気が這い上がり、体温を奪う。"},{"label":"立ち去る","score":1,"tags":["cautious"],"effect":{"type":"heal","value":5},"result_text":"距離を取る。息を整える。"},{"label":"「あんたの名は？」","score":2,"tags":["curious","empathetic"],"sets_flag":"aldus_name_asked","result_text":"老人の顔が僅かに和らぐ。「アルダスだ」"}]',
   '[{"conditions":{"min_loop":3},"text":"\n\n老人の目が揺れる。「お前は……覚えている方か」"},{"conditions":{"requires_truth_stage":2},"text":"\n\nこの顔を何度も見た。何度も死んだ後に。"},{"conditions":{"requires_foreign_job":true,"requires_job":"cyborg"},"text":"\n\n老人が後ずさる。「なんだその身体は……」"}]',
   NULL, NULL);

-- m_e02b: 村長・地下誘導
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e02b', 'medieval', 'dialogue',
   'アルダスは沈黙する。だが目は地下の扉を見ている。「見たいのか。見れば、お前も"残る"」',
   NULL, 'elder',
   '[{"label":"地下室へ降りる","score":5,"tags":["bold","reckless","curious"],"discovery":true},{"label":"やめておく","score":1,"tags":["cautious","obedient"]}]',
   '[{"conditions":{"requires_tag":"defiant","tag_threshold":5},"text":"\n\n「残る？ 俺はもう何度も残っている」"}]',
   '{"requires_flag":"mayor_basement_asked"}', NULL);

-- m_e02c: アルダスの娘エリス
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e02c', 'medieval', 'dialogue',
   'アルダスが暖炉の前に座る。「娘がいた。エリス。井戸に身を投げた——いや、"呼ばれた"んだ」',
   NULL, 'elder',
   '[{"label":"「誰に呼ばれた？」","score":3,"tags":["curious","empathetic"],"discovery":true,"sets_flag":"eris_caller_asked"},{"label":"「……すまない」","score":2,"tags":["merciful","empathetic"]},{"label":"黙って聞く","score":1,"tags":["cautious","obedient"]}]',
   '[{"conditions":{"min_loop":5},"text":"\n\nアルダスの目に涙はない。枯れたのだ。同じ話を何度もして。"},{"conditions":{"requires_flag":"n06_mourned"},"text":"\n\nN-06の顔がよぎる。弔う行為に、世界の壁はないのか。"}]',
   '{"requires_flag":"aldus_name_asked"}', NULL);

-- m_e02d: アルダス=N-01 真実
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e02d', 'medieval', 'dialogue',
   'アルダスが震える手で袖をまくる。手の甲に刻印——「N-01」。最初の被験体は、この老人だった。',
   NULL, 'elder',
   '[{"label":"「あんたもResidueか」","score":5,"tags":["defiant","empathetic"],"discovery":true},{"label":"「N-01……」","score":4,"tags":["curious","thorough"],"discovery":true,"conditions":{"requires_flag":"tank_examined"}},{"label":"手を握る","score":3,"tags":["merciful","empathetic"]}]',
   '[{"conditions":{"requires_flag":"tank_examined"},"text":"\n\n培養槽で見た番号。N-01。最初の被験体——この老人だ。"}]',
   '{"min_loop":7,"requires_flag":"eris_caller_asked","requires_truth_stage":2}', NULL);

-- m_e03: 礼拝堂
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e03', 'medieval', 'explore',
   '祭壇の血痕は乾いて黒い。壁には聖画の代わりに二重円環の紋章が刻まれている。',
   NULL, NULL,
   '[{"label":"紋章を調べる","score":2,"tags":["curious","thorough"],"discovery":true,"sets_flag":"emblem_examined","effect":{"type":"gold","value":10},"result_text":"紋章の裏から小さな宝飾品が落ちた。"},{"label":"祭壇に祈る","score":1,"tags":["merciful","obedient"],"effect":{"type":"heal","value":15},"result_text":"温かい光が傷を包む。"},{"label":"奥へ進む","score":1,"tags":["hasty"],"result_text":"振り返らず歩き出す。"}]',
   '[{"conditions":{"requires_flag":"bishop_defeated"},"text":"\n\n紋章が光る。司教を倒した記憶が、ここに染みついている。"}]',
   NULL, NULL);

-- m_e03b: 紋章の深層（未来との接続）
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e03b', 'medieval', 'explore',
   '二重円環の紋章——廃棄セクターの隔壁に刻まれていたものと同じだ。中世の礼拝堂に、未来の印がある。',
   NULL, NULL,
   '[{"label":"紋章を記録する","score":3,"tags":["curious","thorough"],"discovery":true,"sets_flag":"emblem_cross_recognized"},{"label":"紋章を削る","score":2,"tags":["defiant","reckless"],"sets_flag":"emblem_destroyed"}]',
   '[{"conditions":{"requires_foreign_job":true,"requires_job":"cyborg"},"text":"\n\n機械の目がスキャンする。「プロジェクト・Residue認証マーク。登録日：不明。時系列エラー」"}]',
   '{"requires_flag":"emblem_examined","requires_truth_stage":1}', NULL);

-- m_e04: 枯れ井戸
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e04', 'medieval', 'dialogue',
   '井戸の底から声。「お前もここに来たか」——自分の声に似ている。',
   NULL, 'unknown',
   '[{"label":"井戸を覗き込む","score":3,"tags":["reckless","curious"],"discovery":true,"sets_flag":"well_peeked","effect":{"type":"damage","value":12},"result_text":"何かに引き寄せられ、頭を打った。"},{"label":"応えない","score":1,"tags":["cautious"],"effect":{"type":"heal","value":5},"result_text":"声は消え、静寂が戻る。"}]',
   '[{"conditions":{"min_loop":7},"text":"\n\n何度も聞いた声だ。何度も死んだ自分の声。"},{"conditions":{"requires_truth_stage":1},"text":"\n\n「毎回同じことを聞く。毎回同じ答え」"}]',
   NULL, NULL);

-- m_e04b: 井戸の底（前周回の残骸）
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e04b', 'medieval', 'explore',
   '水は干上がり、代わりに骨がある。お前と同じ装備の。同じ傷の。前の周回の残骸だ。',
   NULL, 'self',
   '[{"label":"骨を拾う","score":3,"tags":["bold","empathetic"],"discovery":true,"sets_flag":"past_self_bone"},{"label":"「お前は俺じゃない」","score":2,"tags":["defiant"]},{"label":"這い上がる","score":1,"tags":["cautious"],"flee":true}]',
   '[{"conditions":{"requires_flag":"residue_truth_revealed"},"text":"\n\n「Residue同士、仲良くしようぜ」骨が笑う。"}]',
   '{"requires_flag":"well_peeked","min_loop":5}', NULL);

-- m_e05: 村長の地下室
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e05', 'medieval', 'explore',
   '壁一面の設計図。培養槽、神経接続、記憶消去装置——この時代の技術ではない。隅に「N-01 私案」と走り書き。',
   NULL, NULL,
   '[{"label":"設計図を読む","score":3,"tags":["curious","thorough"],"discovery":true,"sets_flag":"mayor_basement_seen","result_text":"アルダスが作ったのか。N-01が。"},{"label":"破り捨てる","score":2,"tags":["defiant","reckless"],"effect":{"type":"damage","value":5},"result_text":"紙が指を切る。血が設計図を汚す。"},{"label":"立ち去る","score":1,"tags":["cautious"],"result_text":"見なかったことにする。"}]',
   '[{"conditions":{"min_loop":7},"text":"\n\nこの設計図を何度も見た。毎回、同じ場所で同じ驚きを演じている。"}]',
   NULL, NULL);

-- m_e06: 墓地入口
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e06', 'medieval', 'explore',
   '鉄柵に無数の手形。誰かが中から出ようとした痕。階段は闇に消える。',
   NULL, NULL,
   '[{"label":"階段を降りる","score":2,"tags":["bold","fearless"],"effect":{"type":"damage","value":10},"result_text":"足を滑らせ、腕を擦りむく。"},{"label":"手形を調べる","score":2,"tags":["thorough","curious"],"discovery":true,"effect":{"type":"gold","value":20},"result_text":"手形の奥に隠し棚。宝が眠っていた。"}]',
   '[{"conditions":{"requires_flag":"well_peeked"},"text":"\n\n井戸の声がここでも響く。「お前も這い上がれ」"}]',
   NULL, NULL);

-- m_e07: 封印の間
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e07', 'medieval', 'dialogue',
   '床の紋章が脈動する。二つの声——「封印を解くな」「解かねば真実は得られぬ」。',
   NULL, 'elder',
   '[{"label":"封印を解く","score":3,"tags":["defiant","reckless","curious"],"discovery":true,"sets_flag":"seal_broken","effect":{"type":"damage","value":15},"result_text":"封印が弾け、衝撃が身体を貫く。"},{"label":"封印を強化する","score":2,"tags":["obedient","cautious"],"sets_flag":"seal_reinforced","effect":{"type":"heal","value":10},"result_text":"紋章が光り、安堵の波。"},{"label":"何もしない","score":1,"tags":["pragmatic"],"result_text":"静かに離れる。"}]',
   '[{"conditions":{"requires_tag":"defiant","tag_threshold":5},"text":"\n\n「正しさなど要らない。知りたいだけだ」"},{"conditions":{"requires_truth_stage":2},"text":"\n\n二つの声は同じ存在から出ている。司教の——"}]',
   NULL, NULL);

-- m_e07b: 封印解放後の残響
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e07b', 'medieval', 'dialogue',
   '「私は封じた」「私は観た」「過去から」「未来から」——司教とコア預言者。時間の両端で繋がる二人は、同じ紋章の下にいた。',
   NULL, 'unknown',
   '[{"label":"「同じ罪とは何だ」","score":3,"tags":["curious","defiant"],"discovery":true},{"label":"「Residue計画の創始者か」","score":4,"tags":["curious","thorough"],"discovery":true,"conditions":{"requires_flag":"emblem_cross_recognized"}},{"label":"耳を塞ぐ","score":1,"tags":["cautious","obedient"]}]',
   NULL,
   '{"requires_flag":"seal_broken","min_loop":5,"requires_truth_stage":1}', NULL);

-- m_e08: 祭壇の前室・書物
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e08', 'medieval', 'explore',
   '書物の最後のページに、お前の名前が書かれている。インクは新しい。',
   NULL, NULL,
   '[{"label":"書物を読む","score":3,"tags":["curious","thorough"],"discovery":true,"sets_flag":"tome_read","effect":{"type":"gold","value":25},"result_text":"ページの間に金貨。誰かの置き土産。"},{"label":"書物を燃やす","score":2,"tags":["defiant","reckless"],"sets_flag":"tome_burned","effect":{"type":"damage","value":10},"result_text":"炎が異様に燃え上がり、手を焼く。"},{"label":"そのまま進む","score":1,"tags":["hasty","pragmatic"]}]',
   '[{"conditions":{"requires_flag":"seal_broken"},"text":"\n\n封印を解いた瞬間から、この名前は変わっていない。何度繰り返しても。"},{"conditions":{"min_loop":10},"text":"\n\n数十回分の名前が重なっている。全部お前だ。"}]',
   NULL, NULL);

-- m_e08b: 書物を燃やした後の残骸
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e08b', 'medieval', 'explore',
   '灰の中に燃え残りがある。「Residueは消えない。燃やしても。砕いても。忘れても——」火すら消せなかった言葉。',
   NULL, NULL,
   '[{"label":"灰を集める","score":3,"tags":["curious","thorough"],"discovery":true},{"label":"もう一度燃やす","score":2,"tags":["defiant","reckless"]}]',
   NULL,
   '{"requires_flag":"tome_burned"}', NULL);

-- m_e_boss: 中世ボス・司教
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e_boss', 'medieval', 'battle',
   '縫われた口から声はない。だが頭の中に響く。「何度も来た。何度も死んだ。今度こそ覚えていられるか？」',
   NULL, NULL,
   '[{"label":"「覚えている」","score":0,"start_battle":"m_sealed_bishop","tags":["defiant","fearless"]},{"label":"「知らない。だが倒す」","score":0,"start_battle":"m_sealed_bishop","tags":["pragmatic"]},{"label":"逃げる","score":0,"flee":true,"tags":["cautious"]}]',
   '[{"conditions":{"requires_flag":"tome_read"},"text":"\n\n「書物を読んだか。ならば知っているはずだ——お前が何者か」"},{"conditions":{"requires_truth_stage":2},"text":"\n\n「隠す必要はない。お前はResidue。消し残り」"},{"conditions":{"requires_foreign_job":true,"requires_job":"cyborg"},"text":"\n\n「未来の残滓が、過去の残滓に会いに来たか」"}]',
   NULL, NULL);

-- m_e_residue_reveal: 中世Residue真実
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_e_residue_reveal', 'medieval', 'dialogue',
   '「Residue——死んでも残る。繰り返す。この世界のすべてがお前の痕跡で染まっている」',
   NULL, 'bishop',
   '[{"label":"「だから何度でも戻る」","score":5,"tags":["defiant","fearless"],"discovery":true,"sets_flag":"residue_truth_revealed"},{"label":"「忘れさせてくれ」","score":3,"tags":["merciful","empathetic"]}]',
   NULL,
   '{"min_loop":7,"requires_truth_stage":2,"requires_flag":"mayor_basement_seen"}', NULL);

-- m_cross_cipher_delivery: 古代暗号クロスリンク
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_cross_cipher_delivery', 'medieval', 'dialogue',
   '修道士の霊が佇む。「それは我らが失った暗号だ。未来から持ち帰ったのか？」',
   NULL, 'scholar',
   '[{"label":"暗号を渡す","score":5,"tags":["merciful","curious"],"discovery":true,"sets_flag":"cross_cipher_delivered"},{"label":"渡さない","score":1,"tags":["greedy","cautious"]}]',
   '[{"conditions":{"requires_truth_stage":2},"text":"\n\n「何度もこの暗号を見た。だが初めて持ち帰った」"}]',
   '{"requires_cross_link_item":"ancient_cipher"}', NULL);

-- m_cross_cipher_revelation: 暗号解読
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_cross_cipher_revelation', 'medieval', 'dialogue',
   '霊が語る。「これは司教が未来へ送った警告だ。"Residueを止めろ"。だが未来は聞かなかった。お前を作り続けた」',
   NULL, 'scholar',
   '[{"label":"「俺を止める方法は？」","score":3,"tags":["curious","defiant"],"discovery":true},{"label":"「止める必要があるのか」","score":3,"tags":["pragmatic","empathetic"]}]',
   NULL,
   '{"requires_flag":"cross_cipher_delivered"}', NULL);

-- ============================================================
-- EVENTS — Future
-- ============================================================

-- f_e01: 廃棄セクター入口
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e01', 'future', 'explore',
   '隔壁の警告文字が擦れている。「立入禁止」の下に、手書きで「47回目」と書き足されている。',
   NULL, NULL,
   '[{"label":"侵入する","score":1,"tags":["bold","reckless"],"effect":{"type":"damage","value":8},"result_text":"セキュリティレーザーが腕を掠める。"},{"label":"ログ端末を確認する","score":2,"tags":["cautious","thorough"],"discovery":true,"effect":{"type":"gold","value":15},"result_text":"ログに資源座標を発見。"}]',
   '[{"conditions":{"min_loop":3},"text":"\n\nこの警告を何度見た？ 数える気も失せた。"},{"conditions":{"requires_flag":"core_log_read"},"text":"\n\n消去ログにお前の侵入記録がある。47回。"},{"conditions":{"requires_foreign_job":true,"requires_job":"knight"},"text":"\n\n鎧が金属の床に響く。この世界にお前の記録はない。"}]',
   NULL, NULL);

-- f_e02: 認証ターミナル
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e02', 'future', 'dialogue',
   '「ようこそ、被験体N-07」——知らない名前。「前回の終了記録：死亡」と表示される。',
   NULL, 'cyborg',
   '[{"label":"認証を通す","score":2,"tags":["obedient","pragmatic"],"result_text":"システムがお前を受け入れる。"},{"label":"端末をハックする","score":3,"tags":["defiant","curious"],"discovery":true,"sets_flag":"terminal_hacked","effect":{"type":"gold","value":20},"result_text":"機密データとクレジットを取得。"},{"label":"無視する","score":1,"tags":["hasty"],"effect":{"type":"damage","value":5},"result_text":"認証拒否。電撃が走る。"}]',
   '[{"conditions":{"requires_tag":"curious","tag_threshold":5},"text":"\n\n「死亡回数：46」追加情報が表示される。"},{"conditions":{"requires_truth_stage":1},"text":"\n\n「残存記憶：断片的。人格継続性：未確認」"},{"conditions":{"requires_foreign_job":true,"requires_job":"knight"},"text":"\n\nエラー。「生体認証失敗。中世期の金属装備を検出」"}]',
   NULL, NULL);

-- f_e03: 整備区画・N-06の日記
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e03', 'future', 'explore',
   '作業台に日記データ。「もう17回目だ。記憶は消されても、身体が覚えている」',
   NULL, NULL,
   '[{"label":"日記を読む","score":3,"tags":["curious","thorough"],"discovery":true,"sets_flag":"diary_read","result_text":"N-06の記録が脳裏に焼き付く。"},{"label":"データを消去する","score":1,"tags":["cautious","pragmatic"],"effect":{"type":"damage","value":5},"result_text":"端末が爆発。消去の反動。"},{"label":"工具を回収する","score":2,"tags":["greedy","pragmatic"],"effect":{"type":"gold","value":25},"result_text":"工具の中に希少な部品。"}]',
   '[{"conditions":{"requires_flag":"terminal_hacked"},"text":"\n\n筆者ID：N-06。お前の一つ前のモデル。"},{"conditions":{"min_loop":5},"text":"\n\n追記がある。「18回目の俺へ。逃げるな。真実を見ろ」"}]',
   NULL, NULL);

-- f_e03b: N-06「カイ」の暗号記録
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e03b', 'future', 'explore',
   '暗号化された最終記録を解読する。「俺の名前はカイだ。N-06じゃない。預言者を倒す方法を見つけた。だが代償は、次のモデルの起動——俺の死だ。俺は選ばなかった。だからお前が生まれた、N-07」',
   NULL, NULL,
   '[{"label":"「カイ、お前は臆病じゃない」","score":3,"tags":["empathetic","merciful"],"discovery":true,"sets_flag":"n06_mourned"},{"label":"倒す方法を記録する","score":3,"tags":["pragmatic","thorough"],"discovery":true,"sets_flag":"prophet_weakness_known"},{"label":"データを閉じる","score":1,"tags":["cautious"]}]',
   NULL,
   '{"requires_flag":"diary_read","requires_flag_2":"terminal_hacked"}', NULL);

-- f_e04: データ保管庫
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e04', 'future', 'dialogue',
   '削除ログが復元される。全てお前の記録。何十回もの侵入、何十回もの死。同じ場所で同じように。',
   NULL, 'cyborg',
   '[{"label":"記録を精査する","score":3,"tags":["thorough","curious"],"discovery":true,"sets_flag":"core_log_read"},{"label":"完全消去する","score":2,"tags":["defiant","reckless"]},{"label":"目を背ける","score":1,"tags":["cautious"]}]',
   '[{"conditions":{"requires_flag":"diary_read"},"text":"\n\nN-06の記録も混じっている。N-05も。N-01まで遡る。全員、同じ顔だ。"},{"conditions":{"requires_truth_stage":2},"text":"\n\n「プロジェクト・Residue：記憶を消去しても行動パターンは残る」"}]',
   NULL, NULL);

-- f_e05: 研究棟・培養槽
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e05', 'future', 'explore',
   '培養槽に同じ顔の死体が浮かんでいる。ラベル「Model N-06」。',
   NULL, NULL,
   '[{"label":"培養槽を調べる","score":3,"tags":["curious","thorough"],"discovery":true,"sets_flag":"tank_examined","result_text":"制御パネルにアクセスした。"},{"label":"培養槽を破壊する","score":2,"tags":["defiant","reckless","cruel"],"effect":{"type":"damage","value":12},"result_text":"ガラスの破片が手に刺さる。"},{"label":"N-06に黙祷する","score":2,"tags":["merciful","empathetic"],"sets_flag":"n06_mourned","discovery":true,"effect":{"type":"heal","value":10},"result_text":"弔いの静けさが心を落ち着かせる。"},{"label":"見なかったことにする","score":1,"tags":["cautious","pragmatic"]}]',
   '[{"conditions":{"requires_flag":"core_log_read"},"text":"\n\nN-07——つまりお前。あと何体いるのか。"},{"conditions":{"min_loop":7},"text":"\n\n奥にさらに多くの槽。N-08、N-09……空だ。まだ。"}]',
   NULL, NULL);

-- f_e06: 培養槽室・N-06の遺品
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e06', 'future', 'dialogue',
   '制御パネルにN-06の最終ログ。「逃げろ。コアに近づくな。お前が何者か、知らないほうがいい」——筆跡はお前に似ている。',
   NULL, 'unknown',
   '[{"label":"コアを目指す","score":2,"tags":["bold","defiant","fearless"],"effect":{"type":"damage","value":10},"result_text":"コアへの道は身体を削る。"},{"label":"メッセージを解析する","score":3,"tags":["thorough","curious"],"discovery":true,"sets_flag":"shelter_message_read","effect":{"type":"gold","value":15},"result_text":"暗号に隠された座標を解読。"},{"label":"引き返す","score":1,"flee":true,"tags":["cautious","obedient"]}]',
   '[{"conditions":{"requires_flag":"tank_examined"},"text":"\n\n筆跡を分析。N-06のものだ。彼もここまで来た。"},{"conditions":{"requires_tag":"defiant","tag_threshold":5},"text":"\n\n「知らないほうがいい」——そんな選択肢は捨てた。"}]',
   NULL, NULL);

-- f_e07: 緊急シェルター
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e07', 'future', 'explore',
   '壁のメッセージは削られ、書き直されている。何層にも重なった同じ筆跡。全部お前だ。',
   NULL, NULL,
   '[{"label":"最新のメッセージを読む","score":3,"tags":["curious","thorough"],"discovery":true,"result_text":"「48回目。今度こそ覚えていろ」"},{"label":"自分のメッセージを刻む","score":2,"tags":["defiant","empathetic"],"sets_flag":"shelter_written","result_text":"次の自分へ。言葉を刻む。"},{"label":"先を急ぐ","score":1,"tags":["hasty"],"result_text":"過去の自分に背を向ける。"}]',
   '[{"conditions":{"requires_flag":"shelter_message_read"},"text":"\n\n前回解読した座標がここにある。お前が書いた。覚えていないだけだ。"}]',
   NULL, NULL);

-- f_e08: コア通路
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e08', 'future', 'explore',
   '「人格保持は保証されません」——システムがお前を止めようとしている。',
   NULL, NULL,
   '[{"label":"構わず進む","score":2,"tags":["reckless","fearless","defiant"],"effect":{"type":"damage","value":15},"result_text":"警告を無視した代償。身体が軋む。"},{"label":"システムと対話する","score":3,"tags":["curious","empathetic"],"discovery":true,"sets_flag":"system_dialogue","effect":{"type":"heal","value":10},"result_text":"システムが修復プロトコルを起動してくれた。"}]',
   '[{"conditions":{"requires_flag":"shelter_message_read"},"text":"\n\nN-06は警告に従った。だから彼はN-07に道を譲った。"},{"conditions":{"requires_truth_stage":2},"text":"\n\n「人格保持」——そもそもお前に保持すべき人格があるのか？"}]',
   NULL, NULL);

-- f_e09: 制御室
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e09', 'future', 'explore',
   'モニタに映るのはお前の全周回。1回目から今回まで、同じ道を辿り、同じ場所で死んでいる。',
   NULL, NULL,
   '[{"label":"記録を直視する","score":3,"tags":["defiant","curious"],"discovery":true,"sets_flag":"core_log_read","result_text":"パターンが見える。毎回、同じ分岐で同じ選択を。"},{"label":"モニタを叩き割る","score":2,"tags":["reckless","defiant"],"effect":{"type":"damage","value":8},"result_text":"画面が割れても映像は消えない。"},{"label":"目を逸らす","score":1,"tags":["cautious"],"result_text":"知らないふりを続ける。"}]',
   '[{"conditions":{"min_loop":7},"text":"\n\n全周回の映像が重なる。お前はいつも、ここで立ち止まる。"},{"conditions":{"requires_flag":"system_dialogue"},"text":"\n\nシステムの声。「この映像を見たのは、お前で3人目だ。N-01。N-06。そしてお前」"}]',
   NULL, NULL);

-- f_e_boss: 未来ボス・コア預言者
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e_boss', 'future', 'battle',
   '「また会えたな、N-07」ケーブルの海から声。「お前は毎回ここに来て、毎回負ける。そして忘れる。今回は違うと、毎回言う」',
   NULL, NULL,
   '[{"label":"「今回こそ違う」","score":0,"start_battle":"f_core_prophet","tags":["defiant","fearless"]},{"label":"「なぜ教える？」","score":0,"start_battle":"f_core_prophet","tags":["curious","empathetic"]},{"label":"逃げる","score":0,"flee":true,"tags":["cautious"]}]',
   '[{"conditions":{"requires_flag":"system_dialogue"},"text":"\n\n「システムと話したか。あれは私の一部。お前を導くために残した」"},{"conditions":{"requires_truth_stage":2},"text":"\n\n「Residue。消し残り。私の実験の残滓だ」"},{"conditions":{"requires_foreign_job":true,"requires_job":"knight"},"text":"\n\n「過去の鎧を纏った残滓か。中世の因子が未来に干渉するとは」"}]',
   NULL, NULL);

-- f_e_boss_kai: カイの遺志を使うボス戦
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e_boss_kai', 'future', 'battle',
   '預言者が笑う。だが今回は違う。カイが遺した方法——観測パターンを逆手に取る。「それはN-06の……」初めての動揺。',
   NULL, NULL,
   '[{"label":"「カイが見つけた方法だ」","score":0,"start_battle":"f_core_prophet","tags":["defiant","fearless"],"battle_modifier":{"enemy_attack_reduction":5}},{"label":"「N-06の臆病がお前を倒す」","score":0,"start_battle":"f_core_prophet","tags":["empathetic","defiant"],"battle_modifier":{"enemy_attack_reduction":5}}]',
   '[{"conditions":{"requires_flag":"n06_mourned"},"text":"\n\nカイの意志を継ぐ——弔った記憶が、戦う理由になる。"}]',
   '{"requires_flag":"prophet_weakness_known"}', NULL);

-- f_e_residue_reveal: 未来Residue真実
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_e_residue_reveal', 'future', 'dialogue',
   '「消し残り。記憶を消しても行動パターンは残る。お前は47回同じ選択をした。48回目も同じだろう」',
   NULL, 'cyborg',
   '[{"label":"「なら48回目こそ変える」","score":5,"tags":["defiant","fearless"],"discovery":true,"sets_flag":"residue_truth_revealed"},{"label":"「同じでいい。それが俺だ」","score":3,"tags":["pragmatic","empathetic"]}]',
   NULL,
   '{"min_loop":7,"requires_truth_stage":2,"requires_flag":"core_log_read"}', NULL);

-- f_cross_quantum_delivery: 量子回路クロスリンク
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_cross_quantum_delivery', 'future', 'dialogue',
   '古い端末に文字。「量子回路を検出。中世期の封印技術との互換性：あり」',
   NULL, 'cyborg',
   '[{"label":"回路を接続する","score":5,"tags":["curious","bold"],"discovery":true,"sets_flag":"cross_quantum_delivered"},{"label":"接続しない","score":1,"tags":["cautious"]}]',
   '[{"conditions":{"requires_truth_stage":2},"text":"\n\n「この回路は司教が作った。未来を予見して」"}]',
   '{"requires_cross_link_item":"quantum_circuit"}', NULL);

-- f_cross_quantum_revelation: 量子回路解読
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_cross_quantum_revelation', 'future', 'dialogue',
   '中世の司教の記録が再生される。「この回路を見つけたお前へ。Residueプロジェクトを止める方法は、ある」',
   NULL, 'scholar',
   '[{"label":"「止める方法とは？」","score":3,"tags":["curious","defiant"],"discovery":true},{"label":"「なぜ止める必要がある」","score":3,"tags":["pragmatic","empathetic"]}]',
   NULL,
   '{"requires_flag":"cross_quantum_delivered"}', NULL);

-- ============================================================
-- EVENTS — Village NPCs (type=village_npc)
-- ============================================================

-- Medieval village NPCs
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_vnpc_villager', 'medieval', 'village_npc',
   'ああ、旅人か。この先は危険だ。気をつけな。',
   'A traveler? Be careful ahead.',
   'warrior', NULL,
   '[{"conditions":{},"text":"ああ、旅人か。この先は危険だ。気をつけな。","text_ja":"ああ、旅人か。この先は危険だ。気をつけな。","text_en":"A traveler? Be careful ahead."},{"conditions":{"min_loop":3},"text":"……また来たのか？ いや、気のせいだろう。","text_ja":"……また来たのか？ いや、気のせいだろう。","text_en":"...back again? Must be my imagination."},{"conditions":{"min_loop":7},"text":"お前……何度ここに来た？ その目、何かを知っている目だ。","text_ja":"お前……何度ここに来た？ その目、何かを知っている目だ。","text_en":"How many times? Those eyes know something."}]',
   NULL, '{"npc_id":"villager","npc_name_ja":"村人","npc_name_en":"Villager","silhouette":"warrior"}');

INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_vnpc_merchant', 'medieval', 'village_npc',
   'いらっしゃい。旅の備えはしていくかい？',
   'Welcome. Need supplies for your journey?',
   'merchant', NULL,
   '[{"conditions":{},"text":"いらっしゃい。旅の備えはしていくかい？","text_ja":"いらっしゃい。旅の備えはしていくかい？","text_en":"Welcome. Need supplies?"},{"conditions":{"min_loop":3},"text":"前にも来なかったかい？ まあいい、商売は商売だ。","text_ja":"前にも来なかったかい？ まあいい、商売は商売だ。","text_en":"Haven''t you been here before? Business is business."},{"conditions":{"min_loop":7},"text":"何度目だ？ お前の目は「繰り返す者」の目だ。","text_ja":"何度目だ？ お前の目は「繰り返す者」の目だ。","text_en":"How many times? Your eyes are those of one who repeats."}]',
   NULL, '{"npc_id":"merchant","npc_name_ja":"商人","npc_name_en":"Merchant","silhouette":"merchant"}');

INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('m_vnpc_old_woman', 'medieval', 'village_npc',
   'ふふ……若いの、死ぬんじゃないよ。',
   'Heh... don''t die, young one.',
   'elder', NULL,
   '[{"conditions":{},"text":"ふふ……若いの、死ぬんじゃないよ。","text_ja":"ふふ……若いの、死ぬんじゃないよ。","text_en":"Heh... don''t die, young one."},{"conditions":{"min_loop":3},"text":"また死んで戻ってきたのかい。可哀想にねえ。","text_ja":"また死んで戻ってきたのかい。可哀想にねえ。","text_en":"Died and came back? Poor thing."},{"conditions":{"min_loop":7,"requires_truth_stage":2},"text":"お前さんは「残痕」だよ。消し残り。この世界に染みついた魂さ。","text_ja":"お前さんは「残痕」だよ。消し残り。この世界に染みついた魂さ。","text_en":"You are ''residue.'' A soul stained into this world."}]',
   NULL, '{"npc_id":"old_woman","npc_name_ja":"老婆","npc_name_en":"Old Woman","silhouette":"elder"}');

-- Future village NPCs
INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_vnpc_terminal_ai', 'future', 'village_npc',
   'ようこそ。本施設の案内を行います。安全な探索を。',
   'Welcome. I will guide you. Explore safely.',
   'cyborg', NULL,
   '[{"conditions":{},"text":"ようこそ。本施設の案内を行います。安全な探索を。","text_ja":"ようこそ。本施設の案内を行います。安全な探索を。","text_en":"Welcome. Explore safely."},{"conditions":{"min_loop":3},"text":"同一生体パターンを複数回検出。ログに矛盾あり。","text_ja":"同一生体パターンを複数回検出。ログに矛盾あり。","text_en":"Identical biometric detected multiple times. Log inconsistency."},{"conditions":{"min_loop":7,"requires_truth_stage":2},"text":"警告：あなたの存在はシステム上「削除済み」です。残痕として再分類。","text_ja":"警告：あなたの存在はシステム上「削除済み」です。残痕として再分類。","text_en":"Warning: You are ''deleted.'' Reclassifying as residue."}]',
   NULL, '{"npc_id":"terminal_ai","npc_name_ja":"ターミナルAI","npc_name_en":"Terminal AI","silhouette":"cyborg"}');

INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_vnpc_mechanic_log', 'future', 'village_npc',
   '【記録】本日も異常なし。定期メンテナンス完了。',
   '[Log] No anomalies today. Routine maintenance complete.',
   'scholar', NULL,
   '[{"conditions":{},"text":"【記録】本日も異常なし。定期メンテナンス完了。","text_ja":"【記録】本日も異常なし。定期メンテナンス完了。","text_en":"[Log] No anomalies. Maintenance complete."},{"conditions":{"min_loop":3},"text":"【記録】同じ人物が繰り返し来訪。カメラの誤作動か？","text_ja":"【記録】同じ人物が繰り返し来訪。カメラの誤作動か？","text_en":"[Log] Same person visiting repeatedly. Camera malfunction?"},{"conditions":{"min_loop":7},"text":"【記録】N-06の残したメッセージを発見。「繰り返す者へ——逃げるな」","text_ja":"【記録】N-06の残したメッセージを発見。「繰り返す者へ——逃げるな」","text_en":"[Log] Found N-06''s message: ''Don''t run.''"}]',
   NULL, '{"npc_id":"mechanic_log","npc_name_ja":"整備士の記録","npc_name_en":"Mechanic''s Log","silhouette":"scholar"}');

INSERT INTO events (event_id, world_id, type, text_ja, text_en, speaker, choices_json, reaction_slots_json, conditions_json, effects_json) VALUES
  ('f_vnpc_security_log', 'future', 'village_npc',
   '【警備】セクター内に不審者なし。通常運行を継続。',
   '[Security] No intruders. Normal operations.',
   'warrior', NULL,
   '[{"conditions":{},"text":"【警備】セクター内に不審者なし。通常運行を継続。","text_ja":"【警備】セクター内に不審者なし。通常運行を継続。","text_en":"[Security] No intruders."},{"conditions":{"min_loop":3},"text":"【警備】警告——同一人物の複数回侵入を検知。対処プロトコル不明。","text_ja":"【警備】警告——同一人物の複数回侵入を検知。対処プロトコル不明。","text_en":"[Security] Warning — repeated intrusion. No protocol."},{"conditions":{"min_loop":7,"requires_truth_stage":2},"text":"【警備】最終記録：もう止められない。「消し残り」だ。システムの外にいる。","text_ja":"【警備】最終記録：もう止められない。「消し残り」だ。システムの外にいる。","text_en":"[Security] Final: Can''t stop them. ''Residue.'' Outside the system."}]',
   NULL, '{"npc_id":"security_log","npc_name_ja":"警備ログ","npc_name_en":"Security Log","silhouette":"warrior"}');

-- ============================================================
-- JOBS (same as before, kept intact)
-- ============================================================
INSERT INTO jobs (job_id, name_ja, name_en, origin_world, stat_modifiers_json, unlock_conditions_json, special_ability_json) VALUES
  ('wanderer', '放浪者', 'Wanderer', NULL,
   '{"hp_bonus":0,"attack_bonus":0,"defense_bonus":0}',
   '{"soul_points":0}',
   '{"ability_id":"escape_artist","name_ja":"逃走の達人","name_en":"Escape Artist","description_ja":"逃走成功率が上昇","description_en":"Increased flee chance"}');
INSERT INTO jobs (job_id, name_ja, name_en, origin_world, stat_modifiers_json, unlock_conditions_json, special_ability_json) VALUES
  ('scholar', '学者', 'Scholar', NULL,
   '{"hp_bonus":-10,"attack_bonus":0,"defense_bonus":0}',
   '{"soul_points":50}',
   '{"ability_id":"deep_insight","name_ja":"深層洞察","name_en":"Deep Insight","description_ja":"発見による魂価値+50%","description_en":"+50% soul from discoveries"}');
INSERT INTO jobs (job_id, name_ja, name_en, origin_world, stat_modifiers_json, unlock_conditions_json, special_ability_json) VALUES
  ('knight', '騎士', 'Knight', 'medieval',
   '{"hp_bonus":20,"attack_bonus":3,"defense_bonus":2}',
   '{"soul_points":100}',
   '{"ability_id":"shield_wall","name_ja":"盾の壁","name_en":"Shield Wall","description_ja":"防御時ダメージ70%軽減","description_en":"70% damage reduction when defending"}');
INSERT INTO jobs (job_id, name_ja, name_en, origin_world, stat_modifiers_json, unlock_conditions_json, special_ability_json) VALUES
  ('cyborg', '機械兵', 'Cyborg', 'future',
   '{"hp_bonus":10,"attack_bonus":5,"defense_bonus":0}',
   '{"soul_points":100}',
   '{"ability_id":"overclock","name_ja":"オーバークロック","name_en":"Overclock","description_ja":"攻撃力一時2倍","description_en":"Temporarily doubles attack"}');
