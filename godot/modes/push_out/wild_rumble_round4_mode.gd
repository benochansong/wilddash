extends "res://modes/push_out/wild_rumble_phase2_mode.gd"

## ROUND 4 — WILD RUMBLE: TITAN CROWN
## Current campaign finale. The round evolves from a three-objective relic war
## into an awakening arena, a shrinking high-stagger brawl, FINAL THREE crown
## warfare and a FINAL DUEL. Ring-outs are permanent.

const ROUND4_ID: StringName = &"push_out"

const ROUND4_RING_OPEN := 19.0
const ROUND4_RING_MID := 16.7
const ROUND4_RING_LATE := 13.8
const ROUND4_RING_DUEL := 10.6
const ROUND4_RING_SUDDEN_DEATH := 8.8
const ROUND4_RING_SHRINK_SPEED := 0.92
const ROUND4_EDGE_PRESSURE_RADIUS := 13.4

const RELIC_PICKUP_RADIUS := 2.15
const RELIC_DROP_IMMUNITY := 0.72
const RELIC_SCORE_INTERVAL := 1.0
const POWER_RELIC_BONUS_KNOCKBACK := 2.35
const GUARDIAN_RING_GRACE := 0.85
const AGILITY_RELIC_SPEED_SCALE := 1.18

const CROWN_PICKUP_RADIUS := 2.35
const CROWN_DROP_IMMUNITY := 0.65
const CROWN_KNOCKBACK_BONUS := 3.25
const CROWN_SPEED_SCALE := 0.86

const TITAN_SHOCKWAVE_INTERVAL := 6.0
const TITAN_SHOCKWAVE_RADIUS := 11.8
const TITAN_SHOCKWAVE_STRENGTH := 5.6

const ROUND4_AI_SEEK_RELIC := 6
const ROUND4_AI_ATTACK_RELIC_CARRIER := 7
const ROUND4_AI_FINISH_BROKEN_TARGET := 8

const CAMERA_DISTANCE := 15.4
const CAMERA_HEIGHT := 13.2
const CAMERA_SMOOTHING := 5.4
const CAMERA_OBJECTIVE_WEIGHT := 0.28

var _direct_f6_bootstrap := false
var _runtime_recovered := false
var _round4_eliminated: Dictionary = {}
var _round4_obstacles_created := false
var _round4_sudden_death_announced := false
var _round4_arena_awake_announced := false
var _round4_final_three_announced := false
var _round4_final_duel_announced := false

var _round4_current_ring_radius := ROUND4_RING_OPEN
var _round4_safe_ring: CSGTorus3D
var _round4_relics: Array[Dictionary] = []
var _round4_relic_score_elapsed := 0.0
var _round4_crown: Dictionary = {}
var _round4_shockwave_remaining := TITAN_SHOCKWAVE_INTERVAL
var _round4_dynamic_camera: Camera3D
var _round4_camera_shake_remaining := 0.0
var _round4_camera_shake_phase := 0.0
var _round4_breakable_barriers: Array[Node3D] = []
var _round4_barrier_hp: Dictionary = {}
var _round4_wall_hit_cooldown: Dictionary = {}
var _round4_local_hitstop: Dictionary = {}

func _ready() -> void:
	_prepare_round4_context()
	await super()
	_ensure_round4_runtime_active()
	_ensure_phase2_core()
	_create_round4_combat_obstacles()
	_create_round4_safe_ring()
	_create_titan_relics()
	_create_round4_dynamic_camera()
	if _combat_core != null and not _combat_core.hit_resolved.is_connected(_on_round4_hit_resolved):
		_combat_core.hit_resolved.connect(_on_round4_hit_resolved)
	if hud != null:
		hud.configure(
			"ROUND 4 — WILD RUMBLE: TITAN CROWN",
			"RELIC WAR → TITAN AWAKENING → FINAL THREE → TITAN CROWN → FINAL DUEL"
		)
	_route_round4_audio()
	print("WILD RUMBLE TITAN CROWN READY direct_f6=%s recovered=%s round_index=%d active=%s state=%d racers=%d ai=%d relics=3 elimination=true" % [
		str(_direct_f6_bootstrap),
		str(_runtime_recovered),
		GameManager.current_round_index,
		str(GameManager.round_active),
		int(GameManager.state),
		racers.size(),
		ai_racers.size(),
	])

func _physics_process(delta: float) -> void:
	super(delta)
	if mode_finished or not GameManager.round_active:
		return
	_update_round4_hitstop(delta)
	_update_round4_phase(delta)
	_update_round4_relics(delta)
	_update_round4_crown(delta)
	_update_round4_environment_contacts(delta)
	_update_round4_dynamic_camera(delta)

# Repeated 0.2s decisions must not refill EVADE/RETREAT/FLANK forever.
func _set_phase2_ai_state(racer: WildDashCharacterController, state: int, hold_seconds: float) -> void:
	if racer == null:
		return
	var id := racer.get_instance_id()
	var current := int(_phase2_ai_state.get(id, state))
	var current_timer := float(_phase2_ai_state_timer.get(id, 0.0))
	if current == state:
		if current_timer <= 0.0 and hold_seconds > 0.0:
			_phase2_ai_state_timer[id] = hold_seconds
		return
	_phase2_ai_state[id] = state
	_phase2_ai_state_timer[id] = maxf(0.0, hold_seconds)

func _round4_index() -> int:
	return GameManager.ROUND_IDS.find(ROUND4_ID)

func _prepare_round4_context() -> void:
	var round4_index := _round4_index()
	if round4_index < 0:
		push_error("WILD RUMBLE: push_out missing from GameManager.ROUND_IDS")
		return
	var valid_context := (
		GameManager.current_round_index == round4_index
		and GameManager.get_current_round_id() == ROUND4_ID
	)
	if valid_context:
		return
	if not GameManager.campaign_running or GameManager.current_round_index < 0:
		ResultManager.reset_campaign()
		GameManager.current_round_index = round4_index
		GameManager.campaign_running = true
		_direct_f6_bootstrap = true
		print("WILD RUMBLE F6 BOOTSTRAP round_index=%d mode=%s selected=%s" % [
			round4_index + 1,
			String(ROUND4_ID),
			String(GameManager.selected_animal),
		])

func _ensure_round4_runtime_active() -> void:
	var round4_index := _round4_index()
	if round4_index < 0:
		return
	if not GameManager.round_active:
		GameManager.current_round_index = round4_index
		GameManager.campaign_running = true
		GameManager.begin_round(ROUND4_ID)
		_runtime_recovered = true
	if GameManager.state != GameManager.GameState.FINAL:
		GameManager.set_state(GameManager.GameState.FINAL)
		_runtime_recovered = true
	if get_tree().paused:
		get_tree().paused = false
		_runtime_recovered = true
	for driver in ai_drivers:
		if driver != null:
			driver.set_arena_enabled(true)
	if not GameManager.round_active:
		push_error("WILD RUMBLE ROUND4 START FAILURE: round_active remained false")
	elif player == null:
		push_error("WILD RUMBLE ROUND4 START FAILURE: player missing")
	elif racers.is_empty():
		push_error("WILD RUMBLE ROUND4 START FAILURE: racer field empty")

func _create_round4_combat_obstacles() -> void:
	if _round4_obstacles_created:
		return
	_round4_obstacles_created = true

	var altar := CSGCylinder3D.new()
	altar.name = "TitanAltar"
	altar.position = Vector3(0.0, 0.12, 0.0)
	altar.radius = 2.25
	altar.height = 0.24
	altar.sides = 12
	altar.use_collision = false
	altar.material = _emissive_material(Color(0.28, 0.23, 0.20), Color(0.12, 0.07, 0.02))
	add_child(altar)

	var barrier_specs := [
		["TitanBarrierA", Vector3(6.0, 0.55, 4.6), Vector3(4.0, 1.10, 1.30), 32.0, 3],
		["TitanBarrierB", Vector3(-6.0, 0.55, -4.6), Vector3(4.0, 1.10, 1.30), 32.0, 3],
		["TitanBarrierC", Vector3(-6.7, 0.50, 5.4), Vector3(3.4, 1.00, 1.20), -28.0, 2],
		["TitanBarrierD", Vector3(6.7, 0.50, -5.4), Vector3(3.4, 1.00, 1.20), -28.0, 2],
		["TitanBarrierE", Vector3(0.0, 0.48, 9.0), Vector3(3.0, 0.96, 1.15), 0.0, 2],
		["TitanBarrierF", Vector3(0.0, 0.48, -9.0), Vector3(3.0, 0.96, 1.15), 0.0, 2],
	]
	for spec in barrier_specs:
		var barrier := create_box(spec[0], spec[1], spec[2], Color(0.37, 0.31, 0.27), true)
		barrier.rotation_degrees.y = float(spec[3])
		_round4_breakable_barriers.append(barrier)
		_round4_barrier_hp[barrier.get_instance_id()] = int(spec[4])

	for i in range(4):
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var pillar := CSGCylinder3D.new()
		pillar.name = "TitanCombatPillar%d" % (i + 1)
		pillar.position = Vector3(cos(angle) * 10.1, 0.85, sin(angle) * 10.1)
		pillar.radius = 0.92
		pillar.height = 1.70
		pillar.sides = 8
		pillar.use_collision = true
		pillar.material = _material(Color(0.31, 0.27, 0.25), 0.94)
		add_child(pillar)

	print("WILD RUMBLE OBSTACLES READY barriers=6 breakable=true pillars=4 altar=true")

func _create_round4_safe_ring() -> void:
	_round4_safe_ring = CSGTorus3D.new()
	_round4_safe_ring.name = "TitanSafeRing"
	_round4_safe_ring.position = Vector3(0.0, 0.10, 0.0)
	_round4_safe_ring.inner_radius = ROUND4_RING_OPEN - 0.28
	_round4_safe_ring.outer_radius = ROUND4_RING_OPEN + 0.04
	_round4_safe_ring.sides = 64
	_round4_safe_ring.ring_sides = 8
	_round4_safe_ring.use_collision = false
	_round4_safe_ring.material = _emissive_material(Color(0.95, 0.31, 0.08), Color(0.55, 0.07, 0.01))
	add_child(_round4_safe_ring)

func _create_titan_relics() -> void:
	if not _round4_relics.is_empty():
		return
	_create_titan_relic(&"power", "POWER RELIC", Vector3(-8.4, 0.45, -2.6), Color(1.0, 0.30, 0.07))
	_create_titan_relic(&"guardian", "GUARDIAN RELIC", Vector3(6.5, 0.45, -6.0), Color(0.10, 0.68, 1.0))
	_create_titan_relic(&"agility", "AGILITY RELIC", Vector3(4.0, 0.45, 8.1), Color(0.32, 1.0, 0.36))
	print("WILD RUMBLE TITAN RELICS READY power=true guardian=true agility=true")

func _create_titan_relic(kind: StringName, label: String, spawn_position: Vector3, color: Color) -> void:
	var shrine := CSGCylinder3D.new()
	shrine.name = "%sShrine" % label.replace(" ", "")
	shrine.position = Vector3(spawn_position.x, 0.12, spawn_position.z)
	shrine.radius = 1.55
	shrine.height = 0.24
	shrine.sides = 8
	shrine.use_collision = false
	shrine.material = _emissive_material(color.darkened(0.55), color * 0.22)
	add_child(shrine)

	var root := Node3D.new()
	root.name = label.replace(" ", "")
	root.position = spawn_position
	add_child(root)
	var orb := CSGSphere3D.new()
	orb.name = "RelicOrb"
	orb.radius = 0.52
	orb.use_collision = false
	orb.material = _emissive_material(color, color * 0.82)
	root.add_child(orb)
	var beam := CSGCylinder3D.new()
	beam.name = "RelicBeam"
	beam.position.y = 1.2
	beam.radius = 0.08
	beam.height = 2.4
	beam.sides = 8
	beam.use_collision = false
	beam.material = _emissive_material(color.lightened(0.18), color * 0.55)
	root.add_child(beam)

	_round4_relics.append({
		"kind": kind,
		"label": label,
		"node": root,
		"spawn": spawn_position,
		"carrier": null,
		"cooldown": 0.0,
		"active": true,
	})

func _create_round4_dynamic_camera() -> void:
	var old_camera := get_node_or_null("WildRumblePhase1Camera") as Camera3D
	if old_camera != null:
		old_camera.current = false
	_round4_dynamic_camera = Camera3D.new()
	_round4_dynamic_camera.name = "TitanCrownFollowCamera"
	_round4_dynamic_camera.fov = 62.0
	_round4_dynamic_camera.current = true
	add_child(_round4_dynamic_camera)
	if player != null:
		var back := player.global_transform.basis.z.normalized()
		_round4_dynamic_camera.global_position = player.global_position + back * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT

func _update_round4_phase(delta: float) -> void:
	var alive := _round4_alive_count()
	var target_radius := ROUND4_RING_OPEN
	if alive <= 2:
		target_radius = ROUND4_RING_DUEL
	elif alive <= 5:
		target_radius = ROUND4_RING_LATE
	elif alive <= 9:
		target_radius = ROUND4_RING_MID
	if time_remaining <= 0.0:
		target_radius = minf(target_radius, ROUND4_RING_SUDDEN_DEATH)
	_round4_current_ring_radius = move_toward(_round4_current_ring_radius, target_radius, ROUND4_RING_SHRINK_SPEED * delta)
	if _round4_safe_ring != null:
		_round4_safe_ring.inner_radius = maxf(2.0, _round4_current_ring_radius - 0.28)
		_round4_safe_ring.outer_radius = _round4_current_ring_radius + 0.04

	if alive <= 10 and not _round4_arena_awake_announced:
		_round4_arena_awake_announced = true
		_round4_shockwave_remaining = 1.6
		if hud != null:
			hud.set_message("TITAN ARENA AWAKENS! · WALLS BREAK · SHOCKWAVES ACTIVE")
		print("WILD RUMBLE TITAN ARENA AWAKENS alive=%d" % alive)

	if _round4_arena_awake_announced and alive > 3:
		_round4_shockwave_remaining -= delta
		if _round4_shockwave_remaining <= 0.0:
			_round4_shockwave_remaining = TITAN_SHOCKWAVE_INTERVAL
			_emit_titan_shockwave()

	if alive <= 3 and not _round4_final_three_announced:
		_round4_final_three_announced = true
		_deactivate_titan_relics()
		_spawn_titan_crown()
		if hud != null:
			hud.set_message("FINAL THREE · TITAN CROWN AWAKENS!")
		print("WILD RUMBLE FINAL THREE crown=true")

	if alive <= 2 and not _round4_final_duel_announced:
		_round4_final_duel_announced = true
		if hud != null:
			hud.set_message("FINAL DUEL · LAST ANIMAL WINS!")
		print("WILD RUMBLE FINAL DUEL radius=%.1f" % ROUND4_RING_DUEL)

func _emit_titan_shockwave() -> void:
	_spawn_impact_ring(Vector3.ZERO, 2.4, Color(1.0, 0.48, 0.10))
	for racer in racers:
		if not _is_combatant_active(racer):
			continue
		var planar := racer.global_position
		planar.y = 0.0
		var distance := planar.length()
		if distance <= 0.2 or distance > TITAN_SHOCKWAVE_RADIUS:
			continue
		var strength := TITAN_SHOCKWAVE_STRENGTH * lerpf(1.0, 0.38, distance / TITAN_SHOCKWAVE_RADIUS)
		racer.apply_knockback(planar.normalized(), strength)
	if hud != null:
		hud.set_message("TITAN SHOCKWAVE!")

func _update_round4_relics(delta: float) -> void:
	if _round4_final_three_announced:
		return
	_round4_relic_score_elapsed += delta
	var award_score := false
	if _round4_relic_score_elapsed >= RELIC_SCORE_INTERVAL:
		_round4_relic_score_elapsed = fmod(_round4_relic_score_elapsed, RELIC_SCORE_INTERVAL)
		award_score = true

	for relic in _round4_relics:
		if not bool(relic.get("active", false)):
			continue
		relic["cooldown"] = maxf(0.0, float(relic.get("cooldown", 0.0)) - delta)
		var node := relic.get("node") as Node3D
		var carrier := relic.get("carrier") as WildDashCharacterController
		if carrier != null and is_instance_valid(carrier) and _is_combatant_active(carrier):
			if node != null:
				node.global_position = carrier.global_position + Vector3.UP * 2.45
			if award_score:
				var id := carrier.get_instance_id()
				_scores[id] = int(_scores.get(id, 0)) + 1
			continue
		if carrier != null:
			relic["carrier"] = null
		if node == null or float(relic.get("cooldown", 0.0)) > 0.0:
			continue
		for racer in racers:
			if not _is_combatant_active(racer) or _racer_has_relic(racer):
				continue
			if racer.global_position.distance_to(node.global_position) <= RELIC_PICKUP_RADIUS:
				_pickup_titan_relic(relic, racer)
				break

func _pickup_titan_relic(relic: Dictionary, racer: WildDashCharacterController) -> void:
	if racer == null or _racer_has_relic(racer):
		return
	relic["carrier"] = racer
	relic["cooldown"] = 0.0
	var label := String(relic.get("label", "TITAN RELIC"))
	if hud != null and racer == player:
		hud.set_message("%s CLAIMED · YOU ARE A TARGET" % label)
	print("WILD RUMBLE RELIC CLAIM kind=%s carrier=%s" % [String(relic.get("kind", &"")), racer.get_display_name()])

func _drop_relic_for(racer: WildDashCharacterController, reason: String) -> void:
	if racer == null:
		return
	for relic in _round4_relics:
		if relic.get("carrier") != racer:
			continue
		relic["carrier"] = null
		relic["cooldown"] = RELIC_DROP_IMMUNITY
		var node := relic.get("node") as Node3D
		if node != null:
			node.visible = not _round4_final_three_announced
			var safe := _phase2_safe_move_point(racer.global_position)
			node.global_position = Vector3(safe.x, 0.55, safe.z)
		if hud != null and racer == player:
			hud.set_message("RELIC DROPPED · %s" % reason)
		print("WILD RUMBLE RELIC DROP kind=%s carrier=%s reason=%s" % [String(relic.get("kind", &"")), racer.get_display_name(), reason])

func _deactivate_titan_relics() -> void:
	for relic in _round4_relics:
		relic["active"] = false
		relic["carrier"] = null
		var node := relic.get("node") as Node3D
		if node != null:
			node.visible = false

func _spawn_titan_crown() -> void:
	if not _round4_crown.is_empty():
		return
	var root := Node3D.new()
	root.name = "TitanCrown"
	root.position = Vector3(0.0, 2.0, 0.0)
	add_child(root)
	var ring := CSGTorus3D.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.68
	ring.sides = 24
	ring.ring_sides = 8
	ring.use_collision = false
	ring.material = _emissive_material(Color(1.0, 0.72, 0.08), Color(1.0, 0.42, 0.02))
	root.add_child(ring)
	for i in range(4):
		var prong := CSGBox3D.new()
		prong.size = Vector3(0.16, 0.68, 0.16)
		prong.position = Vector3(cos(TAU * float(i) / 4.0) * 0.52, 0.34, sin(TAU * float(i) / 4.0) * 0.52)
		prong.use_collision = false
		prong.material = ring.material
		root.add_child(prong)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.64, 0.10)
	light.light_energy = 2.0
	light.omni_range = 7.0
	root.add_child(light)
	_round4_crown = {
		"node": root,
		"carrier": null,
		"cooldown": 0.55,
		"active": true,
	}

func _update_round4_crown(delta: float) -> void:
	if _round4_crown.is_empty() or not bool(_round4_crown.get("active", false)):
		return
	_round4_crown["cooldown"] = maxf(0.0, float(_round4_crown.get("cooldown", 0.0)) - delta)
	var node := _round4_crown.get("node") as Node3D
	var carrier := _round4_crown.get("carrier") as WildDashCharacterController
	if carrier != null and is_instance_valid(carrier) and _is_combatant_active(carrier):
		if node != null:
			node.global_position = carrier.global_position + Vector3.UP * 2.85
		return
	if carrier != null:
		_round4_crown["carrier"] = null
	if node == null or float(_round4_crown.get("cooldown", 0.0)) > 0.0:
		return
	for racer in racers:
		if not _is_combatant_active(racer):
			continue
		if racer.global_position.distance_to(node.global_position) <= CROWN_PICKUP_RADIUS:
			_round4_crown["carrier"] = racer
			if hud != null:
				hud.set_message("%s CLAIMS THE TITAN CROWN!" % ("YOU" if racer == player else racer.get_display_name().to_upper()))
			print("WILD RUMBLE CROWN CLAIM carrier=%s" % racer.get_display_name())
			break

func _drop_crown_for(racer: WildDashCharacterController, reason: String) -> void:
	if _round4_crown.is_empty() or _round4_crown.get("carrier") != racer:
		return
	_round4_crown["carrier"] = null
	_round4_crown["cooldown"] = CROWN_DROP_IMMUNITY
	var node := _round4_crown.get("node") as Node3D
	if node != null:
		node.global_position = Vector3(0.0, 2.0, 0.0)
	if hud != null and racer == player:
		hud.set_message("TITAN CROWN DROPPED · %s" % reason)
	print("WILD RUMBLE CROWN DROP carrier=%s reason=%s" % [racer.get_display_name(), reason])

func _record_phase2_hit_credit(source: WildDashCharacterController, target: WildDashCharacterController) -> void:
	if source == null or target == null:
		return
	var target_id := target.get_instance_id()
	_last_attacker[target_id] = source
	_last_hit_age[target_id] = 0.0
	var direction := target.global_position - source.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	var source_power := WildDashRaceCombatProfile.get_attack_power(source.animal_id)
	var target_defense := WildDashRaceCombatProfile.get_defense(target.animal_id)
	var source_role := _phase2_role(source.animal_id)
	var target_role := _phase2_role(target.animal_id)
	var bonus := maxf(0.0, source_power - target_defense) * 0.70
	if source_role == &"heavy":
		bonus += 2.90
	elif source_role == &"mid":
		bonus += 0.95
	elif source_role == &"duelist":
		bonus += 0.62
	if target_role == &"light":
		bonus += 1.30
	if _relic_kind_for(source) == &"power":
		bonus += POWER_RELIC_BONUS_KNOCKBACK
	if _racer_has_crown(source):
		bonus += CROWN_KNOCKBACK_BONUS
	if _relic_kind_for(target) == &"guardian":
		bonus *= 0.56
	var target_radius := Vector2(target.global_position.x, target.global_position.z).length()
	var edge_start := minf(ROUND4_EDGE_PRESSURE_RADIUS, _round4_current_ring_radius - 2.8)
	if target_radius >= edge_start:
		bonus += lerpf(1.0, 3.8, clampf((target_radius - edge_start) / 4.5, 0.0, 1.0))
	if bonus > 0.10:
		target.apply_knockback(direction.normalized(), bonus)

func _on_round4_hit_resolved(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	result: Dictionary,
) -> void:
	if source == null or target == null or not bool(result.get("applied", false)):
		return
	var kind := StringName(result.get("kind", &"tap"))
	var broke := bool(result.get("break", false))
	var hitstop := 0.08 if broke else (0.06 if kind == &"hold" else 0.0)
	if hitstop > 0.0:
		_round4_local_hitstop[source.get_instance_id()] = maxf(hitstop, float(_round4_local_hitstop.get(source.get_instance_id(), 0.0)))
		_round4_local_hitstop[target.get_instance_id()] = maxf(hitstop, float(_round4_local_hitstop.get(target.get_instance_id(), 0.0)))
		_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.13 if broke else 0.09)
		_spawn_impact_flash(target.global_position + Vector3.UP * 0.75, kind == &"hold" or broke)
		_spawn_impact_ring(target.global_position, 0.65 if kind == &"hold" else 0.42, Color(0.92, 0.53, 0.23))
		_damage_barrier_near(target.global_position, 2 if broke else 1)
	if broke:
		var direction := target.global_position - source.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			target.apply_knockback(direction.normalized(), 4.4)
		_drop_relic_for(target, "BREAK")
		_drop_crown_for(target, "BREAK")
	elif kind == &"hold" and float(result.get("knockback", 0.0)) >= 13.5:
		_drop_relic_for(target, "HEAVY SMASH")
		_drop_crown_for(target, "HEAVY SMASH")

func _spawn_impact_flash(position: Vector3, heavy: bool) -> void:
	var flash := CSGSphere3D.new()
	flash.name = "TitanImpactFlash"
	flash.global_position = position
	flash.radius = 0.34 if heavy else 0.22
	flash.use_collision = false
	flash.material = _emissive_material(Color(1.0, 0.86, 0.55), Color(1.0, 0.38, 0.05))
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * (2.8 if heavy else 2.0), 0.10)
	tween.tween_callback(Callable(flash, "queue_free"))

func _spawn_impact_ring(position: Vector3, radius: float, color: Color) -> void:
	var ring := CSGTorus3D.new()
	ring.name = "TitanDustRing"
	ring.global_position = Vector3(position.x, 0.14, position.z)
	ring.inner_radius = maxf(0.12, radius - 0.12)
	ring.outer_radius = radius
	ring.sides = 24
	ring.ring_sides = 6
	ring.use_collision = false
	ring.material = _emissive_material(color.darkened(0.35), color * 0.32)
	add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.3, 0.18)
	tween.tween_callback(Callable(ring, "queue_free"))

func _damage_barrier_near(position: Vector3, damage: int) -> void:
	var nearest: Node3D
	var nearest_distance := 2.65 * 2.65
	for barrier in _round4_breakable_barriers:
		if barrier == null or not is_instance_valid(barrier) or not barrier.visible:
			continue
		var distance := barrier.global_position.distance_squared_to(position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = barrier
	if nearest == null:
		return
	var id := nearest.get_instance_id()
	var hp := int(_round4_barrier_hp.get(id, 1)) - damage
	_round4_barrier_hp[id] = hp
	if hp > 0:
		return
	if nearest is CSGShape3D:
		(nearest as CSGShape3D).use_collision = false
	nearest.visible = false
	_spawn_impact_ring(nearest.global_position, 1.25, Color(0.55, 0.42, 0.30))
	print("WILD RUMBLE BARRIER BREAK name=%s" % nearest.name)

func _update_round4_environment_contacts(delta: float) -> void:
	if _combat_core == null:
		return
	for racer in racers:
		if racer == null:
			continue
		var id := racer.get_instance_id()
		_round4_wall_hit_cooldown[id] = maxf(0.0, float(_round4_wall_hit_cooldown.get(id, 0.0)) - delta)
		if not _is_combatant_active(racer) or float(_round4_wall_hit_cooldown[id]) > 0.0:
			continue
		if not racer.has_blocking_collision() or racer.current_speed < 3.8:
			continue
		var gain := clampf(racer.current_speed * 1.45, 6.0, 16.0)
		var stagger := _combat_core.add_environment_stagger(racer, gain)
		_round4_wall_hit_cooldown[id] = 0.72
		var ai_index := ai_racers.find(racer)
		if ai_index >= 0:
			_phase2_ai_strafe_sign[id] = -float(_phase2_ai_strafe_sign.get(id, 1.0))
			_set_phase2_ai_state(racer, Phase2AIState.FLANK, 0.55)
		if racer == player and hud != null:
			hud.set_message("WALL IMPACT · STAGGER %.0f/100" % stagger)

func _update_round4_hitstop(delta: float) -> void:
	var expired: Array[int] = []
	for raw_id in _round4_local_hitstop.keys():
		var id := int(raw_id)
		var remaining := maxf(0.0, float(_round4_local_hitstop.get(id, 0.0)) - delta)
		_round4_local_hitstop[id] = remaining
		if remaining <= 0.0:
			expired.append(id)
	for id in expired:
		_round4_local_hitstop.erase(id)

func _apply_break_control_locks() -> void:
	super()
	if not _phase2_initialized:
		return
	for racer in racers:
		if racer == null:
			continue
		var id := racer.get_instance_id()
		if not _is_combatant_active(racer):
			continue
		var base_speed := float(_base_arena_move_speeds.get(id, racer.arena_move_speed))
		var multiplier := _round4_objective_speed_multiplier(racer)
		if _combat_core.get_stun_remaining(racer) > 0.0 or float(_round4_local_hitstop.get(id, 0.0)) > 0.0:
			racer.arena_move_speed = 0.0
		else:
			racer.arena_move_speed = base_speed * multiplier
	for i in range(ai_racers.size()):
		if i >= ai_drivers.size():
			break
		var racer := ai_racers[i]
		if racer == null:
			continue
		var id := racer.get_instance_id()
		var base_target := float(_base_ai_target_speeds.get(id, ai_drivers[i].target_speed))
		if not _is_combatant_active(racer) or _combat_core.get_stun_remaining(racer) > 0.0 or float(_round4_local_hitstop.get(id, 0.0)) > 0.0:
			ai_drivers[i].target_speed = 0.0
		else:
			ai_drivers[i].target_speed = base_target * _phase2_state_speed_scale(racer) * _round4_objective_speed_multiplier(racer)

func _round4_objective_speed_multiplier(racer: WildDashCharacterController) -> float:
	var multiplier := 1.0
	if _relic_kind_for(racer) == &"agility":
		multiplier *= AGILITY_RELIC_SPEED_SCALE
	if _racer_has_crown(racer):
		multiplier *= CROWN_SPEED_SCALE
	return multiplier

func _phase2_target_for(ai_index: int, racer: WildDashCharacterController) -> WildDashCharacterController:
	if racer == null:
		return null
	if _round4_final_three_announced:
		var crown_carrier := _round4_crown.get("carrier") as WildDashCharacterController
		if crown_carrier != null and crown_carrier != racer and is_instance_valid(crown_carrier) and _is_combatant_active(crown_carrier):
			return crown_carrier
	else:
		var relic_carrier := _nearest_relic_carrier_for(racer)
		if relic_carrier != null:
			var role := _phase2_role(racer.animal_id)
			if role == &"heavy" or role == &"duelist" or racer.global_position.distance_to(relic_carrier.global_position) <= 6.5:
				return relic_carrier
	return super(ai_index, racer)

func _phase2_choose_state(ai_index: int, racer: WildDashCharacterController, target: WildDashCharacterController) -> int:
	if racer == null or target == null:
		return Phase2AIState.CHASE
	if _combat_core != null and _combat_core.get_break_vulnerability_remaining(target) > 0.0:
		return ROUND4_AI_FINISH_BROKEN_TARGET
	if _round4_final_three_announced:
		var crown_carrier := _round4_crown.get("carrier") as WildDashCharacterController
		if crown_carrier == null:
			return ROUND4_AI_SEEK_RELIC
		if crown_carrier != racer and target == crown_carrier:
			return ROUND4_AI_ATTACK_RELIC_CARRIER
	else:
		if not _racer_has_relic(racer) and _nearest_unclaimed_objective_node(racer) != null:
			var seek_phase := int(maxf(0.0, time_remaining) / 3.0)
			if (ai_index + seek_phase) % 3 == 0:
				return ROUND4_AI_SEEK_RELIC
		if _racer_has_relic(target):
			return ROUND4_AI_ATTACK_RELIC_CARRIER
	return super(ai_index, racer, target)

func _phase2_state_target_point(racer: WildDashCharacterController, target: WildDashCharacterController, state: int) -> Vector3:
	if state == ROUND4_AI_SEEK_RELIC:
		var objective := _nearest_unclaimed_objective_node(racer)
		if objective != null:
			return _phase2_safe_move_point(objective.global_position)
	if state == ROUND4_AI_ATTACK_RELIC_CARRIER or state == ROUND4_AI_FINISH_BROKEN_TARGET:
		var offset := target.global_position - racer.global_position
		offset.y = 0.0
		if offset.length_squared() > 0.001:
			return _phase2_safe_move_point(target.global_position - offset.normalized() * 0.75)
	return super(racer, target, state)

func _phase2_default_state_hold(state: int) -> float:
	if state == ROUND4_AI_SEEK_RELIC:
		return 0.42
	if state == ROUND4_AI_ATTACK_RELIC_CARRIER:
		return 0.36
	if state == ROUND4_AI_FINISH_BROKEN_TARGET:
		return 0.32
	return super(state)

func _phase2_state_speed_scale(racer: WildDashCharacterController) -> float:
	var state := int(_phase2_ai_state.get(racer.get_instance_id(), Phase2AIState.CHASE)) if racer != null else Phase2AIState.CHASE
	if state == ROUND4_AI_SEEK_RELIC:
		return 1.15
	if state == ROUND4_AI_ATTACK_RELIC_CARRIER:
		return 1.12
	if state == ROUND4_AI_FINISH_BROKEN_TARGET:
		return 1.20
	return super(racer)

func _phase2_safe_move_point(point: Vector3) -> Vector3:
	var safe_radius := maxf(6.8, _round4_current_ring_radius - 1.25)
	var planar := Vector2(point.x, point.z)
	if planar.length() > safe_radius:
		planar = planar.normalized() * safe_radius
	return Vector3(planar.x, 0.20, planar.y)

func _nearest_relic_carrier_for(racer: WildDashCharacterController) -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_distance := INF
	for relic in _round4_relics:
		if not bool(relic.get("active", false)):
			continue
		var carrier := relic.get("carrier") as WildDashCharacterController
		if carrier == null or carrier == racer or not is_instance_valid(carrier) or not _is_combatant_active(carrier):
			continue
		var distance := racer.global_position.distance_squared_to(carrier.global_position)
		if distance < best_distance:
			best_distance = distance
			best = carrier
	return best

func _nearest_unclaimed_objective_node(racer: WildDashCharacterController) -> Node3D:
	if racer == null:
		return null
	if _round4_final_three_announced and not _round4_crown.is_empty() and _round4_crown.get("carrier") == null:
		return _round4_crown.get("node") as Node3D
	var best: Node3D
	var best_distance := INF
	for relic in _round4_relics:
		if not bool(relic.get("active", false)) or relic.get("carrier") != null or float(relic.get("cooldown", 0.0)) > 0.0:
			continue
		var node := relic.get("node") as Node3D
		if node == null:
			continue
		var distance := racer.global_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

func _racer_has_relic(racer: WildDashCharacterController) -> bool:
	return _relic_kind_for(racer) != &""

func _relic_kind_for(racer: WildDashCharacterController) -> StringName:
	if racer == null:
		return &""
	for relic in _round4_relics:
		if relic.get("carrier") == racer and bool(relic.get("active", false)):
			return StringName(relic.get("kind", &""))
	return &""

func _racer_has_crown(racer: WildDashCharacterController) -> bool:
	return racer != null and not _round4_crown.is_empty() and _round4_crown.get("carrier") == racer

func _check_ring_outs() -> void:
	for racer in racers:
		if not _is_combatant_active(racer):
			continue
		var grace := GUARDIAN_RING_GRACE if _relic_kind_for(racer) == &"guardian" else 0.0
		var planar_radius := Vector2(racer.global_position.x, racer.global_position.z).length()
		if planar_radius > _round4_current_ring_radius + grace or racer.global_position.y < -2.6:
			_ring_out(racer)

func _ring_out(victim: WildDashCharacterController) -> void:
	if victim == null or mode_finished or not _is_combatant_active(victim):
		return
	var victim_id := victim.get_instance_id()
	var attacker := _last_attacker.get(victim_id, null) as WildDashCharacterController
	var credited := attacker != null and is_instance_valid(attacker) and attacker != victim
	credited = credited and float(_last_hit_age.get(victim_id, ATTACK_CREDIT_WINDOW + 1.0)) <= ATTACK_CREDIT_WINDOW
	if credited:
		var attacker_id := attacker.get_instance_id()
		_scores[attacker_id] = int(_scores.get(attacker_id, 0)) + RING_OUT_SCORE
		_ko_counts[attacker_id] = int(_ko_counts.get(attacker_id, 0)) + 1
	_drop_relic_for(victim, "RING OUT")
	_drop_crown_for(victim, "RING OUT")
	_round4_eliminated[victim_id] = true
	_last_attacker.erase(victim_id)
	_last_hit_age[victim_id] = ATTACK_CREDIT_WINDOW + 1.0
	_set_combatant_active(victim, false)
	_spawn_impact_ring(victim.global_position, 1.4, Color(1.0, 0.22, 0.06))
	_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.18)

	var alive := _round4_alive_count()
	if victim == player:
		if hud != null:
			hud.set_message("ELIMINATED! · %d ANIMALS LEFT" % alive)
		finish_mode(false, _score_for(player), {
			"dominance": _score_for(player),
			"kos": _kos_for(player),
			"alive": alive,
			"eliminated": true,
			"titan_crown_finale": true,
		})
		return
	if hud != null:
		if credited and attacker == player:
			hud.set_message("RING OUT! +%d · %d LEFT" % [RING_OUT_SCORE, alive])
		else:
			hud.set_message("%s ELIMINATED · %d LEFT" % [victim.get_display_name().to_upper(), alive])
	print("WILD RUMBLE ELIMINATION victim=%s attacker=%s alive=%d permanent=true" % [
		victim.get_display_name(),
		attacker.get_display_name() if credited else "none",
		alive,
	])
	if alive <= 1:
		_finish_last_survivor()

func _is_combatant_active(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	var id := racer.get_instance_id()
	if _round4_eliminated.has(id):
		return false
	return not _respawn_remaining.has(id)

func _round4_alive_count() -> int:
	var count := 0
	for racer in racers:
		if _is_combatant_active(racer):
			count += 1
	return count

func _finish_last_survivor() -> void:
	if mode_finished or player == null:
		return
	var player_alive := _is_combatant_active(player)
	var survivor_name := "NONE"
	for racer in racers:
		if _is_combatant_active(racer):
			survivor_name = racer.get_display_name()
			break
	if hud != null:
		hud.set_message("TITAN CHAMPION · %s" % survivor_name.to_upper())
	print("WILD RUMBLE TITAN CHAMPION winner=%s player_alive=%s score=%d kos=%d" % [
		survivor_name, str(player_alive), _score_for(player), _kos_for(player),
	])
	finish_mode(player_alive, _score_for(player) + (15 if player_alive else 0), {
		"dominance": _score_for(player),
		"kos": _kos_for(player),
		"alive": _round4_alive_count(),
		"winner": survivor_name,
		"titan_crown_finale": true,
		"elimination": true,
	})

func _update_hud() -> void:
	_ensure_phase2_core()
	if player == null or hud == null or not _phase2_initialized:
		return
	var profile := _combat_core.get_profile(player)
	var stagger := _combat_core.get_stagger(player)
	var attack_cd := _combat_core.get_attack_cooldown_remaining(player)
	var stun := _combat_core.get_stun_remaining(player)
	var objective := "NONE"
	var relic_kind := _relic_kind_for(player)
	if relic_kind != &"":
		objective = String(relic_kind).to_upper()
	if _racer_has_crown(player):
		objective = "TITAN CROWN"
	hud.set_metrics("TIME %.0f   ALIVE %d/%d   DOM %d   KOs %d   OBJ %s   STAGGER %.0f/100   PWR %.1f DEF %.1f%s" % [
		time_remaining,
		_round4_alive_count(),
		racers.size(),
		_score_for(player),
		_kos_for(player),
		objective,
		stagger,
		float(profile.get("attack_power", 0.0)),
		float(profile.get("defense", 0.0)),
		"   BREAK %.1fs" % stun if stun > 0.0 else ("   ATK CD %.1f" % attack_cd if attack_cd > 0.05 else "   READY"),
	])

func _finish_score_battle() -> void:
	if mode_finished or player == null:
		return
	var alive := _round4_alive_count()
	if alive <= 1:
		_finish_last_survivor()
		return
	if not _round4_sudden_death_announced:
		_round4_sudden_death_announced = true
		if hud != null:
			hud.set_message("SUDDEN DEATH · ARENA COLLAPSING!")
		print("WILD RUMBLE SUDDEN DEATH alive=%d target_radius=%.2f" % [alive, ROUND4_RING_SUDDEN_DEATH])

func _update_round4_dynamic_camera(delta: float) -> void:
	if _round4_dynamic_camera == null or player == null or not is_instance_valid(player):
		return
	var forward_back := player.global_transform.basis.z.normalized()
	var desired_position := player.global_position + forward_back * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
	var smoothing := clampf(CAMERA_SMOOTHING * delta, 0.0, 1.0)
	_round4_dynamic_camera.global_position = _round4_dynamic_camera.global_position.lerp(desired_position, smoothing)

	var focus := player.global_position + Vector3.UP * 1.1
	var objective_position := _round4_relevant_objective_position()
	if objective_position != Vector3.ZERO:
		focus = focus.lerp(objective_position + Vector3.UP * 0.8, CAMERA_OBJECTIVE_WEIGHT)
	if _round4_camera_shake_remaining > 0.0:
		_round4_camera_shake_remaining = maxf(0.0, _round4_camera_shake_remaining - delta)
		_round4_camera_shake_phase += delta * 52.0
		var shake := Vector3(sin(_round4_camera_shake_phase), cos(_round4_camera_shake_phase * 1.31), 0.0) * 0.16
		_round4_dynamic_camera.global_position += shake * clampf(_round4_camera_shake_remaining / 0.18, 0.0, 1.0)
	_round4_dynamic_camera.look_at(focus, Vector3.UP)

func _round4_relevant_objective_position() -> Vector3:
	if not _round4_crown.is_empty():
		var crown_carrier := _round4_crown.get("carrier") as WildDashCharacterController
		if crown_carrier != null and is_instance_valid(crown_carrier):
			return crown_carrier.global_position
		var crown_node := _round4_crown.get("node") as Node3D
		if crown_node != null:
			return crown_node.global_position
	if player != null:
		var relic_node := _nearest_unclaimed_objective_node(player)
		if relic_node != null:
			return relic_node.global_position
	return Vector3.ZERO

func _route_round4_audio() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	audio.call("play_theme", "arena_push_out")
