extends Control

signal battle_ended(result: String)  # "victory", "defeat", "flee"

@onready var header: Label = $Margin/Root/Header
@onready var enemy_panel: VBoxContainer = $Margin/Root/EnemyPanel
@onready var enemy_name_label: Label = $Margin/Root/EnemyPanel/EnemyName
@onready var enemy_hp_bar: ProgressBar = $Margin/Root/EnemyPanel/EnemyHPBar
@onready var enemy_hp_label: Label = $Margin/Root/EnemyPanel/EnemyHP
@onready var enemy_desc: RichTextLabel = $Margin/Root/EnemyPanel/EnemyDesc
@onready var battle_log: RichTextLabel = $Margin/Root/BattleLog
@onready var player_panel: PanelContainer = $Margin/Root/PlayerPanel
@onready var player_hp_bar: ProgressBar = $Margin/Root/PlayerPanel/PlayerHBox/PlayerHPBar
@onready var player_status: Label = $Margin/Root/PlayerPanel/PlayerHBox/PlayerStatus
@onready var commands_box: HBoxContainer = $Margin/Root/Commands
@onready var attack_btn: Button = $Margin/Root/Commands/AttackButton
@onready var defend_btn: Button = $Margin/Root/Commands/DefendButton
@onready var flee_btn: Button = $Margin/Root/Commands/FleeButton
@onready var background: ColorRect = $Background
@onready var popup_container: Control = $PopupContainer

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
	_apply_theme()
	_update_button_texts()
	_setup_battle()
	
	LocaleManager.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	_update_button_texts()
	_update_display()


func _update_button_texts() -> void:
	attack_btn.text = "⚔️ " + LocaleManager.t("ui.battle_attack")
	defend_btn.text = "🛡️ " + LocaleManager.t("ui.battle_defend")
	flee_btn.text = "🏃 " + LocaleManager.t("ui.battle_flee")


func _apply_theme() -> void:
	# Battle has slightly different colors (more intense)
	var base_color: Color = ThemeManager.get_background_color()
	# Make it slightly more reddish for battle atmosphere
	background.color = Color(
		base_color.r + 0.05,
		base_color.g * 0.8,
		base_color.b * 0.9
	)
	
	# Style battle command buttons
	_style_battle_buttons()
	
	# Style player panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.1, 0.9)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	player_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Style HP bars
	UITheme.style_hp_bar(enemy_hp_bar, true)
	UITheme.style_hp_bar(player_hp_bar, true)


func _style_battle_buttons() -> void:
	# Attack button (red-ish)
	var atk_normal := UITheme.create_button_stylebox(Color(0.4, 0.25, 0.25, 0.9))
	var atk_hover := UITheme.create_button_stylebox(Color(0.5, 0.3, 0.3, 0.95))
	var atk_pressed := UITheme.create_button_stylebox(Color(0.35, 0.2, 0.2, 1.0))
	var disabled := UITheme.create_button_stylebox(Color(0.2, 0.15, 0.15, 0.5))
	attack_btn.add_theme_stylebox_override("normal", atk_normal)
	attack_btn.add_theme_stylebox_override("hover", atk_hover)
	attack_btn.add_theme_stylebox_override("pressed", atk_pressed)
	attack_btn.add_theme_stylebox_override("disabled", disabled)
	
	# Defend button (blue-ish)
	var def_normal := UITheme.create_button_stylebox(Color(0.25, 0.3, 0.4, 0.9))
	var def_hover := UITheme.create_button_stylebox(Color(0.3, 0.35, 0.5, 0.95))
	var def_pressed := UITheme.create_button_stylebox(Color(0.2, 0.25, 0.35, 1.0))
	defend_btn.add_theme_stylebox_override("normal", def_normal)
	defend_btn.add_theme_stylebox_override("hover", def_hover)
	defend_btn.add_theme_stylebox_override("pressed", def_pressed)
	defend_btn.add_theme_stylebox_override("disabled", disabled)
	
	# Flee button (gray-ish)
	var flee_normal := UITheme.create_button_stylebox(Color(0.3, 0.3, 0.3, 0.9))
	var flee_hover := UITheme.create_button_stylebox(Color(0.4, 0.4, 0.4, 0.95))
	var flee_pressed := UITheme.create_button_stylebox(Color(0.25, 0.25, 0.25, 1.0))
	flee_btn.add_theme_stylebox_override("normal", flee_normal)
	flee_btn.add_theme_stylebox_override("hover", flee_hover)
	flee_btn.add_theme_stylebox_override("pressed", flee_pressed)
	flee_btn.add_theme_stylebox_override("disabled", disabled)


func set_enemy(p_enemy_id: String) -> void:
	enemy_id = p_enemy_id


func _setup_battle() -> void:
	enemy_data = GameState.get_enemy_by_id(enemy_id)
	if enemy_data.is_empty():
		_log(LocaleManager.t("ui.node_missing") + ": %s" % enemy_id)
		return
	
	enemy_max_hp = int(enemy_data.get("hp", 50))
	enemy_hp = enemy_max_hp
	
	var enemy_name: String = LocaleManager.tr_data(enemy_data, "name")
	var enemy_description: String = LocaleManager.tr_data(enemy_data, "description")
	
	enemy_name_label.text = enemy_name
	enemy_desc.text = enemy_description
	
	# Phase 3: Show job in header
	var job: Dictionary = GameState.get_job_by_id(GameState.current_job)
	var job_name: String = LocaleManager.tr_data(job, "name")
	header.text = LocaleManager.t("ui.battle_header", {"enemy": enemy_name, "job": job_name})
	
	_log(LocaleManager.t("ui.battle_enemy_appears", {"name": enemy_name}))
	
	# Phase 3: Show job ability hint
	_show_job_ability_hint()
	
	_update_display()


func _show_job_ability_hint() -> void:
	var job: Dictionary = GameState.get_job_by_id(GameState.current_job)
	var ability: Dictionary = job.get("special_ability", {})
	if ability.is_empty():
		return
	
	match GameState.current_job:
		"wanderer":
			_log(LocaleManager.t("ui.battle_ability_escape"))
		"knight":
			_log(LocaleManager.t("ui.battle_ability_shield"))
		"cyborg":
			_log(LocaleManager.t("ui.battle_ability_overclock"))
			# Add overclock button
			_add_overclock_button()


func _add_overclock_button() -> void:
	var overclock_btn := Button.new()
	overclock_btn.name = "OverclockButton"
	overclock_btn.text = "⚡ " + LocaleManager.t("ui.battle_overclock")
	overclock_btn.custom_minimum_size = Vector2(0, 64)
	overclock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overclock_btn.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
	
	# Style overclock button (yellow/electric)
	var normal := UITheme.create_button_stylebox(Color(0.4, 0.35, 0.2, 0.9))
	var hover := UITheme.create_button_stylebox(Color(0.5, 0.45, 0.25, 0.95))
	var pressed := UITheme.create_button_stylebox(Color(0.35, 0.3, 0.15, 1.0))
	var disabled := UITheme.create_button_stylebox(Color(0.2, 0.18, 0.1, 0.5))
	overclock_btn.add_theme_stylebox_override("normal", normal)
	overclock_btn.add_theme_stylebox_override("hover", hover)
	overclock_btn.add_theme_stylebox_override("pressed", pressed)
	overclock_btn.add_theme_stylebox_override("disabled", disabled)
	
	overclock_btn.pressed.connect(_on_overclock)
	commands_box.add_child(overclock_btn)


func _update_display() -> void:
	# Enemy HP bar
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	enemy_hp_label.text = LocaleManager.t("ui.battle_enemy_hp", {"current": enemy_hp, "max": enemy_max_hp})
	
	# Update enemy HP bar color
	var enemy_hp_percent: float = float(enemy_hp) / float(enemy_max_hp)
	_update_hp_bar_style(enemy_hp_bar, enemy_hp_percent)
	
	# Player HP bar
	player_hp_bar.max_value = GameState.run_max_hp
	player_hp_bar.value = GameState.run_hp
	
	var player_hp_percent: float = float(GameState.run_hp) / float(GameState.run_max_hp)
	_update_hp_bar_style(player_hp_bar, player_hp_percent)
	
	# Phase 3: Show attack/defense bonuses
	var atk_text: String = ""
	var def_text: String = ""
	if GameState.run_attack_bonus > 0:
		atk_text = LocaleManager.t("ui.battle_atk_bonus", {"bonus": GameState.run_attack_bonus})
	if GameState.run_defense_bonus > 0:
		def_text = LocaleManager.t("ui.battle_def_bonus", {"bonus": GameState.run_defense_bonus})
	
	player_status.text = LocaleManager.t("ui.battle_player_status", {
		"hp": GameState.run_hp,
		"maxhp": GameState.run_max_hp,
		"atk": atk_text,
		"def": def_text,
		"gold": GameState.run_gold
	})
	
	var log_text: String = ""
	var start_idx: int = maxi(0, log_messages.size() - 6)
	for i: int in range(start_idx, log_messages.size()):
		log_text += log_messages[i] + "\n"
	battle_log.text = log_text
	
	_set_commands_enabled(not battle_over)


func _update_hp_bar_style(bar: ProgressBar, percent: float) -> void:
	var color: Color
	if percent > 0.5:
		color = Color(0.3, 0.7, 0.4)
	elif percent > 0.25:
		color = Color(0.8, 0.7, 0.3)
	else:
		color = Color(0.8, 0.3, 0.3)
	
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = color
	stylebox.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", stylebox)


func _spawn_damage_popup(value: int, is_player: bool, is_healing: bool = false) -> void:
	if popup_container == null:
		return
	
	var popup := DamagePopup.new()
	popup.setup(value, is_healing, value >= 25)
	
	# Position near the target
	if is_player:
		popup.position = Vector2(player_panel.global_position.x + 100, player_panel.global_position.y)
	else:
		popup.position = Vector2(enemy_panel.global_position.x + 100, enemy_panel.global_position.y + 50)
	
	popup_container.add_child(popup)


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
		_log(LocaleManager.t("ui.battle_overclock_active"))
		overclock_turns -= 1
		if overclock_turns <= 0:
			overclock_active = false
			_log(LocaleManager.t("ui.battle_overclock_end"))
	
	var total_attack: int = base_attack + attack_bonus
	var enemy_def: int = int(enemy_data.get("defense", 0))
	var damage_to_enemy: int = maxi(1, total_attack - enemy_def)
	enemy_hp -= damage_to_enemy
	_log(LocaleManager.t("ui.battle_attack_log", {"damage": damage_to_enemy}))
	
	# Spawn damage popup on enemy
	_spawn_damage_popup(damage_to_enemy, false)
	
	if enemy_hp <= 0:
		_on_victory()
		return
	
	_enemy_turn()


func _on_defend() -> void:
	if battle_over:
		return
	player_defending = true
	_log(LocaleManager.t("ui.battle_defend_log"))
	
	# Phase 3: Decrement overclock turns even when defending
	if overclock_active:
		overclock_turns -= 1
		if overclock_turns <= 0:
			overclock_active = false
			_log(LocaleManager.t("ui.battle_overclock_end"))
	
	_enemy_turn()


func _on_overclock() -> void:
	if battle_over or overclock_active:
		return
	
	overclock_active = true
	overclock_turns = 3
	_log(LocaleManager.t("ui.battle_overclock_log"))
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
		_log(LocaleManager.t("ui.battle_flee_success"))
		battle_over = true
		_update_display()
		await get_tree().create_timer(1.0).timeout
		battle_ended.emit("flee")
	else:
		_log(LocaleManager.t("ui.battle_flee_fail"))
		_enemy_turn()


func _enemy_turn() -> void:
	if battle_over:
		return
	
	var enemy_name: String = LocaleManager.tr_data(enemy_data, "name")
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
		_log(LocaleManager.t("ui.battle_enemy_attack_blocked", {"name": enemy_name, "damage": damage}))
	else:
		_log(LocaleManager.t("ui.battle_enemy_attack", {"name": enemy_name, "damage": damage}))
	
	GameState.take_damage(damage)
	
	# Spawn damage popup on player
	_spawn_damage_popup(damage, true)
	
	if GameState.is_player_dead():
		_on_defeat()
		return
	
	_update_display()


func _on_victory() -> void:
	battle_over = true
	enemy_hp = 0
	_log("")
	_log(LocaleManager.t("ui.battle_victory"))
	
	# Apply rewards
	var rewards: Dictionary = enemy_data.get("rewards", {})
	var gold: int = int(rewards.get("gold", 0))
	if gold > 0:
		GameState.add_gold(gold)
		_log(LocaleManager.t("ui.battle_gold_gain", {"amount": gold}))
	
	var tags: Array = rewards.get("tags", [])
	for tag: Variant in tags:
		GameState.add_run_tag(str(tag))
		GameState.add_trait_tag(str(tag))
		_log(LocaleManager.t("ui.battle_tag_gain", {"tag": tag}))
	
	GameState.record_kill()
	
	# Phase 3: Check for cross-link item acquisition after boss defeat
	var acquired_items: Array = GameState.check_and_acquire_cross_link_items()
	for item: Variant in acquired_items:
		if item is Dictionary:
			var item_name: String = LocaleManager.tr_data(item, "name")
			var item_desc: String = LocaleManager.tr_data(item, "description")
			_log("")
			_log("[color=gold]%s[/color]" % LocaleManager.t("ui.battle_item_gain", {"name": item_name}))
			_log("[i]%s[/i]" % item_desc)
	
	_update_display()
	
	await get_tree().create_timer(1.5).timeout
	battle_ended.emit("victory")


func _on_defeat() -> void:
	battle_over = true
	_log("")
	_log(LocaleManager.t("ui.battle_defeat"))
	_log(LocaleManager.t("ui.battle_defeat_desc"))
	_update_display()
	
	await get_tree().create_timer(2.0).timeout
	battle_ended.emit("defeat")
