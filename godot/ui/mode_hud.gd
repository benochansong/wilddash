class_name WildDashModeHUD
extends CanvasLayer

const EXPANDED_ITEM_CATALOG: Script = preload("res://items/expanded_item_catalog.gd")

var _title_label: Label
var _metrics_label: Label
var _message_label: Label
var _boost_label: Label
var _body_check_label: Label
var _item_icon_label: Label
var _item_label: Label
var _item_status_label: Label
var _skill_icon_label: Label
var _skill_label: Label
var _skill_status_label: Label
var _rank_popup: Label
var _bound_character: WildDashCharacterController
var _racing_actions: WildDashRacingActionController
var _bear_combat: WildDashBearCombatV2Controller
var _rank_tween: Tween
var _item_tween: Tween

func _ready() -> void:
	layer = 10
	_build_panel(Vector2(18, 14), Vector2(570, 166), Color(0.12, 0.76, 0.80, 0.92))
	_build_panel(Vector2(986, 14), Vector2(424, 158), Color(1.0, 0.66, 0.18, 0.92))

	_title_label = Label.new()
	_title_label.position = Vector2(34, 26)
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0))
	add_child(_title_label)

	_metrics_label = Label.new()
	_metrics_label.position = Vector2(34, 60)
	_metrics_label.add_theme_font_size_override("font_size", 18)
	_metrics_label.add_theme_color_override("font_color", Color(0.80, 0.90, 0.96))
	add_child(_metrics_label)

	_boost_label = Label.new()
	_boost_label.position = Vector2(34, 90)
	_boost_label.add_theme_font_size_override("font_size", 16)
	_boost_label.text = ""
	add_child(_boost_label)

	_body_check_label = Label.new()
	_body_check_label.position = Vector2(34, 116)
	_body_check_label.add_theme_font_size_override("font_size", 16)
	_body_check_label.text = ""
	add_child(_body_check_label)

	_message_label = Label.new()
	_message_label.position = Vector2(34, 143)
	_message_label.add_theme_font_size_override("font_size", 15)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.44))
	add_child(_message_label)

	_item_icon_label = Label.new()
	_item_icon_label.position = Vector2(1004, 24)
	_item_icon_label.size = Vector2(72, 44)
	_item_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_icon_label.add_theme_font_size_override("font_size", 24)
	_item_icon_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	add_child(_item_icon_label)

	_item_label = Label.new()
	_item_label.position = Vector2(1062, 27)
	_item_label.size = Vector2(330, 40)
	_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_item_label.add_theme_font_size_override("font_size", 21)
	add_child(_item_label)

	_item_status_label = Label.new()
	_item_status_label.position = Vector2(1008, 59)
	_item_status_label.size = Vector2(384, 34)
	_item_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_item_status_label.add_theme_font_size_override("font_size", 15)
	_item_status_label.add_theme_color_override("font_color", Color(0.76, 0.87, 0.94))
	add_child(_item_status_label)
	set_item_state("—", "ITEM EMPTY", "--")

	_skill_icon_label = Label.new()
	_skill_icon_label.position = Vector2(1026, 102)
	_skill_icon_label.size = Vector2(58, 46)
	_skill_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_icon_label.add_theme_font_size_override("font_size", 25)
	_skill_icon_label.add_theme_color_override("font_color", Color(0.44, 0.91, 1.0))
	add_child(_skill_icon_label)

	_skill_label = Label.new()
	_skill_label.position = Vector2(1074, 100)
	_skill_label.size = Vector2(318, 40)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skill_label.add_theme_font_size_override("font_size", 19)
	add_child(_skill_label)

	_skill_status_label = Label.new()
	_skill_status_label.position = Vector2(1034, 132)
	_skill_status_label.size = Vector2(358, 32)
	_skill_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skill_status_label.add_theme_font_size_override("font_size", 15)
	_skill_status_label.add_theme_color_override("font_color", Color(0.76, 0.87, 0.94))
	add_child(_skill_status_label)
	set_skill_state("*", "CHARACTER SKILL", "READY")

	_rank_popup = Label.new()
	_rank_popup.position = Vector2(420, 86)
	_rank_popup.size = Vector2(600, 84)
	_rank_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_popup.add_theme_font_size_override("font_size", 38)
	_rank_popup.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	_rank_popup.modulate.a = 0.0
	_rank_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rank_popup)

	_resolve_racing_actions()
	print("GRAPHICS PHASE 3 HUD READY rounded=true rank_pop=true item_pop=true per_frame_nodes=false")

func _process(_delta: float) -> void:
	if _bound_character == null or not is_instance_valid(_bound_character):
		return
	var held_item: StringName = _bound_character.get_held_item()
	if EXPANDED_ITEM_CATALOG.is_expanded(held_item):
		set_item_state(
			EXPANDED_ITEM_CATALOG.get_display_name(held_item),
			"%s READY" % EXPANDED_ITEM_CATALOG.get_status_label(held_item),
			EXPANDED_ITEM_CATALOG.get_icon_text(held_item),
		)
	else:
		set_item_state(
			ItemSystem.get_display_name(held_item),
			ItemSystem.get_status_text(_bound_character),
			ItemSystem.get_icon_text(held_item),
		)
	var cooldown: float = _bound_character.skill_cooldown_remaining
	var status: String = "READY" if cooldown <= 0.01 else "%.1f sec" % cooldown
	set_skill_state(_bound_character.get_skill_icon_text(), _bound_character.get_skill_name(), status)
	_update_racing_action_status()

func configure(title: String, message: String) -> void:
	_title_label.text = title
	_message_label.text = message

func bind_character(character: WildDashCharacterController) -> void:
	_bound_character = character
	_resolve_racing_actions()

func set_metrics(text: String) -> void:
	_metrics_label.text = text

func set_message(text: String) -> void:
	_message_label.text = text

func set_item_state(item_name: String, status: String, icon_text := "--") -> void:
	_item_icon_label.text = "[ %s ]" % icon_text
	_item_label.text = "ITEM  [ %s ]" % item_name
	_item_status_label.text = status

func set_skill_state(icon_text: String, skill_name: String, status: String) -> void:
	_skill_icon_label.text = "[ %s ]" % icon_text
	_skill_label.text = skill_name
	_skill_status_label.text = status

func show_rank_change(old_rank: int, new_rank: int) -> void:
	if _rank_popup == null or old_rank <= 0 or new_rank <= 0 or old_rank == new_rank:
		return
	var improved := new_rank < old_rank
	_rank_popup.text = "%s  →  %s%s" % [_ordinal(old_rank), _ordinal(new_rank), "!" if improved else ""]
	_rank_popup.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28) if improved else Color(0.78, 0.87, 0.95))
	_rank_popup.modulate.a = 1.0
	_rank_popup.scale = Vector2(0.78, 0.78) if improved else Vector2(0.92, 0.92)
	_rank_popup.pivot_offset = _rank_popup.size * 0.5
	if _rank_tween != null and _rank_tween.is_valid():
		_rank_tween.kill()
	_rank_tween = create_tween()
	_rank_tween.tween_property(_rank_popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rank_tween.tween_interval(0.62 if improved else 0.38)
	_rank_tween.tween_property(_rank_popup, "modulate:a", 0.0, 0.26)

func play_item_pop(golden := false) -> void:
	if _item_icon_label == null:
		return
	_item_icon_label.scale = Vector2(0.74, 0.74)
	_item_icon_label.pivot_offset = _item_icon_label.size * 0.5
	_item_icon_label.add_theme_color_override("font_color", Color("ffe04f") if golden else Color("73ebff"))
	if _item_tween != null and _item_tween.is_valid():
		_item_tween.kill()
	_item_tween = create_tween()
	_item_tween.tween_property(_item_icon_label, "scale", Vector2(1.18, 1.18), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_item_tween.tween_property(_item_icon_label, "scale", Vector2.ONE, 0.16)

func _resolve_racing_actions() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	if _racing_actions == null or not is_instance_valid(_racing_actions):
		_racing_actions = parent.get_node_or_null("RacingActionController") as WildDashRacingActionController
	if _bear_combat == null or not is_instance_valid(_bear_combat):
		_bear_combat = parent.get_node_or_null("BearCombatV2Controller") as WildDashBearCombatV2Controller

func _update_racing_action_status() -> void:
	_resolve_racing_actions()
	if _racing_actions == null:
		_boost_label.text = ""
		_body_check_label.text = ""
		return

	var percent: int = int(round(_racing_actions.get_boost_energy_ratio() * 100.0))
	var blocks: int = clampi(int(round(float(percent) / 10.0)), 0, 10)
	var meter: String = ""
	for index: int in range(10):
		meter += "■" if index < blocks else "□"
	_boost_label.text = "BOOST  [%s] %3d%%  ·  %s" % [meter, percent, _racing_actions.get_boost_status_text()]
	_boost_label.add_theme_color_override("font_color", Color("69efff") if _racing_actions.is_boost_ready() else Color(0.78, 0.87, 0.94))

	if _bound_character != null and _bound_character.animal_id == &"bear" and _bear_combat != null:
		_body_check_label.text = "%s  ·  %s" % [
			_bear_combat.get_action_name(),
			_bear_combat.get_status_text(),
		]
		return

	var power: float = _racing_actions.get_current_body_check_power()
	_body_check_label.text = "%s  POWER %.1f  ·  %s" % [
		_racing_actions.get_contact_action_name(),
		power,
		_racing_actions.get_body_check_status_text(),
	]

func _build_panel(position: Vector2, size: Vector2, accent: Color) -> void:
	var panel := Panel.new()
	panel.position = position
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, 0.80)
	style.border_color = accent
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

func _ordinal(rank: int) -> String:
	var suffix := "TH"
	if rank % 100 < 11 or rank % 100 > 13:
		match rank % 10:
			1: suffix = "ST"
			2: suffix = "ND"
			3: suffix = "RD"
	return "%d%s" % [rank, suffix]
