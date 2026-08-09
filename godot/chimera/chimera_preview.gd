extends Node3D

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")

var loadout: WildDashChimeraLoadout
var racer: WildDashCharacterController
var info_label: Label
var _animal_ids := WildDashAnimalCatalog.all_ids()
var _palette_index := 0
var _pattern_index := 0

func _ready() -> void:
	loadout = SaveManager.load_chimera()
	_palette_index = maxi(0, WildDashChimeraSystem.PALETTES.find(loadout.palette_id))
	_pattern_index = maxi(0, WildDashChimeraSystem.PATTERNS.find(loadout.pattern_id))
	_build_stage()
	_build_preview_racer()
	_build_ui()
	_refresh_preview()

func _process(delta: float) -> void:
	if racer != null:
		racer.rotation.y += delta * 0.42

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: _cycle_slot(&"head", -1)
		KEY_2: _cycle_slot(&"head", 1)
		KEY_3: _cycle_slot(&"body", -1)
		KEY_4: _cycle_slot(&"body", 1)
		KEY_5: _cycle_slot(&"tail", -1)
		KEY_6: _cycle_slot(&"tail", 1)
		KEY_C: _cycle_palette()
		KEY_P: _cycle_pattern()
		KEY_ENTER, KEY_KP_ENTER: _save_and_apply()

func _build_stage() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	add_child(light)

	var floor := CSGCylinder3D.new()
	floor.radius = 4.0
	floor.height = 0.35
	floor.position.y = -0.18
	floor.sides = 48
	floor.use_collision = true
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.16, 0.24)
	material.roughness = 0.82
	floor.material = material
	add_child(floor)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.2, 7.2)
	camera.fov = 52.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _build_preview_racer() -> void:
	racer = RACER_SCENE.instantiate() as WildDashCharacterController
	racer.is_player = false
	racer.movement_mode = WildDashCharacterController.MovementMode.ARENA
	racer.position = Vector3.ZERO
	add_child(racer)
	racer.configure_chimera(loadout)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.04, 0.08, 0.82)
	panel.position = Vector2(24, 24)
	panel.size = Vector2(520, 250)
	layer.add_child(panel)
	info_label = Label.new()
	info_label.position = Vector2(20, 16)
	info_label.size = Vector2(485, 220)
	info_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(info_label)

func _cycle_slot(slot: StringName, direction: int) -> void:
	var current: StringName = loadout.head_id
	if slot == &"body": current = loadout.body_id
	elif slot == &"tail": current = loadout.tail_id
	var index := _animal_ids.find(current)
	index = posmod(index + direction, _animal_ids.size())
	if slot == &"head": loadout.head_id = _animal_ids[index]
	elif slot == &"body": loadout.body_id = _animal_ids[index]
	else: loadout.tail_id = _animal_ids[index]
	_refresh_preview()

func _cycle_palette() -> void:
	_palette_index = (_palette_index + 1) % WildDashChimeraSystem.PALETTES.size()
	loadout.palette_id = WildDashChimeraSystem.PALETTES[_palette_index]
	_refresh_preview()

func _cycle_pattern() -> void:
	_pattern_index = (_pattern_index + 1) % WildDashChimeraSystem.PATTERNS.size()
	loadout.pattern_id = WildDashChimeraSystem.PATTERNS[_pattern_index]
	_refresh_preview()

func _refresh_preview() -> void:
	loadout.normalize()
	if racer != null:
		racer.configure_chimera(loadout)
	var description := WildDashChimeraSystem.describe(loadout)
	if info_label != null:
		info_label.text = "WILD DASH CHIMERA LAB\n\nHead  %s  — %s\nBody  %s  — %s\nTail  %s  — %s\nPalette %s   Pattern %s\n\n1/2 Head · 3/4 Body · 5/6 Tail · C Color · P Pattern\nEnter: Save & use" % [
			description.head, description.passive.name,
			description.body, description.body_role,
			description.tail, description.skill_name,
			description.palette, description.pattern,
		]

func _save_and_apply() -> void:
	SaveManager.save_chimera(loadout)
	GameManager.configure_chimera(loadout.to_dictionary(), true)
	if info_label != null:
		info_label.text += "\n\nSAVED — Chimera enabled for the next campaign."
