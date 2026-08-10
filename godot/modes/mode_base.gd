class_name WildDashModeController
extends Node3D

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const AI_SKILL_BRAIN_SCRIPT: Script = preload("res://characters/ai_skill_brain.gd")

var mode_id: StringName = &""
var display_name := ""
var player: WildDashCharacterController
var racers: Array[WildDashCharacterController] = []
var ai_racers: Array[WildDashCharacterController] = []
var ai_drivers: Array[WildDashAIController] = []
var hud: WildDashModeHUD
var time_remaining := 0.0
var mode_finished := false

func setup_mode(id: StringName, title: String, instruction: String, use_fixed_camera := true) -> void:
	mode_id = id
	display_name = title
	_add_sun()
	if use_fixed_camera:
		_add_fixed_camera()
	hud = WildDashModeHUD.new()
	add_child(hud)
	hud.configure(title, instruction)

func begin_mode(normal_duration: float, headless_duration := 6.0) -> void:
	mode_finished = false
	time_remaining = headless_duration if DisplayServer.get_name() == "headless" else normal_duration
	GameManager.begin_round(mode_id)
	print("MODE START id=%s ai=%d" % [mode_id, ai_racers.size()])

func finish_mode(success: bool, score: int, details: Dictionary = {}) -> void:
	if mode_finished:
		return
	mode_finished = true
	GameManager.complete_round(mode_id, success, score, details)

func spawn_racer(
	node_name: String,
	animal: StringName,
	spawn_position: Vector3,
	is_player_character: bool,
	movement: WildDashCharacterController.MovementMode,
) -> WildDashCharacterController:
	var racer := RACER_SCENE.instantiate() as WildDashCharacterController
	if racer == null:
		push_error("Failed to instantiate shared racer scene")
		return null
	var resolved_animal := animal
	if is_player_character and WildDashAnimalCatalog.is_valid(GameManager.selected_animal):
		resolved_animal = GameManager.selected_animal
	if is_player_character and GameManager.chimera_enabled:
		resolved_animal = GameManager.get_chimera_loadout().body_id
	racer.name = node_name
	racer.animal_id = resolved_animal
	racer.is_player = is_player_character
	racer.movement_mode = movement
	racer.position = spawn_position
	add_child(racer)
	if is_player_character and GameManager.chimera_enabled:
		racer.configure_chimera(GameManager.get_chimera_loadout())
	racers.append(racer)
	if is_player_character:
		player = racer
		if hud != null:
			hud.bind_character(racer)
	else:
		ai_racers.append(racer)
	return racer

func spawn_ai_driver(
	racer: WildDashCharacterController,
	ai_mode: WildDashAIController.AIMode,
	speed: float,
	lane := 0.0,
	wander := 0.15,
	preserve_player_identity := false,
) -> WildDashAIController:
	var driver := WildDashAIController.new()
	driver.name = "%sAI" % racer.name
	driver.racer_path = NodePath("../%s" % racer.name)
	driver.ai_mode = ai_mode
	driver.target_speed = speed
	driver.preferred_lane = lane
	driver.lane_wander = wander
	driver.preserve_player_identity = preserve_player_identity
	# Race-specific base values are established before _ready(), so the
	# difficulty profile scales the intended tuned driver rather than defaults.
	if ai_mode == WildDashAIController.AIMode.RACE:
		driver.steering_strength = 5.8
		driver.acceleration = 22.0
		driver.avoidance_distance = 7.5
	add_child(driver)
	ai_drivers.append(driver)

	var skill_brain := AI_SKILL_BRAIN_SCRIPT.new() as WildDashAISkillBrain
	if skill_brain != null:
		skill_brain.name = "%sSkillBrain" % racer.name
		skill_brain.racer_path = NodePath("../%s" % racer.name)
		add_child(skill_brain)
	return driver

func create_box(
	node_name: String,
	box_position: Vector3,
	box_size: Vector3,
	color: Color,
	collision := true,
) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = node_name
	box.position = box_position
	box.size = box_size
	box.use_collision = collision
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	box.material = material
	add_child(box)
	return box

func create_rect_arena(width: float, depth: float, with_walls := true) -> void:
	create_box("ArenaFloor", Vector3(0.0, -0.25, 0.0), Vector3(width, 0.5, depth), Color(0.16, 0.2, 0.27))
	if not with_walls:
		return
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	var wall_color := Color(0.16, 0.7, 0.82)
	create_box("NorthWall", Vector3(0.0, 1.0, -half_depth - 0.25), Vector3(width, 2.0, 0.5), wall_color)
	create_box("SouthWall", Vector3(0.0, 1.0, half_depth + 0.25), Vector3(width, 2.0, 0.5), wall_color)
	create_box("WestWall", Vector3(-half_width - 0.25, 1.0, 0.0), Vector3(0.5, 2.0, depth), wall_color)
	create_box("EastWall", Vector3(half_width + 0.25, 1.0, 0.0), Vector3(0.5, 2.0, depth), wall_color)

func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _add_fixed_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "ModeCamera"
	camera.position = Vector3(0.0, 19.0, 15.0)
	camera.fov = 62.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
