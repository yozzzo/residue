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
	header.text = "戦闘 — %s" % enemy_data.get("name", "")
	
	_log("「%s」が現れた！" % enemy_data.get("name", "敵"))
	_update_display()


func _update_display() -> void:
	enemy_hp_label.text = "HP: %d / %d" % [enemy_hp, enemy_max_hp]
	player_status.text = "あなた: HP %d / %d | Gold: %d" % [GameState.run_hp, GameState.run_max_hp, GameState.run_gold]
	
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


func _log(message: String) -> void:
	log_messages.append(message)


func _on_attack() -> void:
	if battle_over:
		return
	player_defending = false
	
	# Player attacks
	var player_attack: int = 15 + randi() % 6  # 15-20 damage
	var enemy_def: int = int(enemy_data.get("defense", 0))
	var damage_to_enemy: int = maxi(1, player_attack - enemy_def)
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
	_enemy_turn()


func _on_flee() -> void:
	if battle_over:
		return
	
	# 50% chance to flee, 30% against bosses
	var flee_chance: float = 0.5
	if enemy_id.contains("boss"):
		flee_chance = 0.3
	
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
	
	if player_defending:
		damage = int(damage * 0.5)
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
		_log("  → タグ獲得: %s" % tag)
	
	GameState.record_kill()
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
