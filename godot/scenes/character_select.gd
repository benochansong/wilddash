extends Node3D

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const BASIC_ANIMAL_IDS: Array[StringName] = [
	&"dog", &"wolf", &"boar",
	&"rabbit", &"deer", &"monkey",
	&"elephant", &"bear", &"panda",
	&"cat", &"fox", &"raccoon",
]
const CHIMERA_ANIMAL_IDS: Array[StringName] = [&"dog", &"rabbit", &"elephant", &"cat"]
const DIFFICULTIES: Array[StringName] = [&"wild", &"chaos", &"nightmare"]

var _chimera_mode := false
var _selected_animal: StringName = &"dog"
var _difficulty: StringName = &"chaos"
var _loadout: WildDashChimeraLoadout
var _preview_racer: WildDashCharacterController
var _summary_label: Label
var _mode_label: Label
var _start_button: Button
var _stats_panel: WildDashAnimalStatsPanel
var _palette_index := 0
var _pattern_index := 0
var _slot_labels: Dictionary = {}
var _animal_buttons: Dictionary = {}

func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CHARACTER_SELECT)
	_loadout = SaveManager.load_chimera()
	if WildDashAnimalCatalog.is_playable(GameManager.selected_animal):
		_selected_animal = GameManager.selected_animal
	_palette_index = maxi(0, WildDashChimeraSystem.PALETTES.find(_loadout.palette_id))
	_pattern_index = maxi(0, WildDashChimeraSystem.PATTERNS.find(_loadout.pattern_id))
	RenderingServer.set_default_clear_color(Color(0.025, 0.045, 0.085))
	_build_preview_stage()
	_build_ui()
	_refresh_preview()
	print("CHARACTER SELECT READY basic=12 chimera_parts=4 stats=canonical6 responsive_right=true")

func _process(delta: float) -> void:
	if _preview_racer != null:
		_preview_racer.rotation.y += delta * 0.34

func set_chimera_mode(enabled: bool) -> void:
	_chimera_mode = enabled
	_refresh_preview()

func select_animal(animal_id: StringName) -> void:
	if not WildDashAnimalCatalog.is_playable(animal_id):
		return
	_selected_animal = animal_id
	_chimera_mode = false
	_refresh_preview()

func cycle_chimera_slot(slot: StringName, direction: int) -> void:
	var current: StringName = _loadout.head_id
	if slot == &"body":
		current = _loadout.body_id
	elif slot == &"tail":
		current = _loadout.tail_id
	var index := CHIMERA_ANIMAL_IDS.find(current)
	if index < 0:
		index = 0
	index = posmod(index + direction, CHIMERA_ANIMAL_IDS.size())
	if slot == &"head":
		_loadout.head_id = CHIMERA_ANIMAL_IDS[index]
	elif slot == &"body":
		_loadout.body_id = CHIMERA_ANIMAL_IDS[index]
	elif slot == &"tail":
		_loadout.tail_id = CHIMERA_ANIMAL_IDS[index]
	_chimera_mode = true
	_refresh_preview()

func get_preview_racer() -> WildDashCharacterController:
	return _preview_racer

func get_current_loadout() -> WildDashChimeraLoadout:
	return _loadout.duplicate_loadout()

func is_chimera_mode() -> bool:
	return _chimera_mode

func save_current_selection() -> bool:
	if _chimera_mode:
		_loadout.normalize()
		GameManager.configure_chimera(_loadout.to_dictionary(), true)
		return SaveManager.save_chimera(_loadout)
	GameManager.disable_chimera()
	return true

func _build_preview_stage() -> void:
	var light := DirectionalLight3D.new()
	light.name = "PreviewLight"
	light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)

	var fill := OmniLight3D.new()
	fill.name = "PreviewFill"
	fill.position = Vector3(3.5, 4.0, 4.5)
	fill.light_energy = 3.0
	fill.omni_range = 12.0
	add_child(fill)

	var floor := CSGCylinder3D.new()
	floor.name = "PreviewPlatform"
	floor.radius = 3.9
	floor.height = 0.4
	floor.position = Vector3(3.8, -0.2, 0.0)
	floor.sides = 48
	floor.use_collision = true
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.10, 0.16, 0.25)
	floor_material.metallic = 0.15
	floor_material.roughness = 0.62
	floor.material = floor_material
	add_child(floor)

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(3.8, 3.0, 7.3)
	camera.fov = 50.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(3.8, 1.0, 0.0), Vector3.UP)

	_preview_racer = RACER_SCENE.instantiate() as WildDashCharacterController
	_preview_racer.name = "PreviewRacer"
	_preview_racer.is_player = false
	_preview_racer.movement_mode = WildDashCharacterController.MovementMode.ARENA
	_preview_racer.position = Vector3(3.8, 0.1, 0.0)
	add_child(_preview_racer)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CharacterSelectUI"
	add_child(layer)

	var ui_root := Control.new()
	ui_root.name = "ResponsiveRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui_root)

	var shade := ColorRect.new()
	shade.name = "LeftShade"
	shade.color = Color(0.015, 0.025, 0.05, 0.92)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 610.0
	ui_root.add_child(shade)

	var left_margin := MarginContainer.new()
	left_margin.name = "LeftControls"
	left_margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_margin.offset_left = 34.0
	left_margin.offset_right = 574.0
	left_margin.offset_top = 22.0
	left_margin.offset_bottom = -26.0
	ui_root.add_child(left_margin)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(540, 0)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	left_margin.add_child(box)

	var title := Label.new()
	title.text = "WILD DASH — CHOOSE YOUR RACER"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.35, 0.88, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "12 UNIQUE RACERS · 6개 실제 능력치·체급·스킬을 비교하고 선택하세요."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle)

	var mode_row := HBoxContainer.new()
	box.add_child(mode_row)
	var basic_button := Button.new()
	basic_button.text = "12 RACERS"
	basic_button.custom_minimum_size = Vector2(260, 42)
	basic_button.pressed.connect(set_chimera_mode.bind(false))
	mode_row.add_child(basic_button)
	var chimera_button := Button.new()
	chimera_button.text = "CHIMERA LAB · CORE 4"
	chimera_button.custom_minimum_size = Vector2(260, 42)
	chimera_button.pressed.connect(set_chimera_mode.bind(true))
	mode_row.add_child(chimera_button)

	_mode_label = Label.new()
	_mode_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_mode_label)

	var animal_grid := GridContainer.new()
	animal_grid.columns = 3
	animal_grid.add_theme_constant_override("h_separation", 6)
	animal_grid.add_theme_constant_override("v_separation", 5)
	box.add_child(animal_grid)
	for animal_id: StringName in BASIC_ANIMAL_IDS:
		var definition := WildDashAnimalCatalog.get_definition(animal_id)
		var button := Button.new()
		button.text = definition.display_name.to_upper()
		button.tooltip_text = "%s · %s · %s" % [
			definition.display_name,
			WildDashAnimalSelectionPresentation.get_identity(animal_id),
			definition.skill_name,
		]
		button.custom_minimum_size = Vector2(170, 48)
		button.toggle_mode = true
		button.pressed.connect(select_animal.bind(animal_id))
		animal_grid.add_child(button)
		_animal_buttons[animal_id] = button

	var divider := HSeparator.new()
	box.add_child(divider)

	var chimera_title := Label.new()
	chimera_title.text = "CHIMERA CORE PARTS · DOG / RABBIT / ELEPHANT / CAT"
	chimera_title.add_theme_font_size_override("font_size", 15)
	box.add_child(chimera_title)
	_add_slot_row(box, &"head", "HEAD · Active Skill")
	_add_slot_row(box, &"body", "BODY · Passive Trait")
	_add_slot_row(box, &"tail", "TAIL · Utility Bonus")

	var style_row := HBoxContainer.new()
	box.add_child(style_row)
	var color_button := Button.new()
	color_button.text = "COLOR ▶"
	color_button.custom_minimum_size = Vector2(255, 38)
	color_button.pressed.connect(_cycle_palette)
	style_row.add_child(color_button)
	var pattern_button := Button.new()
	pattern_button.text = "PATTERN ▶"
	pattern_button.custom_minimum_size = Vector2(255, 38)
	pattern_button.pressed.connect(_cycle_pattern)
	style_row.add_child(pattern_button)

	_summary_label = Label.new()
	_summary_label.custom_minimum_size = Vector2(0, 94)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 15)
	box.add_child(_summary_label)

	var difficulty := OptionButton.new()
	difficulty.add_item("Wild · Casual (10 racers)")
	difficulty.add_item("Chaos · Normal (15 racers)")
	difficulty.add_item("Nightmare · Hard (18 racers)")
	difficulty.select(1)
	difficulty.item_selected.connect(_on_difficulty_selected)
	box.add_child(difficulty)

	_start_button = Button.new()
	_start_button.text = "START 5-ROUND RUN"
	_start_button.custom_minimum_size = Vector2(0, 54)
	_start_button.add_theme_font_size_override("font_size", 20)
	_start_button.pressed.connect(_start_run)
	box.add_child(_start_button)

	var hints := Label.new()
	hints.text = "동물 선택 → 오른쪽 6능력치 비교 · H/B/T: Chimera · Enter: Start"
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints.modulate = Color(0.7, 0.76, 0.86)
	box.add_child(hints)

	var right_column := MarginContainer.new()
	right_column.name = "RightDetailColumn"
	right_column.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_column.offset_left = -448.0
	right_column.offset_right = -28.0
	right_column.offset_top = 35.0
	right_column.offset_bottom = -35.0
	right_column.add_theme_constant_override("margin_left", 5)
	right_column.add_theme_constant_override("margin_right", 5)
	ui_root.add_child(right_column)

	_stats_panel = WildDashAnimalStatsPanel.new()
	_stats_panel.name = "AnimalStatsPanel"
	_stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(_stats_panel)

	basic_button.grab_focus()

func _add_slot_row(parent: VBoxContainer, slot: StringName, caption: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.custom_minimum_size = Vector2(185, 34)
	row.add_child(caption_label)
	var previous := Button.new()
	previous.text = "◀"
	previous.custom_minimum_size = Vector2(44, 34)
	previous.pressed.connect(cycle_chimera_slot.bind(slot, -1))
	row.add_child(previous)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.custom_minimum_size = Vector2(160, 34)
	row.add_child(value)
	_slot_labels[slot] = value
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(44, 34)
	next.pressed.connect(cycle_chimera_slot.bind(slot, 1))
	row.add_child(next)

func _refresh_preview() -> void:
	if _preview_racer == null or _loadout == null:
		return
	if _chimera_mode:
		_loadout.normalize()
		_preview_racer.configure_chimera(_loadout)
		var description := WildDashChimeraSystem.describe(_loadout)
		_mode_label.text = "MODE: CHIMERA PLAYSTYLE BUILD"
		_summary_label.text = "HEAD %s → %s\nBODY %s → %s\nTAIL %s → %s\nColor %s · Pattern %s" % [
			description.head, description.skill_name,
			description.body, description.body_passive.name,
			description.tail, description.tail_utility.name,
			description.palette, description.pattern,
		]
		_slot_labels[&"head"].text = String(_loadout.head_id).to_upper()
		_slot_labels[&"body"].text = String(_loadout.body_id).to_upper()
		_slot_labels[&"tail"].text = String(_loadout.tail_id).to_upper()
		_start_button.text = "SAVE BUILD & START"
		var body_definition := WildDashAnimalCatalog.get_definition(_loadout.body_id)
		if _stats_panel != null:
			_stats_panel.show_animal(_loadout.body_id, body_definition, true)
	else:
		_preview_racer.configure_animal(_selected_animal)
		var definition := WildDashAnimalCatalog.get_definition(_selected_animal)
		_mode_label.text = "MODE: %s · %s" % [
			definition.display_name.to_upper(),
			WildDashAnimalSelectionPresentation.get_identity(_selected_animal),
		]
		_summary_label.text = "Speed %.1f · Accel %.1f · Handling %.2f · Jump %.1f · Arena %.1f\nSkill: %s · Cooldown %.1fs\n%s" % [
			definition.max_speed, definition.acceleration, definition.turn_speed, definition.jump_velocity,
			definition.arena_move_speed, definition.skill_name, definition.skill_cooldown, definition.skill_description,
		]
		_start_button.text = "START AS %s" % definition.display_name.to_upper()
		if _stats_panel != null:
			_stats_panel.show_animal(_selected_animal, definition, false)
	_refresh_animal_button_states()

func _refresh_animal_button_states() -> void:
	for raw_id: Variant in _animal_buttons.keys():
		var animal_id: StringName = StringName(raw_id)
		var button: Button = _animal_buttons[raw_id] as Button
		if button == null:
			continue
		button.button_pressed = not _chimera_mode and animal_id == _selected_animal

func _cycle_palette() -> void:
	_palette_index = (_palette_index + 1) % WildDashChimeraSystem.PALETTES.size()
	_loadout.palette_id = WildDashChimeraSystem.PALETTES[_palette_index]
	_chimera_mode = true
	_refresh_preview()

func _cycle_pattern() -> void:
	_pattern_index = (_pattern_index + 1) % WildDashChimeraSystem.PATTERNS.size()
	_loadout.pattern_id = WildDashChimeraSystem.PATTERNS[_pattern_index]
	_chimera_mode = true
	_refresh_preview()

func _on_difficulty_selected(index: int) -> void:
	_difficulty = DIFFICULTIES[clampi(index, 0, DIFFICULTIES.size() - 1)]

func _start_run() -> void:
	var requested_ai := -1
	if OS.has_environment("WILDDASH_AI_COUNT"):
		requested_ai = int(OS.get_environment("WILDDASH_AI_COUNT"))
	if _chimera_mode:
		save_current_selection()
		GameManager.configure_run(_loadout.body_id, _difficulty, _loadout.to_dictionary(), requested_ai)
		print("CHARACTER SELECT START chimera head=%s body=%s tail=%s" % [_loadout.head_id, _loadout.body_id, _loadout.tail_id])
	else:
		GameManager.disable_chimera()
		GameManager.configure_run(_selected_animal, _difficulty, {}, requested_ai)
		print("CHARACTER SELECT START animal=%s role=%s" % [
			_selected_animal,
			WildDashAnimalSelectionPresentation.get_identity(_selected_animal),
		])
	GameManager.start_campaign()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: select_animal(&"dog")
		KEY_2: select_animal(&"rabbit")
		KEY_3: select_animal(&"elephant")
		KEY_4: select_animal(&"cat")
		KEY_H: cycle_chimera_slot(&"head", 1)
		KEY_B: cycle_chimera_slot(&"body", 1)
		KEY_T: cycle_chimera_slot(&"tail", 1)
		KEY_C: _cycle_palette()
		KEY_P: _cycle_pattern()
		KEY_ENTER, KEY_KP_ENTER: _start_run()
