extends Node
## ThemeManager - Manages color themes based on world

signal theme_changed(world_id: String)

# Color themes per world (GDD 9.3, Phase 4 spec)
const THEMES := {
	"medieval": {
		"background": Color(0.15, 0.1, 0.2),  # Dark purple/gray
		"background_alt": Color(0.12, 0.08, 0.16),
		"panel": Color(0.2, 0.15, 0.25, 0.9),
		"text_primary": Color(0.9, 0.85, 0.8),
		"text_secondary": Color(0.7, 0.65, 0.6),
		"accent": Color(0.7, 0.5, 0.8),
		"highlight": Color(0.9, 0.7, 0.5),
		"danger": Color(0.8, 0.3, 0.3),
		"success": Color(0.5, 0.7, 0.5),
		"status_bar": Color(0.1, 0.08, 0.12, 0.95)
	},
	"future": {
		"background": Color(0.05, 0.1, 0.15),  # Dark blue/cyan
		"background_alt": Color(0.03, 0.08, 0.12),
		"panel": Color(0.08, 0.15, 0.2, 0.9),
		"text_primary": Color(0.8, 0.9, 0.95),
		"text_secondary": Color(0.6, 0.7, 0.75),
		"accent": Color(0.3, 0.7, 0.9),
		"highlight": Color(0.5, 0.9, 0.8),
		"danger": Color(0.9, 0.3, 0.4),
		"success": Color(0.3, 0.8, 0.6),
		"status_bar": Color(0.03, 0.06, 0.1, 0.95)
	},
	"default": {
		"background": Color(0.08, 0.08, 0.1),
		"background_alt": Color(0.06, 0.06, 0.08),
		"panel": Color(0.12, 0.12, 0.15, 0.9),
		"text_primary": Color(0.9, 0.9, 0.9),
		"text_secondary": Color(0.7, 0.7, 0.7),
		"accent": Color(0.6, 0.6, 0.8),
		"highlight": Color(0.8, 0.8, 0.6),
		"danger": Color(0.8, 0.3, 0.3),
		"success": Color(0.5, 0.7, 0.5),
		"status_bar": Color(0.05, 0.05, 0.08, 0.95)
	}
}

var current_world: String = "default"
var current_theme: Dictionary = THEMES["default"]


func _ready() -> void:
	current_theme = THEMES["default"]


func set_world(world_id: String) -> void:
	if world_id == current_world:
		return
	
	current_world = world_id
	current_theme = THEMES.get(world_id, THEMES["default"])
	theme_changed.emit(world_id)


func get_color(color_name: String) -> Color:
	return current_theme.get(color_name, Color.WHITE)


func get_background_color() -> Color:
	return current_theme.get("background", Color(0.08, 0.08, 0.1))


func get_panel_color() -> Color:
	return current_theme.get("panel", Color(0.12, 0.12, 0.15, 0.9))


func get_text_color() -> Color:
	return current_theme.get("text_primary", Color.WHITE)


func get_accent_color() -> Color:
	return current_theme.get("accent", Color(0.6, 0.6, 0.8))


func get_status_bar_color() -> Color:
	return current_theme.get("status_bar", Color(0.05, 0.05, 0.08, 0.95))


## Apply theme colors to a background ColorRect
func apply_to_background(rect: ColorRect) -> void:
	rect.color = get_background_color()


## Apply theme colors to common UI nodes recursively
func apply_to_control(control: Control, recursive: bool = false) -> void:
	if control is ColorRect and control.name == "Background":
		control.color = get_background_color()
	elif control is PanelContainer:
		# Panel containers get panel color via stylebox
		var stylebox := StyleBoxFlat.new()
		stylebox.bg_color = get_panel_color()
		stylebox.set_corner_radius_all(4)
		control.add_theme_stylebox_override("panel", stylebox)
	elif control is Label:
		control.add_theme_color_override("font_color", get_text_color())
	elif control is RichTextLabel:
		control.add_theme_color_override("default_color", get_text_color())
	
	if recursive:
		for child in control.get_children():
			if child is Control:
				apply_to_control(child, true)


## Get BBCode color tag for themed text
func bbcode_accent(text: String) -> String:
	var color := get_accent_color()
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]


func bbcode_highlight(text: String) -> String:
	var color: Color = current_theme.get("highlight", Color.YELLOW)
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]


func bbcode_danger(text: String) -> String:
	var color: Color = current_theme.get("danger", Color.RED)
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]
