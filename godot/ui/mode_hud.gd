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
var _bound_character: WildDashCharacterController
var _racing_actions: WildDashRacingActionController

func _ready() -> void:
	_title_label = Label.new()
	_title_label.position = Vector2(28, 24)
	_title_label.add_theme_font_size_override("font_size", 24)
	add_child(_title_label)

	_metrics_label = Label.new()
	_metrics_label.position = Vector2(28, 58)
	_metrics_label.add_theme_font_size_override("font_size", 18)
	add_child(_metrics_label)

	_boost_label = Label.new()
	_boost_label.position = Vector2(28, 88)
	_boost_label.add_theme_font_size_override("font_size", 16)
	_boost_label.text = ""
	add_child(_boost_label)

	_body_check_label = Label.new()
	_body_check_label.position = Vector2(28, 114)
	_body_check_label.add_theme_font_size_override("font_size", 16)
	_body_check_label.text = ""
	add_child(_body_check_label)

	_message_label = Label.new()
	_message_label.position = Vector2(28, 142)
	_message_label.add_theme_font_size_override("font_size", 16)
	add_child(_message_label)

	_item_icon_label = Label.new()
	_item_icon_label.position = Vector2(1010, 20)
	_item_icon_label.size = Vector2(72, 44)
	_item_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_icon_label.add_theme_font_size_override("font_size", 24)
	add_child(_item_icon_label)

	_item_label = Label.new()
	_item_label.position = Vector2(1070, 24)
	_item_label.size = Vector2(330, 40)
	_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_item_label.add_theme_font_size_override("font_size", 22)
	add_child(_item_label)

	_item_status_label = Label.new()
	_item_status_label.position = Vector2(1010, 58)
	_item_status_label.size = Vector2(390, 34)
	_item_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_item_status_label.add_theme_font_size_override("font_size", 16)
	add_child(_item_status_label)
	set_item_state("—", "ITEM EMPTY", "--")

	_skill_icon_label = Label.new()
	_skill_icon_label.position = Vector2(1032, 104)
	_skill_icon_label.size = Vector2(58, 46)
	_skill_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_icon_label.add_theme_font_size_override("font_size", 26)
	add_child(_skill_icon_label)

	_skill_label = Label.new()
	_skill_label.position = Vector2(1080, 100)
	_skill_label.size = Vector2(320, 40)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skill_label.add_theme_font_size_override("font_size", 20)
	add_child(_skill_label)

	_skill_status_label = Label.new()
	_skill_status_label.position = Vector2(1040, 134)
	_skill_status_label.size = Vector2(360, 32)
	_skill_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skill_status_label.add_theme_font_size_override("font_size", 16)
	add_child(_skill_status_label)
	set_skill_state("*", "CHARACTER SKILL", "READY · E / X")

	_resolve_racing_actions()

func _process(_delta: float) -> void:
	if _bound_character == null or not is_instance_valid(_bound_character):
		return
	var held_item: StringName = _bound_character.get_held_item()
	if EXPANDED_ITEM_CATALOG.is_expanded(held_item):
		set_item_state(
			EXPANDED_ITEM_CATALOG.get_display_name(held_item),
			"%s READY · Q / B" % EXPANDED_ITEM_CATALOG.get_status_label(held_item),
			EXPANDED_ITEM_CATALOG.get_icon_text(held_item),
		)
	else:
		set_item_state(
			ItemSystem.get_display_name(held_item),
			ItemSystem.get_status_text(_bound_character),
			ItemSystem.get_icon_text(held_item),
		)
	var cooldown: float = _bound_character.skill_cooldown_remaining
	var status: String = "READY · E / X" if cooldown <= 0.01 else "%.1f sec" % cooldown
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

func _resolve_racing_actions() -> void:
	if _racing_actions != null and is_instance_valid(_racing_actions):
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	_racing_actions = parent.get_node_or_null("RacingActionController") as WildDashRacingActionController

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
	_boost_label.text = "BOOST ENERGY  [%s] %3d%%  ·  %s" % [meter, percent, _racing_actions.get_boost_status_text()]

	var power: float = _racing_actions.get_current_body_check_power()
	_body_check_label.text = "%s  POWER %.1f  ·  %s" % [
		_racing_actions.get_contact_action_name(),
		power,
		_racing_actions.get_body_check_status_text(),
	]
