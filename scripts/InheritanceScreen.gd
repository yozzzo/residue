extends Control

signal inheritance_selected

@onready var header: Label = $Margin/Root/Header
@onready var description_label: RichTextLabel = $Margin/Root/Description
@onready var candidates_box: VBoxContainer = $Margin/Root/Candidates
@onready var skip_button: Button = $Margin/Root/Footer/SkipButton

var candidates: Array = []


func _ready() -> void:
	skip_button.pressed.connect(_on_skip_pressed)
	_setup_screen()


func _setup_screen() -> void:
	header.text = "継承の選択"
	
	var is_clear: bool = GameState.run_is_clear
	var soul_gain: int = GameState.last_run_score
	
	var desc_text: String = """[b]周回%d 終了[/b]

獲得魂価値: [color=gold]%d[/color]
累計魂価値: [color=gold]%d[/color]

""" % [GameState.loop_count - 1, soul_gain, GameState.soul_points]
	
	if is_clear:
		desc_text += "[color=green]✦ クリア達成 ✦[/color]\n\n"
	
	desc_text += "次の周回に持ち越す継承を選んでください。"
	
	# Show dominant traits
	var dominant_traits: Array = GameState.get_dominant_traits(3)
	if dominant_traits.size() > 0:
		desc_text += "\n\n[b]蓄積された傾向:[/b] " + ", ".join(dominant_traits)
	
	# Show acquired memory flags (hints)
	var flags_text: String = _get_recent_flags_text()
	if not flags_text.is_empty():
		desc_text += "\n\n[b]獲得した記憶:[/b] " + flags_text
	
	description_label.text = desc_text
	
	# Generate inheritance candidates
	candidates = GameState.generate_inheritance_candidates()
	_render_candidates()


func _get_recent_flags_text() -> String:
	var flag_labels: Dictionary = {
		"mayor_basement_seen": "村長の地下",
		"well_peeked": "井戸の声",
		"seal_broken": "封印解除",
		"tome_read": "古の書物",
		"bishop_encountered": "司教との対面",
		"bishop_defeated": "司教撃破",
		"terminal_hacked": "端末ハック",
		"diary_read": "N-06の日記",
		"core_log_read": "コアログ",
		"tank_examined": "培養槽調査",
		"shelter_message_read": "シェルターの警告",
		"system_dialogue": "システムとの対話",
		"prophet_encountered": "預言者との対面",
		"prophet_defeated": "預言者撃破",
		"residue_truth_revealed": "Residueの真実"
	}
	
	var acquired: Array = []
	for flag: String in flag_labels.keys():
		if GameState.has_memory_flag(flag):
			acquired.append(flag_labels[flag])
	
	if acquired.size() > 5:
		return ", ".join(acquired.slice(0, 5)) + " 他%d" % (acquired.size() - 5)
	
	return ", ".join(acquired)


func _render_candidates() -> void:
	for child: Node in candidates_box.get_children():
		child.queue_free()
	
	for i: int in range(candidates.size()):
		var candidate: Dictionary = candidates[i]
		var card := _create_candidate_card(candidate, i)
		candidates_box.add_child(card)


func _create_candidate_card(candidate: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.text = "【%s】" % candidate.get("label", "継承")
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc.text = candidate.get("description", "")
	vbox.add_child(desc)
	
	var button := Button.new()
	button.text = "選択"
	button.custom_minimum_size = Vector2(100, 32)
	button.pressed.connect(_on_candidate_selected.bind(candidate))
	vbox.add_child(button)
	
	return panel


func _on_candidate_selected(candidate: Dictionary) -> void:
	var bonus_type: String = candidate.get("type", "")
	var value: Variant = candidate.get("value", 0)
	
	match bonus_type:
		"soul_bonus":
			# Apply soul bonus immediately to current total
			GameState.soul_points += int(value)
		"hp_bonus", "gold_start", "tag_boost", "memory_hint":
			# Set pending inheritance for next run
			GameState.set_pending_inheritance(bonus_type, value)
	
	# Special: memory_hint sets a flag
	if bonus_type == "memory_hint":
		GameState.set_memory_flag(str(value))
	
	GameState.save_persistent_state()
	inheritance_selected.emit()


func _on_skip_pressed() -> void:
	inheritance_selected.emit()
