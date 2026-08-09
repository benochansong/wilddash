extends WildDashModeController

const FRUIT_COUNT := 12
const TARGET_SCORE := 8
const ROUND_DURATION := 32.0
const FRUIT_COLORS: Array[Color] = [
	Color(1.0, 0.22, 0.25),
	Color(1.0, 0.82, 0.16),
	Color(0.55, 0.28, 0.9),
	Color(0.2, 0.85, 0.35),
	Color(1.0, 0.48, 0.12),
	Color(1.0, 0.35, 0.62),
]

var fruits: Array[MeshInstance3D] = []
var fruit_active: Array[bool] = []
var fruit_respawn: Array[float] = []
var fruit_cycles: Array[int] = []
var ai_scores: Array[int] = []
var player_score := 0

func _ready() -> void:
	setup_mode(&"fruit_collection", "ROUND 2 — Fruit Collection", "과일 8개를 먼저 모으세요 · WASD/방향키 이동")
	create_rect_arena(24.0, 24.0, true)
	player = spawn_racer("Dog", &"dog", Vector3(0.0, 0.1, 7.0), true, WildDashCharacterController.MovementMode.ARENA)

	var spawns: Array[Vector3] = [
		Vector3(-7.0, 0.1, -7.0), Vector3(7.0, 0.1, -7.0),
		Vector3(-7.0, 0.1, 2.0), Vector3(7.0, 0.1, 2.0),
		Vector3(-4.0, 0.1, 7.0), Vector3(4.0, 0.1, 7.0),
		Vector3(0.0, 0.1, -7.0), Vector3(-7.0, 0.1, 7.0),
		Vector3(7.0, 0.1, 7.0), Vector3(0.0, 0.1, 0.0),
	]
	var animals: Array[StringName] = [&"rabbit", &"elephant", &"cat", &"dog"]
	for i in range(GameManager.ai_count):
		var racer := spawn_racer("AI_%02d" % (i + 1), animals[i % animals.size()], spawns[i % spawns.size()], false, WildDashCharacterController.MovementMode.ARENA)
		spawn_ai_driver(racer, WildDashAIController.AIMode.ARENA, 6.8 + float(i % 3) * 0.25)

	ai_scores.resize(ai_racers.size())
	for i in range(ai_scores.size()):
		ai_scores[i] = 0
	_create_fruits()
	await get_tree().physics_frame
	await get_tree().physics_frame
	begin_mode(ROUND_DURATION, 6.0)

func _physics_process(delta: float) -> void:
	if mode_finished or not GameManager.round_active:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	_update_fruits(delta)
	_update_ai_targets_and_pickups()
	_check_player_pickups()

	var best_ai := 0
	for score: int in ai_scores:
		best_ai = maxi(best_ai, score)
	hud.set_metrics("YOU %d/%d   Best AI %d   Time %.1f" % [player_score, TARGET_SCORE, best_ai, time_remaining])

	if player_score >= TARGET_SCORE:
		finish_mode(true, player_score, {"best_ai": best_ai, "target": TARGET_SCORE})
		return
	if best_ai >= TARGET_SCORE:
		finish_mode(false, player_score, {"best_ai": best_ai, "target": TARGET_SCORE})
		return
	if time_remaining <= 0.0:
		finish_mode(false, player_score, {"best_ai": best_ai, "target": TARGET_SCORE, "timeout": true})

func _create_fruits() -> void:
	for i in range(FRUIT_COUNT):
		var fruit := MeshInstance3D.new()
		fruit.name = "Fruit_%02d" % (i + 1)
		var mesh := SphereMesh.new()
		mesh.radius = 0.42
		mesh.height = 0.84
		var material := StandardMaterial3D.new()
		material.albedo_color = FRUIT_COLORS[i % FRUIT_COLORS.size()]
		material.emission_enabled = true
		material.emission = material.albedo_color * 0.2
		mesh.material = material
		fruit.mesh = mesh
		fruit.position = _fruit_position(i, 0)
		add_child(fruit)
		fruits.append(fruit)
		fruit_active.append(true)
		fruit_respawn.append(0.0)
		fruit_cycles.append(0)

func _update_fruits(delta: float) -> void:
	for i in range(fruits.size()):
		if fruit_active[i]:
			continue
		fruit_respawn[i] -= delta
		if fruit_respawn[i] > 0.0:
			continue
		fruit_cycles[i] += 1
		fruit_active[i] = true
		fruits[i].visible = true
		fruits[i].position = _fruit_position(i, fruit_cycles[i])

func _check_player_pickups() -> void:
	if player == null:
		return
	for i in range(fruits.size()):
		if fruit_active[i] and player.global_position.distance_to(fruits[i].global_position) < 1.15:
			_collect_fruit(i)
			player_score += 1
			hud.set_message("Fruit collected! %d/%d" % [player_score, TARGET_SCORE])

func _update_ai_targets_and_pickups() -> void:
	for ai_index in range(ai_racers.size()):
		var racer: WildDashCharacterController = ai_racers[ai_index]
		var fruit_index: int = _nearest_active_fruit(racer.global_position)
		if fruit_index < 0:
			continue
		ai_drivers[ai_index].set_arena_target(fruits[fruit_index].global_position)
		if fruit_active[fruit_index] and racer.global_position.distance_to(fruits[fruit_index].global_position) < 1.05:
			_collect_fruit(fruit_index)
			ai_scores[ai_index] += 1

func _nearest_active_fruit(origin: Vector3) -> int:
	var best_index := -1
	var best_distance := INF
	for i in range(fruits.size()):
		if not fruit_active[i]:
			continue
		var distance: float = origin.distance_squared_to(fruits[i].global_position)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _collect_fruit(index: int) -> void:
	if index < 0 or index >= fruits.size() or not fruit_active[index]:
		return
	fruit_active[index] = false
	fruit_respawn[index] = 1.45
	fruits[index].visible = false

func _fruit_position(index: int, cycle: int) -> Vector3:
	var x := -9.0 + float((index * 7 + cycle * 5) % 19)
	var z := -9.0 + float((index * 11 + cycle * 3) % 19)
	return Vector3(x, 0.72, z)
