extends Node

var _overlay: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if InputManager.consume_pause():
		if get_tree().paused:
			resume_game()
		elif GameManager.is_gameplay_state():
			pause_game()

func pause_game() -> void:
	if get_tree().paused or not GameManager.is_gameplay_state():
		return
	get_tree().paused = true
	_show_overlay()

func resume_game() -> void:
	get_tree().paused = false
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null

func _show_overlay() -> void:
	if _overlay != null:
		return
	_overlay = Control.new()
	_overlay.name = "PauseOverlay"
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)

	var box := VBoxContainer.new()
	box.position = Vector2(520, 250)
	box.custom_minimum_size = Vector2(400, 320)
	box.add_theme_constant_override("separation", 18)
	_overlay.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Esc / P / Gamepad Start"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(resume_game)
	box.add_child(resume)

	var lobby := Button.new()
	lobby.text = "Return to Lobby"
	lobby.pressed.connect(_return_to_lobby)
	box.add_child(lobby)

	var quit := Button.new()
	quit.text = "Quit Game"
	quit.pressed.connect(_quit_game)
	box.add_child(quit)
	resume.grab_focus()

func _return_to_lobby() -> void:
	resume_game()
	GameManager.abort_to_lobby()

func _quit_game() -> void:
	resume_game()
	SaveManager.save_current()
	get_tree().quit(0)
