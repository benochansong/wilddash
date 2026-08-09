extends Control

const ANIMALS: Array[StringName] = [&"dog", &"rabbit", &"elephant", &"cat"]
const ANIMAL_LABELS: Dictionary = {
	"dog": "DOG · Sprint",
	"rabbit": "RABBIT · Jump",
	"elephant": "ELEPHANT · Defense",
	"cat": "CAT · Evasion",
}
const DIFFICULTIES: Array[StringName] = [&"wild", &"chaos", &"nightmare"]

var _selected: StringName = &"dog"
var _difficulty: StringName = &"chaos"
var _selection_label: Label
var _difficulty_option: OptionButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameManager.set_state(GameManager.GameState.CHARACTER_SELECT)
	_selected = SaveManager.get_last_character()
	print("RC_FLOW Character Select")
	if DisplayServer.get_name() == "headless" and OS.has_environment("WILDDASH_AUTOTEST"):
		call_deferred("_autotest_start")
		return
	_build_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = SettingsManager.get_background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.position = Vector2(340, 105)
	box.custom_minimum_size = Vector2(760, 700)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title := Label.new()
	title.text = "CHOOSE YOUR RACER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	box.add_child(title)

	_selection_label = Label.new()
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_selection_label)
	_update_selection_text()

	var first_button: Button
	for animal: StringName in ANIMALS:
		var button := Button.new()
		button.text = String(ANIMAL_LABELS[String(animal)])
		button.custom_minimum_size = Vector2(0, 60)
		button.pressed.connect(_select_animal.bind(animal))
		box.add_child(button)
		if first_button == null:
			first_button = button

	var difficulty_label := Label.new()
	difficulty_label.text = "Difficulty"
	box.add_child(difficulty_label)
	_difficulty_option = OptionButton.new()
	_difficulty_option.add_item("Wild")
	_difficulty_option.add_item("Chaos")
	_difficulty_option.add_item("Nightmare")
	_difficulty_option.select(1)
	_difficulty_option.item_selected.connect(_on_difficulty_selected)
	box.add_child(_difficulty_option)

	var start := Button.new()
	start.text = "START 4-ROUND RUN"
	start.custom_minimum_size = Vector2(0, 72)
	start.add_theme_font_size_override("font_size", 24)
	start.pressed.connect(_start_run)
	box.add_child(start)

	var back := Button.new()
	back.text = "BACK TO LOBBY"
	back.pressed.connect(GameManager.return_to_lobby)
	box.add_child(back)
	if first_button != null:
		first_button.grab_focus()

func _select_animal(animal: StringName) -> void:
	_selected = animal
	AudioManager.play_sfx_id("ui")
	_update_selection_text()

func _update_selection_text() -> void:
	if _selection_label != null:
		_selection_label.text = "Selected: %s" % String(_selected).to_upper()

func _on_difficulty_selected(index: int) -> void:
	_difficulty = DIFFICULTIES[clampi(index, 0, DIFFICULTIES.size() - 1)]

func _start_run() -> void:
	var requested_ai := GameManager.MIN_AI_COUNT
	if OS.has_environment("WILDDASH_AI_COUNT"):
		requested_ai = int(OS.get_environment("WILDDASH_AI_COUNT"))
	GameManager.configure_run(_selected, _difficulty, {"head": 0, "body": 0, "tail": 0}, requested_ai)
	AudioManager.play_sfx_id("ui")
	print("RC_FLOW Race requested animal=%s difficulty=%s ai=%d" % [String(_selected), String(_difficulty), GameManager.ai_count])
	GameManager.start_campaign()

func _autotest_start() -> void:
	await get_tree().process_frame
	_selected = &"dog"
	_difficulty = &"chaos"
	_start_run()
