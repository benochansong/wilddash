extends WildDashModeController

const COLS := 6
const ROWS := 5
const TILE_SIZE := 3.8
const ROUND_DURATION := 26.0
const PHASE_SECONDS := 2.25

var tile_bodies: Array[StaticBody3D] = []
var tile_meshes: Array[MeshInstance3D] = []
var tile_shapes: Array[CollisionShape3D] = []
var tile_centers: Array[Vector3] = []
var tile_active: Array[bool] = []
var player_hearts := 3
var _phase := -1

func _ready() -> void:
	setup_mode(&"floor_collapse", "ROUND 3 — Floor Collapse Survival", "무너지는 타일에서 살아남으세요 · 3 Hearts")
	_create_tile_floor()
	player = spawn_racer("Dog", &"dog", Vector3(0.0, 0.2, 0.0), true, WildDashCharacterController.MovementMode.ARENA)

	var animals: Array[StringName] = [&"rabbit", &"elephant", &"cat", &"dog"]
	for i in range(GameManager.ai_count):
		var start_index: int = (i * 7 + 2) % tile_centers.size()
		var racer := spawn_racer("AI_%02d" % (i + 1), animals[i % animals.size()], tile_centers[start_index] + Vector3.UP * 0.2, false, WildDashCharacterController.MovementMode.ARENA)
		spawn_ai_driver(racer, WildDashAIController.AIMode.ARENA, 6.2 + float(i % 3) * 0.2)

	await get_tree().physics_frame
	await get_tree().physics_frame
	begin_mode(ROUND_DURATION, 7.0)
	_apply_phase(0)

func _physics_process(delta: float) -> void:
	if mode_finished or not GameManager.round_active:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	var elapsed: float = (7.0 if DisplayServer.get_name() == "headless" else ROUND_DURATION) - time_remaining
	var next_phase: int = int(floor(elapsed / PHASE_SECONDS))
	if next_phase != _phase:
		_apply_phase(next_phase)

	_update_ai_targets()
	_check_falls()
	hud.set_metrics("Hearts %d   Phase %d   Time %.1f" % [player_hearts, _phase + 1, time_remaining])
	if player_hearts <= 0:
		finish_mode(false, int(ceil(elapsed)), {"hearts": 0, "phase": _phase})
		return
	if time_remaining <= 0.0:
		finish_mode(true, player_hearts, {"hearts": player_hearts, "phase": _phase, "survived": true})

func _create_tile_floor() -> void:
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.18, 0.68, 0.82)
	floor_material.roughness = 0.82
	for row in range(ROWS):
		for col in range(COLS):
			var index: int = row * COLS + col
			var x := (float(col) - float(COLS - 1) * 0.5) * TILE_SIZE
			var z := (float(row) - float(ROWS - 1) * 0.5) * TILE_SIZE
			var body := StaticBody3D.new()
			body.name = "Tile_%02d" % index
			body.position = Vector3(x, -0.2, z)

			var mesh_instance := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(TILE_SIZE - 0.18, 0.4, TILE_SIZE - 0.18)
			mesh_instance.mesh = mesh
			mesh_instance.material_override = floor_material
			body.add_child(mesh_instance)

			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(TILE_SIZE - 0.18, 0.4, TILE_SIZE - 0.18)
			collision.shape = shape
			body.add_child(collision)
			add_child(body)

			tile_bodies.append(body)
			tile_meshes.append(mesh_instance)
			tile_shapes.append(collision)
			tile_centers.append(Vector3(x, 0.15, z))
			tile_active.append(true)

func _apply_phase(phase: int) -> void:
	_phase = phase
	var collapse_level := mini(3, 1 + int(floor(float(phase) / 4.0)))
	for i in range(tile_active.size()):
		var collapsed := ((i + phase * 3) % 11) < collapse_level
		var warning := ((i + (phase + 1) * 3) % 11) < collapse_level
		tile_active[i] = not collapsed
		tile_meshes[i].visible = not collapsed
		tile_shapes[i].set_deferred("disabled", collapsed)
		if not collapsed:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(1.0, 0.68, 0.18) if warning else Color(0.18, 0.68, 0.82)
			material.roughness = 0.82
			tile_meshes[i].material_override = material
	print("FLOOR PHASE %d active_tiles=%d" % [phase, _active_tile_count()])

func _update_ai_targets() -> void:
	for i in range(ai_racers.size()):
		var preferred: int = (i * 7 + _phase * 5 + 3) % tile_centers.size()
		var safe_index: int = _nearest_active_tile(preferred)
		if safe_index >= 0:
			ai_drivers[i].set_arena_target(tile_centers[safe_index])

func _check_falls() -> void:
	if player != null and player.global_position.y < -3.5:
		player_hearts -= 1
		player.reset_motion(_safe_respawn_position())
		hud.set_message("Floor collapsed! Hearts %d" % player_hearts)
	for racer: WildDashCharacterController in ai_racers:
		if racer.global_position.y < -3.5:
			racer.reset_motion(_safe_respawn_position())

func _nearest_active_tile(preferred: int) -> int:
	if tile_active.is_empty():
		return -1
	for offset in range(tile_active.size()):
		var index: int = (preferred + offset) % tile_active.size()
		if tile_active[index]:
			return index
	return -1

func _safe_respawn_position() -> Vector3:
	var center_index := int(tile_active.size() / 2)
	var index: int = _nearest_active_tile(center_index)
	return Vector3(0.0, 2.0, 0.0) if index < 0 else tile_centers[index] + Vector3.UP * 1.8

func _active_tile_count() -> int:
	var count := 0
	for active: bool in tile_active:
		if active:
			count += 1
	return count
