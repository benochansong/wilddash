extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameManager.set_state(GameManager.GameState.RESULT)
	AudioManager.play_theme("result")
	var lines: Array[String] = ResultManager.get_summary_lines()
	var saved := SaveManager.record_campaign_result(ResultManager.round_results, GameManager.selected_animal)
	print("RC_FLOW Result")
	print("RC_SAVE result_saved=%s campaigns=%d" % [
		str(saved), int((SaveManager.current_data.get("profile", {}) as Dictionary).get("campaigns", 0)),
	])
	for line: String in lines:
		print("RESULT " + line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)
		return
	_build_ui(lines)

func _build_ui(lines: Array[String]) -> void:
	var background := ColorRect.new()
	background.color = SettingsManager.get_background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.position = Vector2(360, 105)
	box.custom_minimum_size = Vector2(720, 700)
	box.add_theme_constant_override("separation", 16)
	add_child(box)

	var title := Label.new()
	title.text = "WILD DASH — RESULT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	box.add_child(title)

	var summary := Label.new()
	summary.text = "\n".join(lines) + "\n\nClears %d / %d" % [ResultManager.get_success_count(), ResultManager.round_results.size()]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 21)
	box.add_child(summary)

	var saved_label := Label.new()
	saved_label.text = "Progress saved locally."
	saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(saved_label)

	var replay := Button.new()
	replay.text = "PLAY AGAIN"
	replay.custom_minimum_size = Vector2(0, 62)
	replay.pressed.connect(_on_replay)
	box.add_child(replay)

	var lobby := Button.new()
	lobby.text = "RETURN TO LOBBY"
	lobby.custom_minimum_size = Vector2(0, 58)
	lobby.pressed.connect(_on_lobby)
	box.add_child(lobby)

	var quit := Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(_on_quit)
	box.add_child(quit)
	replay.grab_focus()

func _on_replay() -> void:
	AudioManager.play_sfx_id("ui")
	ResultManager.reset_campaign()
	GameManager.show_character_select()

func _on_lobby() -> void:
	AudioManager.play_sfx_id("ui")
	GameManager.return_to_lobby()

func _on_quit() -> void:
	SaveManager.save_current()
	get_tree().quit(0)
