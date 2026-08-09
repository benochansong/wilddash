extends WildDashModeController

const ROUND_DURATION := 38.0
const ARENA_RADIUS := 10.0
const ELIMINATION_RADIUS := 10.7
const PLAYER_PUSH_RADIUS := 3.0
const PLAYER_PUSH_STRENGTH := 10.5
const AI_PUSH_RADIUS := 2.35
const AI_PUSH_STRENGTH := 7.2

var ai_alive: Array[bool] = []
var ai_push_cooldowns: Array[float] = []

func _ready() -> void:
	setup_mode(&"push_out", "FINAL — Push-Out Arena", "Space 또는 E로 밀치기 · 상대를 링 밖으로 밀어내세요")
	_create_ring()
	player = spawn_racer("Dog", &"dog", Vector3(0.0, 0.15, 4.0), true, WildDashCharacterController.MovementMode.ARENA)
	player.arena_action_requested.connect(_on_player_push)

	var animals: Array[StringName] = [&"rabbit", &"elephant", &"cat", &"dog"]
	for i in range(GameManager.ai_count):
		var angle: float = TAU * float(i) / float(maxi(1, GameManager.ai_count))
		var spawn := Vector3(cos(angle) * 6.2, 0.15, sin(angle) * 6.2)
		var racer := spawn_racer("AI_%02d" % (i + 1), animals[i % animals.size()], spawn, false, WildDashCharacterController.MovementMode.ARENA)
		spawn_ai_driver(racer, WildDashAIController.AIMode.ARENA, 6.6 + float(i % 3) * 0.2)
		ai_alive.append(true)
		ai_push_cooldowns.append(0.35 + float(i) * 0.12)

	await get_tree().physics_frame
	await get_tree().physics_frame
	begin_mode(ROUND_DURATION, 8.0)

func _physics_process(delta: float) -> void:
	if mode_finished or not GameManager.round_active:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	_update_ai(delta)
	_check_eliminations()
	var remaining: int = _remaining_ai()
	hud.set_metrics("Rivals %d/%d   Time %.1f" % [remaining, ai_racers.size(), time_remaining])

	if _is_out(player):
		finish_mode(false, remaining, {"rivals_remaining": remaining, "player_out": true})
		return
	if remaining <= 0:
		finish_mode(true, ai_racers.size(), {"rivals_remaining": 0})
		return
	if time_remaining <= 0.0:
		finish_mode(false, ai_racers.size() - remaining, {"rivals_remaining": remaining, "timeout": true})

func _create_ring() -> void:
	var ring := CSGCylinder3D.new()
	ring.name = "PushOutRing"
	ring.position = Vector3(0.0, -0.25, 0.0)
	ring.radius = ARENA_RADIUS
	ring.height = 0.5
	ring.sides = 48
	ring.use_collision = true
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.22, 0.52)
	material.roughness = 0.75
	ring.material = material
	add_child(ring)

	var marker := CSGTorus3D.new()
	marker.name = "EdgeMarker"
	marker.position = Vector3(0.0, 0.04, 0.0)
	marker.inner_radius = ARENA_RADIUS - 0.35
	marker.outer_radius = ARENA_RADIUS
	marker.sides = 48
	marker.ring_sides = 8
	marker.use_collision = false
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.3, 0.42)
	marker_material.emission_enabled = true
	marker_material.emission = Color(0.5, 0.05, 0.08)
	marker.material = marker_material
	add_child(marker)

func _update_ai(delta: float) -> void:
	if player == null:
		return
	for i in range(ai_racers.size()):
		if not ai_alive[i]:
			continue
		ai_push_cooldowns[i] = maxf(0.0, ai_push_cooldowns[i] - delta)
		var racer: WildDashCharacterController = ai_racers[i]
		var angle := float(i) * 1.73
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * 0.7
		ai_drivers[i].set_arena_target(player.global_position + offset)
		var distance: float = racer.global_position.distance_to(player.global_position)
		if distance <= AI_PUSH_RADIUS and ai_push_cooldowns[i] <= 0.0:
			var direction := player.global_position - racer.global_position
			player.apply_knockback(direction, AI_PUSH_STRENGTH)
			racer.apply_knockback(-direction, 2.4)
			ai_push_cooldowns[i] = 1.35 + float(i % 3) * 0.18
			hud.set_message("AI body check! Use Space/E to shove back")

func _on_player_push() -> void:
	if mode_finished or player == null:
		return
	var hit_count := 0
	for i in range(ai_racers.size()):
		if not ai_alive[i]:
			continue
		var racer: WildDashCharacterController = ai_racers[i]
		var direction := racer.global_position - player.global_position
		if direction.length() <= PLAYER_PUSH_RADIUS:
			racer.apply_knockback(direction, PLAYER_PUSH_STRENGTH)
			hit_count += 1
	if hit_count > 0:
		hud.set_message("PUSH! %d rival(s) hit" % hit_count)

func _check_eliminations() -> void:
	for i in range(ai_racers.size()):
		if ai_alive[i] and _is_out(ai_racers[i]):
			_eliminate_ai(i)

func _eliminate_ai(index: int) -> void:
	ai_alive[index] = false
	ai_drivers[index].set_arena_enabled(false)
	var racer: WildDashCharacterController = ai_racers[index]
	racer.visible = false
	var collision := racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	print("PUSH OUT ELIMINATED %s remaining=%d" % [racer.name, _remaining_ai()])

func _remaining_ai() -> int:
	var count := 0
	for alive: bool in ai_alive:
		if alive:
			count += 1
	return count

func _is_out(racer: WildDashCharacterController) -> bool:
	if racer == null:
		return true
	var planar_radius := Vector2(racer.global_position.x, racer.global_position.z).length()
	return planar_radius > ELIMINATION_RADIUS or racer.global_position.y < -2.5
