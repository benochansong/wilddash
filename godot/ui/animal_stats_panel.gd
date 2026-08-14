class_name WildDashAnimalStatsPanel
extends PanelContainer

## Character-select A-layout right-hand detail card.
## Shows Terrain Adventure affinities plus Combat V2 Defense on one 0-10 scale.

const PANEL_WIDTH: float = 410.0
const PANEL_HEIGHT: float = 830.0

var _name_label: Label
var _role_label: Label
var _description_label: Label
var _context_label: Label
var _strengths_label: Label
var _weaknesses_label: Label
var _playstyle_label: Label
var _stat_bars: Dictionary = {}
var _stat_values: Dictionary = {}

func _ready() -> void:
	_build_panel()

func show_animal(animal_id: StringName, definition: WildDashAnimalDefinition, chimera_body: bool = false) -> void:
	if not is_node_ready():
		await ready
	if definition == null:
		return

	var profile: Dictionary = WildDashAnimalSelectionPresentation.get_profile(animal_id)
	_name_label.text = definition.display_name.to_upper()
	_role_label.text = definition.role
	_description_label.text = definition.skill_description
	_context_label.text = "CHIMERA BODY 기준 · 지형/방어 섀시" if chimera_body else "TERRAIN + COMBAT PROFILE"

	for stat_id: StringName in WildDashAnimalSelectionPresentation.STAT_ORDER:
		var value: float = float(profile.get(String(stat_id), 5.0))
		var bar: ProgressBar = _stat_bars.get(stat_id) as ProgressBar
		var value_label: Label = _stat_values.get(stat_id) as Label
		if bar != null:
			bar.value = value
		if value_label != null:
			value_label.text = "%.1f" % value

	var strengths: Array[StringName] = WildDashAnimalSelectionPresentation.get_strengths(animal_id, 2)
	var weaknesses: Array[StringName] = WildDashAnimalSelectionPresentation.get_weaknesses(animal_id, 2)
	_strengths_label.text = "강점   %s" % WildDashAnimalSelectionPresentation.format_tags(strengths)
	_weaknesses_label.text = "약점   %s" % WildDashAnimalSelectionPresentation.format_tags(weaknesses)
	_playstyle_label.text = WildDashAnimalSelectionPresentation.get_recommended_style(animal_id)

func _build_panel() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.045, 0.085, 0.95)
	panel_style.border_color = Color(0.22, 0.58, 0.78, 0.62)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	panel_style.shadow_size = 10
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_context_label = Label.new()
	_context_label.text = "TERRAIN + COMBAT PROFILE"
	_context_label.add_theme_font_size_override("font_size", 13)
	_context_label.add_theme_color_override("font_color", Color(0.38, 0.82, 1.0))
	box.add_child(_context_label)

	_name_label = Label.new()
	_name_label.text = "DOG"
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	box.add_child(_name_label)

	_role_label = Label.new()
	_role_label.text = "Balanced Runner"
	_role_label.add_theme_font_size_override("font_size", 17)
	_role_label.add_theme_color_override("font_color", Color(0.67, 0.77, 0.88))
	box.add_child(_role_label)

	_description_label = Label.new()
	_description_label.custom_minimum_size = Vector2(0, 64)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 15)
	_description_label.add_theme_color_override("font_color", Color(0.82, 0.87, 0.93))
	box.add_child(_description_label)

	var divider := HSeparator.new()
	divider.modulate = Color(0.42, 0.58, 0.72, 0.55)
	box.add_child(divider)

	var stat_header := HBoxContainer.new()
	box.add_child(stat_header)
	var stat_title := Label.new()
	stat_title.text = "능력치"
	stat_title.add_theme_font_size_override("font_size", 18)
	stat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_header.add_child(stat_title)
	var scale_label := Label.new()
	scale_label.text = "0  —  10"
	scale_label.add_theme_font_size_override("font_size", 12)
	scale_label.modulate = Color(0.62, 0.70, 0.80)
	stat_header.add_child(scale_label)

	for stat_id: StringName in WildDashAnimalSelectionPresentation.STAT_ORDER:
		_add_stat_row(box, stat_id)

	var divider_two := HSeparator.new()
	divider_two.modulate = Color(0.42, 0.58, 0.72, 0.55)
	box.add_child(divider_two)

	_strengths_label = _make_info_label(Color(0.47, 0.93, 0.59))
	box.add_child(_strengths_label)
	_weaknesses_label = _make_info_label(Color(1.0, 0.63, 0.49))
	box.add_child(_weaknesses_label)

	var playstyle_caption := Label.new()
	playstyle_caption.text = "추천 스타일"
	playstyle_caption.add_theme_font_size_override("font_size", 14)
	playstyle_caption.add_theme_color_override("font_color", Color(0.38, 0.82, 1.0))
	box.add_child(playstyle_caption)

	_playstyle_label = Label.new()
	_playstyle_label.custom_minimum_size = Vector2(0, 58)
	_playstyle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_playstyle_label.add_theme_font_size_override("font_size", 16)
	_playstyle_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.99))
	box.add_child(_playstyle_label)

	var footer := Label.new()
	footer.text = "지형 적성과 방어력은 실제 레이스 밸런스 수치를 반영합니다."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 12)
	footer.modulate = Color(0.55, 0.63, 0.73)
	box.add_child(footer)

func _add_stat_row(parent: VBoxContainer, stat_id: StringName) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = WildDashAnimalSelectionPresentation.get_stat_label(stat_id)
	label.custom_minimum_size = Vector2(58, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 10.0
	bar.value = 5.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(230, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _bar_background_style())
	bar.add_theme_stylebox_override("fill", _bar_fill_style(WildDashAnimalSelectionPresentation.get_stat_color(stat_id)))
	row.add_child(bar)
	_stat_bars[stat_id] = bar

	var value := Label.new()
	value.text = "5.0"
	value.custom_minimum_size = Vector2(42, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 15)
	value.add_theme_color_override("font_color", WildDashAnimalSelectionPresentation.get_stat_color(stat_id))
	row.add_child(value)
	_stat_values[stat_id] = value

func _bar_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.20, 0.92)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _bar_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _make_info_label(color: Color) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 28)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	return label
