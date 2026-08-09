class_name WildDashModeHUD
extends CanvasLayer

var _title_label: Label
var _metrics_label: Label
var _message_label: Label
var _item_label: Label
var _item_status_label: Label
var _skill_icon_label: Label
var _skill_label: Label
var _skill_status_label: Label
var _bound_character: WildDashCharacterController

func _ready() -> void:
	_title_label = Label.new()
	_title_label.position = Vector2(28, 24)
	_title_label.add_theme_font_size_override("font_size", 24)
	add_child(_title_label)

	_metrics_label = Label.new()
	_metrics_label.position = Vector2(28, 58)
	_metrics_label.add_theme_font_size_override("font_size", 18)
	add_child(_metrics_label)

	_message_label = Label.new()
	_message_label.position = Vector2(28, 88)
	_message_label.add_theme_font_size_override("font_size", 16)
	add_child(_message_label)

	_item_label = Label.new()
	_item_label.position = Vector2(1050, 24)
	_item_label.size = Vector2(350, 40)
	_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_item_label.add_theme_font_size_override("font_size", 22)
	add_child(_item_label)

	_item_status_label = Label.new()
	_item_status_label.position = Vector2(1020, 58)
	_item_status_label.size = Vector2(380, 34)
	_item_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_item_status_label.add_theme_font_size_override("font_size", 16)
	add_child(_item_status_label)
	set_item_state("—", "ITEM EMPTY")

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

func _process(_delta: float) -> void:
	if _bound_character == null or not is_instance_valid(_bound_character):
		return
	var cooldown := _bound_character.skill_cooldown_remaining
	var status := "READY · E / X" if cooldown <= 0.01 else "%.1f sec" % cooldown
	set_skill_state(_bound_character.get_skill_icon_text(), _bound_character.get_skill_name(), status)

func configure(title: String, message: String) -> void:
	_title_label.text = title
	_message_label.text = message

func bind_character(character: WildDashCharacterController) -> void:
	_bound_character = character

func set_metrics(text: String) -> void:
	_metrics_label.text = text

func set_message(text: String) -> void:
	_message_label.text = text

func set_item_state(item_name: String, status: String) -> void:
	_item_label.text = "ITEM  [ %s ]" % item_name
	_item_status_label.text = status

func set_skill_state(icon_text: String, skill_name: String, status: String) -> void:
	_skill_icon_label.text = "[ %s ]" % icon_text
	_skill_label.text = skill_name
	_skill_status_label.text = status
