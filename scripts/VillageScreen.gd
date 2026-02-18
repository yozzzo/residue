extends Control

signal depart_requested
signal status_updated

@onready var header: Label = $Margin/Root/Header
@onready var body_text: RichTextLabel = $Margin/Root/BodyText
@onready var npc_buttons: VBoxContainer = $Margin/Root/NPCButtons
@onready var shop_buttons: HBoxContainer = $Margin/Root/ShopButtons
@onready var depart_button: Button = $Margin/Root/DepartButton
@onready var status_label: Label = $Margin/Root/StatusLabel
@onready var background: ColorRect = $Background
@onready var background_image: TextureRect = $BackgroundImage
@onready var silhouette_rect: TextureRect = $SilhouetteRect

const WORLD_BACKGROUNDS := {
	"medieval": "res://assets/generated/backgrounds/medieval_bg.png",
	"future": "res://assets/generated/backgrounds/future_bg.png",
}

const SILHOUETTES := {
	"elder": "res://assets/generated/silhouettes/elder.png",
	"warrior": "res://assets/generated/silhouettes/warrior.png",
	"scholar": "res://assets/generated/silhouettes/scholar.png",
	"monster": "res://assets/generated/silhouettes/monster.png",
	"cyborg": "res://assets/generated/silhouettes/cyborg.png",
	"merchant": "res://assets/generated/silhouettes/merchant.png",
}

var village_data: Dictionary = {}
var current_npc_index: int = -1  # -1 = showing main village text


func _ready() -> void:
	depart_button.pressed.connect(_on_depart)
	_apply_theme()
	_load_village_data()
	_show_village_main()
	_update_status()


func _apply_theme() -> void:
	var world_id: String = ThemeManager.current_world
	if WORLD_BACKGROUNDS.has(world_id) and ResourceLoader.exists(WORLD_BACKGROUNDS[world_id]):
		background_image.texture = load(WORLD_BACKGROUNDS[world_id])
		background.color = Color(ThemeManager.get_background_color(), 0.6)
	else:
		background_image.texture = null
		background.color = ThemeManager.get_background_color()
	
	# Style depart button
	var accent: Color = ThemeManager.get_accent_color()
	var normal := UITheme.create_button_stylebox(ThemeManager.get_button_color())
	normal.border_color = Color(accent, 0.5)
	normal.set_border_width_all(1)
	var hover := UITheme.create_button_stylebox(ThemeManager.get_button_hover_color())
	hover.border_color = Color(accent, 0.8)
	hover.set_border_width_all(1)
	depart_button.add_theme_stylebox_override("normal", normal)
	depart_button.add_theme_stylebox_override("hover", hover)
	depart_button.add_theme_color_override("font_color", ThemeManager.get_text_color())


func _load_village_data() -> void:
	var world_id: String = GameState.selected_world_id
	
	# Try to load from API data (village_npc events in events_by_world)
	var api_village: Dictionary = _build_village_from_api(world_id)
	if not api_village.is_empty():
		village_data = api_village
		return
	
	# Fallback to local JSON file
	var path: String = "res://data/village/%s_village.json" % world_id
	if FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				village_data = parsed
				return
	
	# Ultimate fallback: embedded data
	village_data = _get_default_village_data(world_id)


func _build_village_from_api(world_id: String) -> Dictionary:
	## Build village data from village_npc type events loaded via API
	var events: Array = GameState.get_events_for_world(world_id)
	var npcs: Array = []
	
	for event: Variant in events:
		if event is not Dictionary:
			continue
		if event.get("type", "") != "village_npc":
			continue
		
		# Extract NPC metadata from effects_json (stored in "effects" after transform)
		var meta: Dictionary = event.get("effects", {})
		var npc_id: String = meta.get("npc_id", event.get("event_id", ""))
		var npc_name_ja: String = meta.get("npc_name_ja", "")
		var npc_name_en: String = meta.get("npc_name_en", "")
		var silhouette: String = meta.get("silhouette", event.get("speaker", ""))
		
		# reaction_slots contain the loop-dependent dialogues
		var reaction_slots: Array = event.get("reaction_slots", [])
		var dialogues: Array = []
		for slot: Variant in reaction_slots:
			if slot is not Dictionary:
				continue
			dialogues.append({
				"text_ja": slot.get("text_ja", slot.get("text", "")),
				"text_en": slot.get("text_en", ""),
				"conditions": slot.get("conditions", {})
			})
		
		if dialogues.is_empty():
			# Use main text as single dialogue
			dialogues.append({
				"text_ja": event.get("text_ja", event.get("text", "")),
				"text_en": event.get("text_en", ""),
				"conditions": {}
			})
		
		npcs.append({
			"id": npc_id,
			"name_ja": npc_name_ja,
			"name_en": npc_name_en,
			"silhouette": silhouette,
			"dialogues": dialogues
		})
	
	if npcs.is_empty():
		return {}
	
	# Build village description from world setting
	var world: Dictionary = GameState.get_world_by_id(world_id)
	var desc_ja: String = world.get("blurb_ja", world.get("blurb", ""))
	var desc_en: String = world.get("blurb_en", "")
	
	return {
		"description_ja": desc_ja,
		"description_en": desc_en,
		"npcs": npcs
	}


func _get_default_village_data(world_id: String) -> Dictionary:
	# Fallback village data embedded
	if world_id == "medieval":
		return {
			"description_ja": "石造りの村の入口。冷たい風が吹き抜ける。旅人の姿はまばらだ。",
			"description_en": "The entrance to a stone village. Cold wind blows through.",
			"npcs": [
				{
					"id": "villager", "name_ja": "村人", "name_en": "Villager",
					"silhouette": "warrior",
					"dialogues": [
						{"text_ja": "ああ、旅人か。この先は危険だ。気をつけな。", "text_en": "A traveler? Be careful ahead.", "conditions": {}},
						{"text_ja": "……また来たのか？ いや、気のせいだな。", "text_en": "...back again? No, must be my imagination.", "conditions": {"min_loop": 3}},
						{"text_ja": "お前……何度ここに来た？ その目、何かを知っている目だ。", "text_en": "How many times have you come here? Those eyes know something.", "conditions": {"min_loop": 7}}
					]
				},
				{
					"id": "merchant", "name_ja": "商人", "name_en": "Merchant",
					"silhouette": "merchant",
					"dialogues": [
						{"text_ja": "いらっしゃい。旅の備えはしていくかい？", "text_en": "Welcome. Need supplies for your journey?", "conditions": {}},
						{"text_ja": "あんた、前にも来なかったかい？ まあいい、商売は商売だ。", "text_en": "Haven't you been here before? Well, business is business.", "conditions": {"min_loop": 3}},
						{"text_ja": "……何度目だ？ 俺にはわかる。お前の目は「繰り返している者」の目だ。", "text_en": "How many times now? I can tell. Your eyes are those of one who repeats.", "conditions": {"min_loop": 7}}
					]
				},
				{
					"id": "old_woman", "name_ja": "老婆", "name_en": "Old Woman",
					"silhouette": "elder",
					"dialogues": [
						{"text_ja": "ふふ……若いの、死ぬんじゃないよ。", "text_en": "Heh... don't die, young one.", "conditions": {}},
						{"text_ja": "……また死んで戻ってきたのかい。可哀想にねえ。", "text_en": "...died and came back again, have you? Poor thing.", "conditions": {"min_loop": 3}},
						{"text_ja": "お前さんは「残痕」だよ。消し残り。この世界に染みついた魂さ。", "text_en": "You are a 'residue'. A soul stained into this world.", "conditions": {"min_loop": 7, "requires_truth_stage": 2}}
					]
				}
			]
		}
	else:  # future
		return {
			"description_ja": "冷たい蛍光灯が瞬く。ターミナルの入口。電子音が低く響く。",
			"description_en": "Cold fluorescent lights flicker. The terminal entrance. Electronic hum.",
			"npcs": [
				{
					"id": "terminal_ai", "name_ja": "ターミナルAI", "name_en": "Terminal AI",
					"silhouette": "cyborg",
					"dialogues": [
						{"text_ja": "ようこそ。本施設の案内を行います。安全な探索を。", "text_en": "Welcome. I will guide you. Explore safely.", "conditions": {}},
						{"text_ja": "……同一生体パターンを複数回検出。ログに矛盾あり。", "text_en": "...identical biometric pattern detected multiple times. Log inconsistency.", "conditions": {"min_loop": 3}},
						{"text_ja": "警告：あなたの存在はシステム上「削除済み」です。残痕として再分類します。", "text_en": "Warning: You are classified as 'deleted'. Reclassifying as residue.", "conditions": {"min_loop": 7, "requires_truth_stage": 2}}
					]
				},
				{
					"id": "mechanic_log", "name_ja": "整備士の記録", "name_en": "Mechanic's Log",
					"silhouette": "scholar",
					"dialogues": [
						{"text_ja": "【記録】本日も異常なし。定期メンテナンス完了。", "text_en": "[Log] No anomalies today. Routine maintenance complete.", "conditions": {}},
						{"text_ja": "【記録】同じ人物が繰り返し来訪。監視カメラの誤作動か？", "text_en": "[Log] Same person visiting repeatedly. Camera malfunction?", "conditions": {"min_loop": 3}},
						{"text_ja": "【記録】N-06の残したメッセージを発見。「繰り返す者へ——逃げるな」", "text_en": "[Log] Found N-06's message. 'To the one who repeats — don't run.'", "conditions": {"min_loop": 7}}
					]
				},
				{
					"id": "security_log", "name_ja": "警備ログ", "name_en": "Security Log",
					"silhouette": "warrior",
					"dialogues": [
						{"text_ja": "【警備】セクター内に不審者なし。通常運行を継続。", "text_en": "[Security] No intruders. Normal operations.", "conditions": {}},
						{"text_ja": "【警備】警告——同一人物の複数回侵入を検知。対処プロトコル不明。", "text_en": "[Security] Warning — repeated intrusion by same individual. No protocol.", "conditions": {"min_loop": 3}},
						{"text_ja": "【警備】最終記録：もう止められない。彼は「消し残り」だ。システムの外にいる。", "text_en": "[Security] Final log: Can't stop them. They are 'residue'. Outside the system.", "conditions": {"min_loop": 7, "requires_truth_stage": 2}}
					]
				}
			]
		}


func _show_village_main() -> void:
	current_npc_index = -1
	_hide_silhouette()
	
	var world: Dictionary = GameState.get_world_by_id(GameState.selected_world_id)
	var world_name: String = LocaleManager.tr_data(world, "name")
	header.text = LocaleManager.t("ui.village_header", {"world": world_name})
	depart_button.text = LocaleManager.t("ui.village_depart")
	
	var desc: String = LocaleManager.tr_data(village_data, "description")
	if desc.is_empty():
		desc = village_data.get("description", "")
	
	# Build 16: Inheritance effect display at village
	var inheritance_text: String = _get_inheritance_display()
	if not inheritance_text.is_empty():
		body_text.text = "[color=#8888aa]%s[/color]\n\n[i]%s[/i]" % [inheritance_text, desc]
	else:
		body_text.text = "[i]%s[/i]" % desc
	
	_render_npc_buttons()
	_render_shop_buttons()


func _get_inheritance_display() -> String:
	# Show what was inherited (Task 4)
	var parts: Array = []
	# Check if run has inheritance bonuses applied
	# We check pending_inheritance before it's cleared by start_new_run
	# Actually start_new_run clears it, so we track separately
	# For now, check if loop > 1 and show generic text
	if GameState.loop_count > 1:
		if GameState.run_max_hp > 100:
			var bonus: int = GameState.run_max_hp - 100
			parts.append(LocaleManager.t("ui.inherited_display_hp", {"amount": bonus}))
		if GameState.run_gold > 0:
			parts.append(LocaleManager.t("ui.inherited_display_gold", {"amount": GameState.run_gold}))
	
	if parts.is_empty():
		return ""
	return LocaleManager.t("ui.inherited_from_past") + "\n" + "\n".join(parts)


func _render_npc_buttons() -> void:
	for child: Node in npc_buttons.get_children():
		child.queue_free()
	
	var npcs: Array = village_data.get("npcs", [])
	for i: int in range(npcs.size()):
		var npc: Dictionary = npcs[i]
		var npc_name: String = LocaleManager.tr_data(npc, "name")
		if npc_name.is_empty():
			npc_name = npc.get("name", "NPC")
		var btn := UITheme.create_choice_button(LocaleManager.t("ui.village_talk", {"name": npc_name}))
		btn.pressed.connect(_on_npc_talk.bind(i))
		npc_buttons.add_child(btn)


func _render_shop_buttons() -> void:
	for child: Node in shop_buttons.get_children():
		child.queue_free()
	
	# Healing potion: HP+30, 20G
	var potion_btn := UITheme.create_choice_button(LocaleManager.t("ui.shop_potion", {"cost": 20}))
	potion_btn.pressed.connect(_on_buy_potion)
	shop_buttons.add_child(potion_btn)
	
	# Talisman: DEF+2 for 1 battle, 30G
	var talisman_btn := UITheme.create_choice_button(LocaleManager.t("ui.shop_talisman", {"cost": 30}))
	talisman_btn.pressed.connect(_on_buy_talisman)
	shop_buttons.add_child(talisman_btn)


func _on_npc_talk(npc_index: int) -> void:
	current_npc_index = npc_index
	var npcs: Array = village_data.get("npcs", [])
	if npc_index >= npcs.size():
		return
	
	var npc: Dictionary = npcs[npc_index]
	var npc_name: String = LocaleManager.tr_data(npc, "name")
	if npc_name.is_empty():
		npc_name = npc.get("name", "NPC")
	
	# Show silhouette
	var sil_type: String = npc.get("silhouette", "")
	_show_silhouette(sil_type)
	
	# Find best matching dialogue
	var dialogues: Array = npc.get("dialogues", [])
	var best_dialogue: Dictionary = {}
	for dialogue: Variant in dialogues:
		if dialogue is not Dictionary:
			continue
		var conditions: Dictionary = dialogue.get("conditions", {})
		if conditions.is_empty() or GameState.check_event_conditions(conditions):
			best_dialogue = dialogue  # Last matching = highest priority (most specific)
	
	var text: String = LocaleManager.tr_data(best_dialogue, "text")
	if text.is_empty():
		text = best_dialogue.get("text", "……")
	
	body_text.text = "[b]%s[/b]\n\n%s" % [npc_name, text]
	
	# Replace NPC buttons with "back" button
	for child: Node in npc_buttons.get_children():
		child.queue_free()
	var back_btn := UITheme.create_choice_button(LocaleManager.t("ui.back"))
	back_btn.pressed.connect(_show_village_main)
	npc_buttons.add_child(back_btn)


func _on_buy_potion() -> void:
	if GameState.buy_item("potion", "回復薬", "heal", 30, 20):
		body_text.text += "\n\n[color=#60ff60]%s[/color]" % LocaleManager.t("ui.shop_bought_potion")
	else:
		body_text.text += "\n\n[color=#ff6060]%s[/color]" % LocaleManager.t("ui.shop_no_gold")
	_update_status()


func _on_buy_talisman() -> void:
	if GameState.buy_item("talisman", "護符", "defense_buff", 2, 30):
		body_text.text += "\n\n[color=#60ff60]%s[/color]" % LocaleManager.t("ui.shop_bought_talisman")
	else:
		body_text.text += "\n\n[color=#ff6060]%s[/color]" % LocaleManager.t("ui.shop_no_gold")
	_update_status()


func _show_silhouette(sil_type: String) -> void:
	if sil_type.is_empty() or not SILHOUETTES.has(sil_type):
		_hide_silhouette()
		return
	var path: String = SILHOUETTES[sil_type]
	if ResourceLoader.exists(path):
		silhouette_rect.texture = load(path)
		silhouette_rect.visible = true
		var tween: Tween = create_tween()
		silhouette_rect.modulate.a = 0.0
		tween.tween_property(silhouette_rect, "modulate:a", 0.25, 0.5)


func _hide_silhouette() -> void:
	if silhouette_rect.visible:
		var tween: Tween = create_tween()
		tween.tween_property(silhouette_rect, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void: silhouette_rect.visible = false)


func _on_depart() -> void:
	depart_requested.emit()


func _update_status() -> void:
	status_label.text = "HP: %d/%d | Gold: %d | %s" % [
		GameState.run_hp, GameState.run_max_hp, GameState.run_gold,
		LocaleManager.t("ui.village_items", {"count": GameState.run_items.size()})
	]
