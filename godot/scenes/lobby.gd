extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameManager.set_state(GameManager.GameState.LOBBY)
	AudioManager.play_theme("menu")
	print("RC_FLOW Launch")
	print("RC_FLOW Lobby")
	var profile: Dictionary = SaveManager.current_data.get("profile", {})
	print("RC_SAVE_LOADED launches=%d campaigns=%d last_character=%s" % [
		int(profile.get("launches", 0)), int(profile.get("campaigns", 0)), String(profile.get("last_character", "dog")),
	])
	if DisplayServer.get_name() == "headless" and OS.has_environment("WILDDASH_AUTOTEST_LOAD_ONLY"):
		get_tree().quit(0)
		return
	if DisplayServer.get_name() == "headless" and OS.has_environment("WILDDASH_AUTOTEST"):
		call_deferred("_autotest_continue")
		return
	_build_ui(profile)

func _build_ui(profile: Dictionary) -> void:
	var background := ColorRect.new()
	background.color = SettingsManager.get_background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.position = Vector2(420, 150)
	box.custom_minimum_size = Vector2(600, 620)
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.text = "WILD DASH 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "RC3 GAMEPLAY UPGRADE · OFFLINE SINGLE PLAYER"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	box.add_child(subtitle)

	var profile_label := Label.new()
	profile_label.text = "Campaigns %d   Wins %d   Fans %d   Best GP %d" % [
		int(profile.get("campaigns", 0)), int(profile.get("wins", 0)),
		int(profile.get("fans", 0)), int(profile.get("best", 50)),
	]
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_label)

	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(0, 72)
	play.add_theme_font_size_override("font_size", 26)
	play.pressed.connect(_on_play)
	box.add_child(play)

	var settings_button := Button.new()
	settings_button.text = "SETTINGS"
	settings_button.custom_minimum_size = Vector2(0, 58)
	settings_button.pressed.connect(_on_settings)
	box.add_child(settings_button)

	var controls := Label.new()
	controls.text = "Keyboard: WASD / Arrows · Space Jump · E Skill · Q Item · Esc/P Pause\nGamepad: Left Stick / D-Pad · A Jump · X Skill · B Item · Start Pause"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(controls)

	var quit := Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(_on_quit)
	box.add_child(quit)
	play.grab_focus()

func _on_play() -> void:
	AudioManager.play_sfx_id("ui")
	GameManager.show_character_select()

func _on_settings() -> void:
	AudioManager.play_sfx_id("ui")
	GameManager.show_settings()

func _on_quit() -> void:
	SaveManager.save_current()
	get_tree().quit(0)

func _autotest_continue() -> void:
	await get_tree().process_frame
	GameManager.show_character_select()
