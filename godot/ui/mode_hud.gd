class_name WildDashModeHUD
extends CanvasLayer

var _title_label: Label
var _metrics_label: Label
var _message_label: Label

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

func configure(title: String, message: String) -> void:
	_title_label.text = title
	_message_label.text = message

func set_metrics(text: String) -> void:
	_metrics_label.text = text

func set_message(text: String) -> void:
	_message_label.text = text
