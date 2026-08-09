extends Control

const KEY_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"accelerate", &"brake",
	&"jump", &"skill", &"item", &"pause",
]
const ACTION_LABELS: Dictionary = {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"accelerate": "Accelerate / Forward",
	"brake": "Brake / Back",
	"jump": "Jump",
	"skill": "Skill",
	"item": "Item",
	"pause": "Pause",
}

var _waiting_action: StringName = &""
var _waiting_button: Button
var _background: ColorRect
var _resolution_option: OptionButton
var _fps_option: OptionButton
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _mute_check: CheckButton
var _fullscreen_check: CheckButton
var _reduced_motion_check: CheckButton
var _high_contrast_check: CheckButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	_background = ColorRect.new()
	_background.color = SettingsManager.get_background_color()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	var root_box := VBoxContainer.new()
	root_box.position = Vector2(90, 45)
	root_box.custom_minimum_size = Vector2(1260, 800)
	root_box.add_theme_constant_override("separation", 12)
	add_child(root_box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	root_box.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	root_box.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 650)
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(560, 650)
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)

	_add_section(left, "AUDIO")
	var audio: Dictionary = SettingsManager.get_audio_settings()
	_master_slider = _add_slider(left, "Master Volume", float(audio.get("master_volume", 0.85)), _on_master_changed)
	_music_slider = _add_slider(left, "Music Volume", float(audio.get("music_volume", 0.62)), _on_music_changed)
	_sfx_slider = _add_slider(left, "SFX Volume", float(audio.get("sfx_volume", 0.82)), _on_sfx_changed)
	_mute_check = CheckButton.new()
	_mute_check.text = "Mute All Audio"
	_mute_check.button_pressed = bool(audio.get("muted", false))
	_mute_check.toggled.connect(_on_mute_toggled)
	left.add_child(_mute_check)

	_add_section(left, "GRAPHICS")
	var graphics: Dictionary = SettingsManager.get_graphics_settings()
	_resolution_option = OptionButton.new()
	for size: Vector2i in SettingsManager.RESOLUTIONS:
		_resolution_option.add_item("%d × %d" % [size.x, size.y])
	var current_size := Vector2i(int(graphics.get("width", 1600)), int(graphics.get("height", 900)))
	var resolution_index := SettingsManager.RESOLUTIONS.find(current_size)
	_resolution_option.select(maxi(0, resolution_index))
	_resolution_option.item_selected.connect(_on_resolution_selected)
	left.add_child(_labeled_control("Resolution", _resolution_option))

	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.button_pressed = bool(graphics.get("fullscreen", false))
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	left.add_child(_fullscreen_check)

	_fps_option = OptionButton.new()
	for fps: int in SettingsManager.FPS_OPTIONS:
		_fps_option.add_item("Unlimited" if fps == 0 else "%d FPS" % fps)
	var current_fps := int(graphics.get("fps_limit", 60))
	var fps_index := SettingsManager.FPS_OPTIONS.find(current_fps)
	_fps_option.select(maxi(0, fps_index))
	_fps_option.item_selected.connect(_on_fps_selected)
	left.add_child(_labeled_control("FPS Limit", _fps_option))

	_add_section(left, "ACCESSIBILITY")
	_reduced_motion_check = CheckButton.new()
	_reduced_motion_check.text = "Reduced Motion"
	_reduced_motion_check.button_pressed = SettingsManager.is_reduced_motion()
	_reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	left.add_child(_reduced_motion_check)
	_high_contrast_check = CheckButton.new()
	_high_contrast_check.text = "High Contrast"
	_high_contrast_check.button_pressed = SettingsManager.is_high_contrast()
	_high_contrast_check.toggled.connect(_on_high_contrast_toggled)
	left.add_child(_high_contrast_check)

	_add_section(right, "KEYBOARD BINDINGS")
	var gamepad_hint := Label.new()
	gamepad_hint.text = "Gamepad defaults stay active while keyboard keys are remapped."
	gamepad_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(gamepad_hint)
	var first_rebind: Button
	for action: StringName in KEY_ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(ACTION_LABELS[String(action)])
		label.custom_minimum_size = Vector2(230, 36)
		row.add_child(label)
		var binding := Button.new()
		binding.text = "%s   [Pad: %s]" % [InputManager.get_keyboard_binding_text(action), InputManager.get_gamepad_hint(action)]
		binding.custom_minimum_size = Vector2(300, 36)
		binding.pressed.connect(_on_rebind_pressed.bind(action, binding))
		row.add_child(binding)
		right.add_child(row)
		if first_rebind == null:
			first_rebind = binding

	var back := Button.new()
	back.text = "SAVE & BACK TO LOBBY"
	back.custom_minimum_size = Vector2(0, 58)
	back.pressed.connect(_on_back)
	root_box.add_child(back)
	if _master_slider != null:
		_master_slider.grab_focus()

func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	parent.add_child(label)

func _add_slider(parent: VBoxContainer, label_text: String, value: float, callback: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 34)
	slider.value_changed.connect(callback)
	parent.add_child(_labeled_control(label_text, slider))
	return slider

func _labeled_control(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190, 36)
	row.add_child(label)
	row.add_child(control)
	return row

func _on_master_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)

func _on_music_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)

func _on_sfx_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value)
	AudioManager.play_sfx_id("ui", 0.7)

func _on_mute_toggled(value: bool) -> void:
	SettingsManager.set_muted(value)

func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution(SettingsManager.RESOLUTIONS[clampi(index, 0, SettingsManager.RESOLUTIONS.size() - 1)])

func _on_fullscreen_toggled(value: bool) -> void:
	SettingsManager.set_fullscreen(value)

func _on_fps_selected(index: int) -> void:
	SettingsManager.set_fps_limit(SettingsManager.FPS_OPTIONS[clampi(index, 0, SettingsManager.FPS_OPTIONS.size() - 1)])

func _on_reduced_motion_toggled(value: bool) -> void:
	SettingsManager.set_reduced_motion(value)

func _on_high_contrast_toggled(value: bool) -> void:
	SettingsManager.set_high_contrast(value)
	_background.color = SettingsManager.get_background_color()

func _on_rebind_pressed(action: StringName, button: Button) -> void:
	_waiting_action = action
	_waiting_button = button
	button.text = "Press a keyboard key... (Esc cancels)"
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action == &"" or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_ESCAPE:
		_cancel_rebind()
		get_viewport().set_input_as_handled()
		return
	if SettingsManager.rebind_keyboard(_waiting_action, key_event.physical_keycode):
		_waiting_button.text = "%s   [Pad: %s]" % [
			InputManager.get_keyboard_binding_text(_waiting_action), InputManager.get_gamepad_hint(_waiting_action),
		]
		AudioManager.play_sfx_id("ui")
	_waiting_action = &""
	_waiting_button = null
	get_viewport().set_input_as_handled()

func _cancel_rebind() -> void:
	if _waiting_button != null:
		_waiting_button.text = "%s   [Pad: %s]" % [
			InputManager.get_keyboard_binding_text(_waiting_action), InputManager.get_gamepad_hint(_waiting_action),
		]
	_waiting_action = &""
	_waiting_button = null

func _on_back() -> void:
	SaveManager.save_current()
	AudioManager.play_sfx_id("ui")
	GameManager.return_to_lobby()
