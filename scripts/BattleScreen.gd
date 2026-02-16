extends Control

signal battle_ended(result: String)  # "victory", "defeat", "flee"

@onready var header: Label = $Margin/Root/Header
@onready var enemy_panel: VBoxContainer = $Margin/Root/EnemyPanel
@onready var enemy_name_label: Label = $Margin/Root/EnemyPanel/EnemyName
@onready var enemy_hp_label: Label = $Margin/Root/EnemyPanel/EnemyHP
@onready var enemy_desc: RichTextLabel = $Margin/Root/EnemyPanel/EnemyDesc
@onready var battle_log: RichTextLabel = $Margin/Root/BattleLog
@onready var player_status: Label = $Margin/Root/PlayerStatus
@onready var commands_box: VBoxContainer = $Margin/Root/Commands
@onready var attack_btn: Button = $Margin/Root/Commands/AttackButton
@onready var defend_btn: Button = $Margin/Root/Commands/DefendButton
@onready var flee_btn: Button = $Margin/Root/Commands/FleeButton

var enemy_id: String = ""
var enemy_data: Dictionary = {}
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var player_defending: bool = false
var battle_over: bool = false
var log_messages: Array = []

# Phase 3: Special ability tracking
var overclock_active: bool = false
var overclock_turns: int = 0


func _ready() -> void:
	attack_btn.pressed.connect(_on_attack)
	defend_btn.pressed.connect(_on_defend)
	flee_btn.pressed.connect(_on_flee)
	_setup_battle()


func set_enemy(p_enemy_id: String) -> void:
	enemy_id = p_enemy_id


func _setup_battle() -> void:
	enemy_data = GameState.get_enemy_by_id(enemy_id)
	if enemy_data.is_empty():
		_log("敵データが見つかりません: %s" % enemy_id)
		return
	
	enemy_max_hp = int(enemy_data.get("hp", 50))
	enemy_hp = enemy_max_hp
	
	enemy_name_label.text = enemy_data.get("name", "Unknown Enemy")
	enemy_desc.text = enemy_data.get("description", "")
	
	# Phase 3: Show job in header
	var job: Dictionary = GameState.get_job_by_id(GameState.current_job)
	var job_name: String = job.get("name", "放浪者")
	header.text = "戦闘 — %s [%s]" % [enemy_data.get("name", ""), job_name]
	
	_log("「%s」が現れた！" % enemy_data.get("name", "敵"))
	
	# Phase 3: Show job ability hint
	_show_job_ability_hint()
	
	_update_display()


func _show_job_ability_hint() -> void:
	var job: Dictionary = GameState.get_job_by_id(GameState.current_job)
	var ability: Dictionary = job.get("special_ability", {})
	if ability.is_empty():
		return
	
	var ability_name: String = ability.get("name", "")
	match GameState.current_job:
		"wanderer":
			_log("[特殊] 逃走の達人 - 逃走成功率上昇")
		"knight":
			_log("[特殊] 盾の壁 - 防御時70%軽減")
		"cyborg":
			_log("[特殊] オーバークロック - 攻撃ボタン長押しで発動")
			# Add overclock button
			_add_overclock_button()


func _add_overclock_button() -> void:
	var overclock_btn := Button.new()
	overclock_btn.name = "OverclockButton"
	overclock_btn.text = "オーバークロック"
	overclock_btn.pressed.connect(_on_overclock)
	commands_box.add_child(overclock_btn)


func _update_display() -> void:
	enemy_hp_label.text = "HP: %d / %d" % [enemy_hp, enemy_max_hp]
	
	# Phase 3: Show attack/defense bonuses
	var atk_text: String = ""
	var def_text: String = ""
	if GameState.run_attack_bonus > 0:
		atk_text = " (攻+%d)" % GameState.run_attack_bonus
	if GameState.run_defense_bonus > 0:
		def_text = " (防+%d)" % GameState.run_defense_bonus
	
	player_status.text = "あなた: HP %d / %d%s%s | Gold: %d" % [
		GameState.run_hp,
		GameState.run_max_hp,
		atk_text,
		def_text,
		GameState.run_gold
	]
	
	var log_text: String = ""
	var start_idx: int = maxi(0, log_messages.size() - 6)
	for i: int in range(start_idx, log_messages.size()):
		log_text += log_messages[i] + "\n"
	battle_log.text = log_text
	
	_set_commands_enabled(not battle_over)


func _set_commands_enabled(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	defend_btn.disabled = not enabled
	flee_btn.disabled = not enabled
	
	var overclock_btn: Button = commands_box.get_node_or_null("OverclockButton")
	if overclock_btn != null:
		overclock_btn.disabled = not enabled or overclock_active


func _log(message: String) -> void:
	log_messages.append(message)


func _on_attack() -> void:
	if battle_over:
		return
	player_defending = false
	
	# Player attacks with job bonus
	var base_attack: int = 15 + randi() % 6  # 15-20 base damage
	var attack_bonus: int = GameState.run_attack_bonus
	
	# Phase 3: Cyborg overclock doubles attack
	if overclock_active:
		attack_bonus = attack_bonus * 2 + base_attack
		_log("[オーバークロック発動！]")
		overclock_turns -= 1
		if overclock_turns <= 0:
			overclock_active = false
			_log("[オーバークロック終了]")
	
	var total_attack: int = base_attack + attack_bonus
	var enemy_def: int = int(enemy_data.get("defense", 0))
	var damage_to_enemy: int = maxi(1, total_attack - enemy_def)
	enemy_hp -= damage_to_enemy
	_log("→ 攻撃！ %d ダメージ" % damage_to_enemy)
	
	if enemy_hp <= 0:
		_on_victory()
		return
	
	_enemy_turn()


func _on_defend() -> void:
	if battle_over:
		return
	player_defending = true
	_log("→ 防御の構え")
	
	# Phase 3: Decrement overclock turns even when defending
	if overclock_active:
		overclock_turns -= 1
		if overclock_turns <= 0:
			overclock_active = false
			_log("[オーバークロック終了]")
	
	_enemy_turn()


func _on_overclock() -> void:
	if battle_over or overclock_active:
		return
	
	overclock_active = true
	overclock_turns = 3
	_log("→ オーバークロック起動！ 3ターン攻撃力2倍")
	_update_display()


func _on_flee() -> void:
	if battle_over:
		return
	
	# Base flee chance: 50%, 30% against bosses
	var flee_chance: float = 0.5
	if enemy_id.contains("boss"):
		flee_chance = 0.3
	
	# Phase 3: Wanderer has higher flee chance
	if GameState.current_job == "wanderer":
		flee_chance += 0.25
	
	if randf() < flee_chance:
		_log("→ 逃走成功！")
		battle_over = true
		_update_display()
		await get_tree().create_timer(1.0).timeout
		battle_ended.emit("flee")
	else:
		_log("→ 逃げられない！")
		_enemy_turn()


func _enemy_turn() -> void:
	if battle_over:
		return
	
	var enemy_attack: int = int(enemy_data.get("attack", 10))
	var damage: int = enemy_attack + randi() % 5
	
	# Apply player's defense bonus
	damage = maxi(1, damage - GameState.run_defense_bonus)
	
	if player_defending:
		# Phase 3: Knight has 70% reduction when defending (instead of 50%)
		var reduction: float = 0.5
		if GameState.current_job == "knight":
			reduction = 0.7
		damage = int(damage * (1.0 - reduction))
		_log("← %s の攻撃！ 防御で %d ダメージに軽減" % [enemy_data.get("name", "敵"), damage])
	else:
		_log("← %s の攻撃！ %d ダメージ" % [enemy_data.get("name", "敵"), damage])
	
	GameState.take_damage(damage)
	
	if GameState.is_player_dead():
		_on_defeat()
		return
	
	_update_display()


func _on_victory() -> void:
	battle_over = true
	enemy_hp = 0
	_log("")
	_log("[color=green]勝利！[/color]")
	
	# Apply rewards
	var rewards: Dictionary = enemy_data.get("rewards", {})
	var gold: int = int(rewards.get("gold", 0))
	if gold > 0:
		GameState.add_gold(gold)
		_log("  → %d Gold 獲得" % gold)
	
	var tags: Array = rewards.get("tags", [])
	for tag: Variant in tags:
		GameState.add_run_tag(str(tag))
		GameState.add_trait_tag(str(tag))
		_log("  → タグ獲得: %s" % tag)
	
	GameState.record_kill()
	
	# Phase 3: Check for cross-link item acquisition after boss defeat
	var acquired_items: Array = GameState.check_and_acquire_cross_link_items()
	for item: Variant in acquired_items:
		if item is Dictionary:
			_log("")
			_log("[color=gold]✦ %s を獲得！ ✦[/color]" % item.get("name", "アイテム"))
			_log("[i]%s[/i]" % item.get("description", ""))
	
	_update_display()
	
	await get_tree().create_timer(1.5).timeout
	battle_ended.emit("victory")


func _on_defeat() -> void:
	battle_over = true
	_log("")
	_log("[color=red]敗北…[/color]")
	_log("闘いに敗れ、闇が視界を覆う。")
	_update_display()
	
	await get_tree().create_timer(2.0).timeout
	battle_ended.emit("defeat")
