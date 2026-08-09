extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.04, 0.06, 0.1, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var title := Label.new()
	title.text = "WILD DASH — 4 ROUND RESULT"
	title.position = Vector2(56, 48)
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)

	var summary := Label.new()
	var lines: Array[String] = ResultManager.get_summary_lines()
	summary.text = "\n".join(lines) + "\n\nClears %d / %d" % [ResultManager.get_success_count(), ResultManager.round_results.size()]
	summary.position = Vector2(58, 110)
	summary.add_theme_font_size_override("font_size", 20)
	add_child(summary)

	var hint := Label.new()
	hint.text = "R: replay four-round prototype"
	hint.position = Vector2(58, 330)
	hint.add_theme_font_size_override("font_size", 16)
	add_child(hint)

	print("HEADLESS RESULT rounds=%d clears=%d" % [ResultManager.round_results.size(), ResultManager.get_success_count()])
	for line: String in lines:
		print("RESULT " + line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_R:
			GameManager.reset_run()
			get_tree().change_scene_to_file("res://scenes/main.tscn")
