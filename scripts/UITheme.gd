extends Node
## UITheme - Centralized UI sizing and styling constants for touch-friendly UI

# iOS HIG recommends 44pt minimum touch targets, we use 56px for safety margin
const TOUCH_TARGET_MIN := 56.0

# Font sizes (px)
const FONT_TITLE := 64
const FONT_HEADING := 28
const FONT_BODY := 22
const FONT_BUTTON := 22
const FONT_STATUS := 18
const FONT_SMALL := 16

# Button styling
const BUTTON_MIN_HEIGHT := 44.0
const BUTTON_MIN_WIDTH := 140.0
const BUTTON_CORNER_RADIUS := 8
const BUTTON_SPACING := 16

# Card styling
const CARD_PADDING := 16
const CARD_CORNER_RADIUS := 12
const CARD_MIN_HEIGHT := 100.0
const CARD_SPACING := 12

# Safe area margins (iOS notch/home bar)
const MARGIN_TOP := 60
const MARGIN_BOTTOM := 48
const MARGIN_SIDE := 24

# Line height multiplier for body text
const LINE_HEIGHT_MULTIPLIER := 1.4


## Create a styled button with proper touch target size
static func create_button(text: String, full_width: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_MIN_WIDTH, BUTTON_MIN_HEIGHT)
	button.add_theme_font_size_override("font_size", FONT_BUTTON)
	if full_width:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


## Create a large primary action button
static func create_primary_button(text: String) -> Button:
	var button := create_button(text, true)
	button.custom_minimum_size = Vector2(280, BUTTON_MIN_HEIGHT)
	
	# Apply styled background
	var normal := create_button_stylebox(Color(0.3, 0.3, 0.4, 0.9))
	var hover := create_button_stylebox(Color(0.4, 0.4, 0.5, 0.95))
	var pressed := create_button_stylebox(Color(0.25, 0.25, 0.35, 1.0))
	var disabled := create_button_stylebox(Color(0.2, 0.2, 0.25, 0.5))
	
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	
	return button


## Create a card-style choice button (for event choices)
static func create_choice_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_MIN_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", FONT_BUTTON)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Card-style appearance
	var normal := create_button_stylebox(Color(0.15, 0.15, 0.2, 0.9))
	normal.content_margin_left = CARD_PADDING
	normal.content_margin_right = CARD_PADDING
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	
	var hover := create_button_stylebox(Color(0.25, 0.25, 0.35, 0.95))
	hover.content_margin_left = CARD_PADDING
	hover.content_margin_right = CARD_PADDING
	hover.content_margin_top = 12
	hover.content_margin_bottom = 12
	
	var pressed := create_button_stylebox(Color(0.12, 0.12, 0.18, 1.0))
	pressed.content_margin_left = CARD_PADDING
	pressed.content_margin_right = CARD_PADDING
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 12
	
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	
	return button


## Create a navigation button (direction buttons)
static func create_nav_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, BUTTON_MIN_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", FONT_BUTTON)
	
	var normal := create_button_stylebox(Color(0.2, 0.2, 0.3, 0.85))
	var hover := create_button_stylebox(Color(0.3, 0.3, 0.4, 0.9))
	var pressed := create_button_stylebox(Color(0.15, 0.15, 0.25, 1.0))
	
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	
	return button


## Create a battle action button
static func create_battle_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", FONT_HEADING)
	
	var normal := create_button_stylebox(Color(0.25, 0.2, 0.3, 0.9))
	var hover := create_button_stylebox(Color(0.35, 0.3, 0.4, 0.95))
	var pressed := create_button_stylebox(Color(0.2, 0.15, 0.25, 1.0))
	var disabled := create_button_stylebox(Color(0.15, 0.12, 0.18, 0.5))
	
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	
	return button


## Create a styled stylebox for buttons
static func create_button_stylebox(bg_color: Color) -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = bg_color
	stylebox.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	stylebox.set_border_width_all(1)
	stylebox.border_color = Color(bg_color.r + 0.1, bg_color.g + 0.1, bg_color.b + 0.1, 0.5)
	stylebox.content_margin_left = 16
	stylebox.content_margin_right = 16
	stylebox.content_margin_top = 8
	stylebox.content_margin_bottom = 8
	return stylebox


## Create a card panel for job/inheritance cards
static func create_card_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	stylebox.set_corner_radius_all(CARD_CORNER_RADIUS)
	stylebox.set_border_width_all(1)
	stylebox.border_color = Color(0.3, 0.3, 0.4, 0.6)
	panel.add_theme_stylebox_override("panel", stylebox)
	
	return panel


## Create a world select card
static func create_world_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	stylebox.set_corner_radius_all(CARD_CORNER_RADIUS)
	stylebox.set_border_width_all(1)
	stylebox.border_color = Color(0.35, 0.35, 0.45, 0.6)
	stylebox.content_margin_left = CARD_PADDING
	stylebox.content_margin_right = CARD_PADDING
	stylebox.content_margin_top = CARD_PADDING
	stylebox.content_margin_bottom = CARD_PADDING
	panel.add_theme_stylebox_override("panel", stylebox)
	
	return panel


## Apply body text styling to RichTextLabel
static func style_body_text(rtl: RichTextLabel) -> void:
	rtl.add_theme_font_size_override("normal_font_size", FONT_BODY)
	rtl.add_theme_font_size_override("bold_font_size", FONT_BODY)
	rtl.add_theme_font_size_override("italics_font_size", FONT_BODY)
	# Line spacing would require theme resource or custom line_separation


## Apply heading style to label
static func style_heading(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_HEADING)


## Apply title style to label
static func style_title(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_TITLE)


## Apply status text style to label
static func style_status(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_STATUS)


## Create safe area margin container
static func create_safe_area_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_right", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_top", MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", MARGIN_BOTTOM)
	margin.anchors_preset = Control.PRESET_FULL_RECT
	return margin


## Apply safe area margins to existing margin container
static func apply_safe_margins(margin: MarginContainer) -> void:
	margin.add_theme_constant_override("margin_left", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_right", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_top", MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", MARGIN_BOTTOM)


## Style a progress bar (HP bar)
static func style_hp_bar(bar: ProgressBar, thick: bool = false) -> void:
	bar.custom_minimum_size = Vector2(bar.custom_minimum_size.x, 24 if thick else 20)
	bar.show_percentage = false
	
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)


## Update HP bar fill color based on percentage
static func update_hp_bar_color(bar: ProgressBar, current: int, max_val: int) -> void:
	var percent: float = float(current) / float(max_val) if max_val > 0 else 0.0
	var color: Color
	if percent > 0.5:
		color = Color(0.3, 0.7, 0.4)
	elif percent > 0.25:
		color = Color(0.8, 0.7, 0.3)
	else:
		color = Color(0.8, 0.3, 0.3)
	
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
