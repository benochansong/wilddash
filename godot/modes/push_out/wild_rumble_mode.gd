extends WildDashModeController

## ROUND 4 — WILD RUMBLE: TITAN CLASH
## Phase 1 only: grounded arena, sand-moat ring outs, respawn and Dominance score.
## Phase 2 replaces the provisional F/Y shove below with ArenaCombatCore + Stagger.

const ROUND_DURATION := 90.0
const ARENA_RADIUS := 19.0
const RING_OUT_RADIUS := 19.55
const MOAT_RADIUS := 28.0
const RESPAWN_DELAY := 2.20
const SPAWN_PROTECTION_DURATION := 1.0
const ATTACK_CREDIT_WINDOW := 3.5
const RING_OUT_SCORE := 5

const PHASE1_TAP_RADIUS := 3.0
const PHASE1_TAP_STRENGTH := 8.6
const PHASE1_HEAVY_RADIUS := 3.55
const PHASE1_HEAVY_STRENGTH := 11.6
const PHASE1_AI_PUSH_RADIUS := 2.55
const PHASE1_AI_PUSH_STRENGTH := 7.4
const AI_DECISION_INTERVAL := 0.20

const ARENA_ROSTER: Array[StringName] = [
	&"dog", &"wolf", &"boar", &"rabbit", &"deer", &"monkey",
	&"elephant", &"bear", &"panda", &"cat", &"fox", &"raccoon",
]

var _scores: Dictionary = {}
var _ko_counts: Dictionary = {}
var _spawn_slots: Dictionary = {}
var _respawn_remaining: Dictionary = {}
var _spawn_protection: Dictionary = {}
var _last_attacker: Dictionary = {}
var _last_hit_age: Dictionary = {}
var _ai_push_cooldowns: Array[float] = []
var _ai_decision_elapsed := 0.0
var _phase1_combat_connected := false

func _ready() -> void:
	setup_mode(
		&"push_out",
		"ROUND 4 — WILD RUMBLE: TITAN CLASH",
		"PHASE 1 · F/Y 임시 타격 · RING OUT +5 · 2.2초 후 재진입",
		false
	)
	_create_titan_arena()
	_add_phase1_camera()

	player = spawn_racer(
		"Player",
		&"dog",
		_spawn_position_for_slot(0),
		true,
		WildDashCharacterController.MovementMode.ARENA
	)
	if player == null:
		push_error("WILD RUMBLE PHASE1 failed to spawn player")
		return
	_register_combatant(player, 0)

	var ai_count: int = maxi(0, GameManager.ai_count)
	for i in range(ai_count):
		var animal: StringName = ARENA_ROSTER[i % ARENA_ROSTER.size()]
		var slot := i + 1
		var racer := spawn_racer(
			"AI_%02d" % slot,
			animal,
			_spawn_position_for_slot(slot),
			false,
			WildDashCharacterController.MovementMode.ARENA
		)
		if racer == null:
			continue
		_register_combatant(racer, slot)
		var arena_speed := clampf(racer.arena_move_speed * 0.72, 5.4, 7.2)
		spawn_ai_driver(racer, WildDashAIController.AIMode.ARENA, arena_speed, 0.0, 0.0)
		_ai_push_cooldowns.append(0.45 + float(i % 5) * 0.11)

	if not InputManager.race_combat_action_resolved.is_connected(_on_phase1_combat_action):
		InputManager.race_combat_action_resolved.connect(_on_phase1_combat_action)
		_phase1_combat_connected = true

	await get_tree().physics_frame
	await get_tree().physics_frame
	begin_mode(ROUND_DURATION, 8.0)
	print("WILD RUMBLE PHASE1 READY arena_diameter=%.1f moat_radius=%.1f duration=%.0f respawn=%.2f racers=%d space_push=false" % [
		ARENA_RADIUS * 2.0,
		MOAT_RADIUS,
		ROUND_DURATION,
		RESPAWN_DELAY,
		racers.size(),
	])

func _exit_tree() -> void:
	if _phase1_combat_connected and InputManager.race_combat_action_resolved.is_connected(_on_phase1_combat_action):
		InputManager.race_combat_action_resolved.disconnect(_on_phase1_combat_action)
	_phase1_combat_connected = false

func _physics_process(delta: float) -> void:
	if mode_finished or not GameManager.round_active:
		return

	time_remaining = maxf(0.0, time_remaining - delta)
	_update_state_timers(delta)
	_update_phase1_ai(delta)
	_check_ring_outs()
	_update_hud()

	if time_remaining <= 0.0:
		_finish_score_battle()

func _create_titan_arena() -> void:
	var foundation := CSGCylinder3D.new()
	foundation.name = "TempleFoundation"
	foundation.position = Vector3(0.0, -1.62, 0.0)
	foundation.radius = MOAT_RADIUS + 5.5
	foundation.height = 0.22
	foundation.sides = 32
	foundation.use_collision = false
	foundation.material = _material(Color(0.19, 0.15, 0.13), 0.95)
	add_child(foundation)

	var moat := CSGCylinder3D.new()
	moat.name = "SandMoat"
	moat.position = Vector3(0.0, -1.25, 0.0)
	moat.radius = MOAT_RADIUS
	moat.height = 0.50
	moat.sides = 64
	moat.use_collision = true
	moat.material = _material(Color(0.66, 0.48, 0.25), 0.98)
	add_child(moat)

	var arena := CSGCylinder3D.new()
	arena.name = "TitanOctagonArena"
	arena.position = Vector3(0.0, -0.35, 0.0)
	arena.radius = ARENA_RADIUS
	arena.height = 0.70
	arena.sides = 8
	arena.use_collision = true
	arena.material = _material(Color(0.31, 0.28, 0.34), 0.82)
	add_child(arena)

	var edge := CSGTorus3D.new()
	edge.name = "RingOutEdgeMarker"
	edge.position = Vector3(0.0, 0.06, 0.0)
	edge.inner_radius = ARENA_RADIUS - 0.52
	edge.outer_radius = ARENA_RADIUS - 0.12
	edge.sides = 64
	edge.ring_sides = 8
	edge.use_collision = false
	edge.material = _emissive_material(Color(0.92, 0.29, 0.12), Color(0.35, 0.055, 0.02))
	add_child(edge)

	var center_disc := CSGCylinder3D.new()
	center_disc.name = "FutureTitanControlZone"
	center_disc.position = Vector3(0.0, 0.025, 0.0)
	center_disc.radius = 4.8
	center_disc.height = 0.05
	center_disc.sides = 48
	center_disc.use_collision = false
	center_disc.material = _emissive_material(Color(0.22, 0.36, 0.48), Color(0.035, 0.09, 0.15))
	add_child(center_disc)

	var totem := CSGCylinder3D.new()
	totem.name = "TitanTotemPhase1Marker"
	totem.position = Vector3(0.0, 1.65, 0.0)
	totem.radius = 0.75
	totem.height = 3.3
	totem.sides = 8
	totem.use_collision = false
	totem.material = _material(Color(0.36, 0.27, 0.18), 0.88)
	add_child(totem)

func _add_phase1_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "WildRumblePhase1Camera"
	camera.position = Vector3(0.0, 38.0, 28.0)
	camera.fov = 64.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _emissive_material(color: Color, emission: Color) -> StandardMaterial3D:
	var material := _material(color, 0.72)
	material.emission_enabled = true
	material.emission = emission
	return material

func _register_combatant(racer: WildDashCharacterController, slot: int) -> void:
	var id := racer.get_instance_id()
	_scores[id] = 0
	_ko_counts[id] = 0
	_spawn_slots[id] = slot
	_spawn_protection[id] = 0.0
	_last_hit_age[id] = ATTACK_CREDIT_WINDOW + 1.0

func _spawn_position_for_slot(slot: int) -> Vector3:
	if slot == 0:
		return Vector3(0.0, 0.20, 8.0)
	var ring_index := (slot - 1) % 2
	var ring_slot := int((slot - 1) / 2)
	var ring_radius := 8.8 + float(ring_index) * 4.0
	var slots_on_ring := maxi(6, int(ceil(float(maxi(1, GameManager.ai_count)) * 0.5)))
	var angle := TAU * float(ring_slot) / float(slots_on_ring) + float(ring_index) * 0.28
	return Vector3(cos(angle) * ring_radius, 0.20, sin(angle) * ring_radius)

func _update_state_timers(delta: float) -> void:
	for raw_id in _spawn_protection.keys():
		var id := int(raw_id)
		_spawn_protection[id] = maxf(0.0, float(_spawn_protection.get(id, 0.0)) - delta)

	for raw_id in _last_hit_age.keys():
		var id := int(raw_id)
		_last_hit_age[id] = float(_last_hit_age.get(id, ATTACK_CREDIT_WINDOW + 1.0)) + delta

	var ready_to_respawn: Array[int] = []
	for raw_id in _respawn_remaining.keys():
		var id := int(raw_id)
		var remaining := maxf(0.0, float(_respawn_remaining.get(id, 0.0)) - delta)
		_respawn_remaining[id] = remaining
		if remaining <= 0.0:
			ready_to_respawn.append(id)
	for id in ready_to_respawn:
		_respawn_remaining.erase(id)
		_respawn_combatant(id)

func _update_phase1_ai(delta: float) -> void:
	for i in range(_ai_push_cooldowns.size()):
		_ai_push_cooldowns[i] = maxf(0.0, _ai_push_cooldowns[i] - delta)

	_ai_decision_elapsed += delta
	if _ai_decision_elapsed >= AI_DECISION_INTERVAL:
		_ai_decision_elapsed = fmod(_ai_decision_elapsed, AI_DECISION_INTERVAL)
		for i in range(ai_racers.size()):
			var racer: WildDashCharacterController = ai_racers[i]
			if not _is_combatant_active(racer):
				continue
			var target := _nearest_active_opponent(racer)
			if target != null:
				var center_bias := Vector3.ZERO if i % 3 != 0 else -racer.global_position * 0.16
				ai_drivers[i].set_arena_target(target.global_position + center_bias)
			else:
				ai_drivers[i].set_arena_target(Vector3.ZERO)

	for i in range(ai_racers.size()):
		if i >= _ai_push_cooldowns.size():
			break
		var racer: WildDashCharacterController = ai_racers[i]
		if not _is_combatant_active(racer) or _ai_push_cooldowns[i] > 0.0:
			continue
		var target := _nearest_active_opponent(racer)
		if target == null:
			continue
		var offset := target.global_position - racer.global_position
		offset.y = 0.0
		if offset.length() <= PHASE1_AI_PUSH_RADIUS:
			_apply_phase1_shove(racer, target, offset, PHASE1_AI_PUSH_STRENGTH)
			_ai_push_cooldowns[i] = 1.10 + float(i % 4) * 0.16

func _nearest_active_opponent(source: WildDashCharacterController) -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_distance := INF
	for candidate in racers:
		if candidate == source or not _is_combatant_active(candidate):
			continue
		var distance := source.global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _on_phase1_combat_action(action: Dictionary) -> void:
	if mode_finished or not GameManager.round_active or not _is_combatant_active(player):
		return
	var kind: StringName = StringName(action.get("kind", &"tap"))
	var radius := PHASE1_HEAVY_RADIUS if kind == &"hold" else PHASE1_TAP_RADIUS
	var strength := PHASE1_HEAVY_STRENGTH if kind == &"hold" else PHASE1_TAP_STRENGTH
	var forward := -player.global_transform.basis.z.normalized()
	var hits := 0
	for target in racers:
		if target == player or not _is_combatant_active(target):
			continue
		var offset := target.global_position - player.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001 or offset.length() > radius:
			continue
		if forward.dot(offset.normalized()) < 0.05:
			continue
		_apply_phase1_shove(player, target, offset, strength)
		hits += 1
	if hits > 0:
		hud.set_message("%s! %d HIT · Phase 2에서 Power/Defense/Stagger로 교체" % [
			"HEAVY SMASH" if kind == &"hold" else "QUICK BASH",
			hits,
		])

func _apply_phase1_shove(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	direction: Vector3,
	strength: float,
) -> void:
	if source == null or target == null or not _is_combatant_active(source) or not _is_combatant_active(target):
		return
	var target_id := target.get_instance_id()
	if float(_spawn_protection.get(target_id, 0.0)) > 0.0:
		return
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= 0.001:
		return
	target.apply_knockback(planar.normalized(), strength)
	source.apply_knockback(-planar.normalized(), 1.25)
	_last_attacker[target_id] = source
	_last_hit_age[target_id] = 0.0

func _check_ring_outs() -> void:
	for racer in racers:
		if not _is_combatant_active(racer):
			continue
		var planar_radius := Vector2(racer.global_position.x, racer.global_position.z).length()
		if planar_radius > RING_OUT_RADIUS or racer.global_position.y < -2.6:
			_ring_out(racer)

func _ring_out(victim: WildDashCharacterController) -> void:
	if victim == null or not _is_combatant_active(victim):
		return
	var victim_id := victim.get_instance_id()
	var attacker: WildDashCharacterController = _last_attacker.get(victim_id, null) as WildDashCharacterController
	var credited := attacker != null and is_instance_valid(attacker) and attacker != victim
	credited = credited and float(_last_hit_age.get(victim_id, ATTACK_CREDIT_WINDOW + 1.0)) <= ATTACK_CREDIT_WINDOW
	if credited:
		var attacker_id := attacker.get_instance_id()
		_scores[attacker_id] = int(_scores.get(attacker_id, 0)) + RING_OUT_SCORE
		_ko_counts[attacker_id] = int(_ko_counts.get(attacker_id, 0)) + 1

	_respawn_remaining[victim_id] = RESPAWN_DELAY
	_last_attacker.erase(victim_id)
	_last_hit_age[victim_id] = ATTACK_CREDIT_WINDOW + 1.0
	_set_combatant_active(victim, false)

	if victim == player:
		hud.set_message("RING OUT! %.1fs 후 재진입%s" % [
			RESPAWN_DELAY,
			" · 상대 +%d" % RING_OUT_SCORE if credited else "",
		])
	elif credited and attacker == player:
		hud.set_message("RING OUT! +%d DOMINANCE" % RING_OUT_SCORE)

	print("WILD RUMBLE RING OUT victim=%s attacker=%s credited=%s respawn=%.2f" % [
		victim.get_display_name(),
		attacker.get_display_name() if credited else "none",
		str(credited),
		RESPAWN_DELAY,
	])

func _set_combatant_active(racer: WildDashCharacterController, value: bool) -> void:
	if racer == null:
		return
	racer.visible = value
	var collision := racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", not value)
	racer.set_physics_process(value)
	var ai_index := ai_racers.find(racer)
	if ai_index >= 0 and ai_index < ai_drivers.size():
		ai_drivers[ai_index].set_arena_enabled(value)
	if not value:
		racer.velocity = Vector3.ZERO
		racer.current_speed = 0.0

func _respawn_combatant(id: int) -> void:
	var racer := _find_racer_by_id(id)
	if racer == null:
		return
	var slot := int(_spawn_slots.get(id, 0))
	racer.reset_motion(_spawn_position_for_slot(slot))
	var look_target := Vector3.ZERO
	look_target.y = racer.global_position.y
	racer.look_at(look_target, Vector3.UP)
	_set_combatant_active(racer, true)
	_spawn_protection[id] = SPAWN_PROTECTION_DURATION
	if racer == player:
		hud.set_message("RESPAWN · 1.0s PROTECTION")
	print("WILD RUMBLE RESPAWN racer=%s protection=%.1f" % [racer.get_display_name(), SPAWN_PROTECTION_DURATION])

func _find_racer_by_id(id: int) -> WildDashCharacterController:
	for racer in racers:
		if racer != null and racer.get_instance_id() == id:
			return racer
	return null

func _is_combatant_active(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	return not _respawn_remaining.has(racer.get_instance_id())

func _score_for(racer: WildDashCharacterController) -> int:
	return 0 if racer == null else int(_scores.get(racer.get_instance_id(), 0))

func _kos_for(racer: WildDashCharacterController) -> int:
	return 0 if racer == null else int(_ko_counts.get(racer.get_instance_id(), 0))

func _rank_for(racer: WildDashCharacterController) -> int:
	var score := _score_for(racer)
	var rank := 1
	for other in racers:
		if other != racer and _score_for(other) > score:
			rank += 1
	return rank

func _update_hud() -> void:
	if player == null or hud == null:
		return
	hud.set_metrics("TIME %.0f   DOMINANCE %d   KOs %d   RANK %d/%d" % [
		time_remaining,
		_score_for(player),
		_kos_for(player),
		_rank_for(player),
		racers.size(),
	])

func _finish_score_battle() -> void:
	if mode_finished or player == null:
		return
	var player_score := _score_for(player)
	var best_score := player_score
	for racer in racers:
		best_score = maxi(best_score, _score_for(racer))
	var success := player_score >= best_score
	print("WILD RUMBLE PHASE1 COMPLETE player_score=%d player_kos=%d best_score=%d rank=%d" % [
		player_score,
		_kos_for(player),
		best_score,
		_rank_for(player),
	])
	finish_mode(success, player_score, {
		"dominance": player_score,
		"kos": _kos_for(player),
		"rank": _rank_for(player),
		"phase": 1,
		"score_mode": true,
	})
