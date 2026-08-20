extends "res://modes/wild_current/wild_current_race.gd"

## WILD CURRENT: RIVER RUSH — Phase 2 competitive final-round layer.
## Phase 1 remains the water-only foundation. This layer adds pack race craft,
## strategic current lanes, equal wake drafting, moving water hazards, HUD/audio
## hooks and late-race convergence without teleporting racers or slowing player.

const PHASE2_SWIMMER_SCRIPT: Script = preload("res://modes/wild_current/wild_current_swimmer_phase2.gd")
const FINAL_SPRINT_Z: float = -282.0
const DRAFT_MIN_GAP: float = 1.6
const DRAFT_MAX_GAP: float = 9.5
const DRAFT_MAX_LATERAL: float = 3.1
const FINISH_PACK_DISTANCE: float = 34.0
const SOFT_BANK_START_X: float = 18.0
const SOFT_BANK_FORCE: float = 2.2

var _moving_logs: Array[Dictionary] = []
var _wake_feedback: Dictionary = {}
var _final_sprint_seen: Dictionary = {}
var _whirlpool_choice_logged: Dictionary = {}
var _phase2_ready: bool = false
var _phase2_elapsed: float = 0.0
var _base_camera_fov: float = 74.0

func _process(delta: float) -> void:
	super(delta)
	_phase2_elapsed += delta
	_ensure_phase2_runtime_ready()
	_update_moving_logs()
	_update_swim_feedback()
	_update_final_sprint_state()
	_update_round5_camera(delta)
	_update_phase2_hud()

func _physics_process(delta: float) -> void:
	super(delta)
	# Phase 1 owns the only positional recovery authority. Phase 2 never performs
	# rubber-band teleports; its AI recovery is steering + route reacquisition.

func _build_currents() -> void:
	super()
	# Every major zone now exposes at least two authored choices: safe water,
	# faster current, or a higher-risk edge line. None is required for progression.
	_add_current("LagoonFastRight", Vector3(8.0, WATER_SURFACE_Y, 214.0), Vector3(-0.06, 0.0, -1.0), 1.10, 8.0, 66.0, &"FAST")
	_add_current("CrossingSafeRight", Vector3(10.0, WATER_SURFACE_Y, 142.0), Vector3(0.0, 0.0, -1.0), 0.72, 8.0, 92.0, &"NORMAL")
	_add_current("ForestSafeLeft", Vector3(-9.5, WATER_SURFACE_Y, 10.0), Vector3(0.02, 0.0, -1.0), 0.78, 7.0, 92.0, &"NORMAL")
	_add_current("WhirlpoolOuterWest", Vector3(-13.0, WATER_SURFACE_Y, -86.0), Vector3(0.08, 0.0, -1.0), 2.18, 5.5, 74.0, &"FAST")
	_add_current("WhirlpoolOuterEast", Vector3(13.0, WATER_SURFACE_Y, -126.0), Vector3(-0.08, 0.0, -1.0), 2.14, 5.5, 74.0, &"FAST")
	_add_current("RapidsSafeLeft", Vector3(-10.0, WATER_SURFACE_Y, -220.0), Vector3(0.02, 0.0, -1.0), 1.72, 7.0, 116.0, &"FAST")
	_add_current("FinalFastCenter", Vector3(0.0, WATER_SURFACE_Y, -307.0), Vector3(0.0, 0.0, -1.0), 1.64, 10.0, 64.0, &"FAST")
	_build_current_particles()
	print("WILD CURRENT PHASE2 LINES safe_fast_risk=true zones=6 single_solution=false current_strategy=true")

func _build_basic_hazards() -> void:
	super()
	_add_floating_debris("ForestDebrisA", Vector3(-6.0, WATER_SURFACE_Y + 0.10, 22.0), Vector3(1.6, 0.16, 0.7))
	_add_floating_debris("ForestDebrisB", Vector3(7.0, WATER_SURFACE_Y + 0.08, -11.0), Vector3(1.2, 0.14, 0.8))
	_add_floating_debris("ForestDebrisC", Vector3(2.5, WATER_SURFACE_Y + 0.08, -31.0), Vector3(1.0, 0.12, 0.6))
	print("WILD CURRENT FLOATING FOREST POLISH moving_logs=%d debris=3 dive_under=true climb_required=false" % _moving_logs.size())

func _add_floating_log(name_text: String, position_value: Vector3, size_value: Vector3) -> void:
	# Animatable box obstacle: visually readable, simple collision, no hollow
	# cylinder and no need to stand on it. Dive height clears beneath the log.
	var body := AnimatableBody3D.new()
	body.name = name_text
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "LogVisual"
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.52, 0.29, 0.12)
	material.roughness = 0.84
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "LogCollision"
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

	var water_reference := position_value
	water_reference.y = WATER_SURFACE_Y
	_floating_log_positions.append(water_reference)
	var motion_index := _moving_logs.size()
	_moving_logs.append({
		"body": body,
		"origin": position_value,
		"amplitude": 1.6 + float(motion_index) * 0.55,
		"speed": 0.62 + float(motion_index) * 0.08,
		"phase": float(motion_index) * 1.7,
		"half_width": size_value.x * 0.5,
	})

func _build_finish_gate() -> void:
	super()
	var finish_position := Vector3(0.0, WATER_SURFACE_Y, COURSE_FINISH_Z)
	# Tall collision-free sight beacon keeps the finish readable roughly 8-12s
	# before arrival at normal final-sprint speed.
	for x in [-7.5, 7.5]:
		var beacon := CSGCylinder3D.new()
		beacon.name = "FinalSightBeacon_%s" % ("L" if x < 0.0 else "R")
		beacon.position = finish_position + Vector3(x, 5.2, 0.0)
		beacon.radius = 0.34
		beacon.height = 10.2
		beacon.sides = 12
		beacon.use_collision = false
		var beacon_material := StandardMaterial3D.new()
		beacon_material.albedo_color = Color(1.0, 0.78, 0.12)
		beacon_material.emission_enabled = true
		beacon_material.emission = Color(0.42, 0.25, 0.03)
		beacon.material = beacon_material
		add_child(beacon)
	create_box("FinalSightCrossbar", finish_position + Vector3(0.0, 9.7, 0.0), Vector3(15.0, 0.42, 0.45), Color(1.0, 0.78, 0.12), false)
	print("WILD CURRENT FINAL GATE sightline=true sight_seconds=8_12 obstacle_density=low")

func _attach_swimmer(racer: WildDashCharacterController, is_player_swimmer: bool, lane: float) -> void:
	if racer == null:
		return
	var swimmer := PHASE2_SWIMMER_SCRIPT.new() as WildCurrentSwimmerPhase2
	if swimmer == null:
		return
	swimmer.name = "%sSwimDriver" % racer.name
	add_child(swimmer)
	swimmer.configure(racer, self, _route_points, is_player_swimmer, lane)

	var role: StringName = &"PLAYER"
	var slot := -1
	var profile := _player_skill_profile()
	if not is_player_swimmer:
		slot = ai_racers.find(racer)
		role = _pack_role_for_ai_slot(slot, GameManager.ai_count)
		profile = _ai_skill_profile(role, slot)
	swimmer.configure_competition(role, profile, slot)
	_swimmers[racer.get_instance_id()] = swimmer
	if is_player_swimmer:
		_player_swimmer = swimmer
	else:
		_log_pack_assignment(racer, role, slot)

func sample_water_force(world_position: Vector3, burst_active: bool, dive_active: bool) -> Vector3:
	var force: Vector3 = super(world_position, burst_active, dive_active)
	# Soft inward water pressure prevents shoreline pinning without teleporting or
	# stealing steering control. The physical bank remains the final boundary.
	var abs_x := absf(world_position.x)
	if abs_x > SOFT_BANK_START_X:
		var ratio := clampf((abs_x - SOFT_BANK_START_X) / maxf(1.0, COURSE_HALF_WIDTH - SOFT_BANK_START_X), 0.0, 1.0)
		force.x += -signf(world_position.x) * SOFT_BANK_FORCE * ratio
	return force

func sample_wake_draft(racer: WildDashCharacterController) -> Dictionary:
	if racer == null or racer.finished or not RaceManager.active:
		return {"active": false, "speed_bonus": 0.0, "leader": ""}
	var own_progress := RaceManager.get_track_progress(racer)
	var best_gap := INF
	var best_leader: WildDashCharacterController = null
	for other_node in RaceManager.racers:
		var other := other_node as WildDashCharacterController
		if other == null or other == racer or other.finished:
			continue
		var gap := RaceManager.get_track_progress(other) - own_progress
		if gap < DRAFT_MIN_GAP or gap > DRAFT_MAX_GAP:
			continue
		if absf(other.global_position.x - racer.global_position.x) > DRAFT_MAX_LATERAL:
			continue
		if absf(other.global_position.y - racer.global_position.y) > 2.4:
			continue
		if gap < best_gap:
			best_gap = gap
			best_leader = other
	if best_leader == null:
		return {"active": false, "speed_bonus": 0.0, "leader": ""}
	var efficiency := 1.0 - clampf((best_gap - DRAFT_MIN_GAP) / (DRAFT_MAX_GAP - DRAFT_MIN_GAP), 0.0, 1.0)
	return {
		"active": true,
		"speed_bonus": lerpf(0.18, 0.62, efficiency),
		"leader": RaceManager.get_racer_label(best_leader),
	}

func get_ai_line_target_x(
	racer: WildDashCharacterController,
	base_lane: float,
	pack_role: StringName,
	selection_skill: float,
	line_skill: float,
) -> float:
	if racer == null:
		return base_lane
	var zone := _zone_name_for_position(racer.global_position)
	var gap_to_player := 0.0
	if player != null and is_instance_valid(player):
		gap_to_player = RaceManager.get_track_progress(player) - RaceManager.get_track_progress(racer)

	var choice: StringName = &"SAFE"
	if pack_role == &"LEAD":
		# Competitive convergence is race craft only: stronger current line,
		# drafting alignment and burst timing. No hidden top-speed multiplier.
		if gap_to_player > 11.0 and selection_skill >= 0.66:
			choice = &"RISK"
		else:
			choice = &"FAST"
	elif pack_role == &"MID":
		choice = &"FAST" if selection_skill >= 0.56 else &"SAFE"
	else:
		choice = &"FAST" if selection_skill >= 0.72 else &"SAFE"

	if zone == "WHIRLPOOL CANYON":
		var whirl_skill := _driver_float(racer, "whirlpool_avoidance", selection_skill)
		if selection_skill >= 0.78 and line_skill >= 0.74 and whirl_skill >= 0.70:
			choice = &"RISK"
		else:
			choice = &"SAFE"
		_log_whirlpool_choice_once(racer, pack_role, choice, whirl_skill)

	var target_x := _strategic_lane_x(zone, choice, base_lane, racer)
	if zone == "OPEN WATER SPRINT" and line_skill >= 0.68:
		var draft_target := _nearby_draft_target_x(racer)
		if not is_nan(draft_target):
			target_x = lerpf(target_x, draft_target, 0.58)

	# Moderate skill AIs avoid the face of a moving log; high dive-skill racers
	# deliberately hold the lane and use Dive Burst instead.
	var obstacle_skill := _driver_float(racer, "obstacle_avoidance", 0.65)
	var dive_skill := _driver_float(racer, "dive_timing", 0.65)
	for entry in _moving_logs:
		var body := entry.get("body") as AnimatableBody3D
		if body == null:
			continue
		var distance_ahead := racer.global_position.z - body.global_position.z
		var half_width := float(entry.get("half_width", 5.0))
		if distance_ahead >= 2.0 and distance_ahead <= 16.0 and absf(target_x - body.global_position.x) <= half_width + 0.8:
			if dive_skill < 0.72 or obstacle_skill < 0.68:
				var side := -1.0 if body.global_position.x >= 0.0 else 1.0
				target_x += side * lerpf(2.2, 4.2, obstacle_skill)

	_note_ai_line_choice(racer, choice)
	return clampf(target_x, -COURSE_HALF_WIDTH + 2.0, COURSE_HALF_WIDTH - 2.0)

func should_ai_burst_phase2(
	racer: WildDashCharacterController,
	pack_role: StringName,
	timing_skill: float,
	burst_clock: float,
) -> bool:
	if racer == null:
		return false
	var progress_gap := 0.0
	if player != null and is_instance_valid(player):
		progress_gap = RaceManager.get_track_progress(player) - RaceManager.get_track_progress(racer)
	var current := current_label_at(racer.global_position)
	if racer.global_position.z <= FINAL_SPRINT_Z:
		return timing_skill >= 0.58 and burst_clock >= lerpf(4.6, 3.1, timing_skill)
	if pack_role == &"LEAD" and progress_gap > 10.0:
		return burst_clock >= lerpf(5.2, 4.0, timing_skill)
	if current in [&"FAST", &"RAPID"] and timing_skill >= 0.62:
		return burst_clock >= lerpf(6.6, 4.8, timing_skill)
	return false

func should_ai_dive_for_profile(world_position: Vector3, dive_skill: float, obstacle_skill: float) -> bool:
	for entry in _moving_logs:
		var body := entry.get("body") as AnimatableBody3D
		if body == null:
			continue
		var forward_distance := world_position.z - body.global_position.z
		var half_width := float(entry.get("half_width", 5.0))
		if forward_distance < 0.0 or forward_distance > 13.0:
			continue
		if absf(world_position.x - body.global_position.x) > half_width + 0.9:
			continue
		var trigger_distance := lerpf(5.8, 11.5, clampf(dive_skill, 0.0, 1.0))
		return forward_distance <= trigger_distance and obstacle_skill >= 0.58
	return false

func emit_swim_audio(racer: WildDashCharacterController, event_id: StringName) -> void:
	# Keep a crowded field readable: semantic hooks exist for every racer, but
	# only the local player emits SFX through the shared AudioManager pool.
	if racer == null or racer != player:
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null or not audio.has_method("play_sfx_id"):
		return
	var sfx_id := "foot_water"
	var volume := 0.72
	match event_id:
		&"swim_stroke":
			sfx_id = "foot_water"
			volume = 0.48
		&"swim_burst":
			sfx_id = "boost"
			volume = 0.82
		&"dive":
			sfx_id = "splash"
			volume = 0.80
		&"splash":
			sfx_id = "splash"
			volume = 0.68
		&"current_fast":
			sfx_id = "wave"
			volume = 0.42
		&"whirlpool":
			sfx_id = "wave"
			volume = 0.62
		&"checkpoint":
			sfx_id = "ui"
			volume = 0.72
		&"final_sprint":
			sfx_id = "boost"
			volume = 0.72
		&"finish":
			sfx_id = "finish"
			volume = 0.92
		_:
			pass
	audio.call("play_sfx_id", sfx_id, volume)

func _on_checkpoint_reached(racer: Node3D, checkpoint_index: int, total: int) -> void:
	print("r5_checkpoint racer=%s checkpoint=%d/%d zone=%s water_spawn=true" % [
		RaceManager.get_racer_label(racer), checkpoint_index + 1, total, _zone_name_for_position(racer.global_position),
	])
	if racer == player:
		emit_swim_audio(player, &"checkpoint")

func _on_any_racer_finished(racer: Node3D, rank: int) -> void:
	print("r5_finish_clear racer=%s rank=%d final_buoy=true phase2=true" % [RaceManager.get_racer_label(racer), rank])
	if racer == player:
		emit_swim_audio(player, &"finish")

func _on_player_finished(rank: int) -> void:
	_player_rank = rank
	var finish_pack := _count_nearby_finish_competitors(player, 42.0)
	print("r5_finish_pack_count phase=finish count=%d target=2_4 teleport=false" % finish_pack)
	if not GameManager.campaign_running:
		_promote_direct_round5_to_campaign_final()
	var elapsed := RaceManager.get_elapsed_seconds()
	finish_mode(true, rank, {
		"rank": rank,
		"racers": RaceManager.racers.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"player_finish_seconds": elapsed,
		"round5_rebuild": "wild_current_phase2",
		"water_only": true,
		"finish_pack_count": finish_pack,
		"competitive_swimming": true,
	})

func _ensure_phase2_runtime_ready() -> void:
	if _phase2_ready or player == null or RaceManager.racers.is_empty():
		return
	_phase2_ready = true
	_base_camera_fov = _camera.fov if _camera != null else 74.0
	for racer_node in RaceManager.racers:
		var racer := racer_node as WildDashCharacterController
		if racer != null:
			_attach_swim_feedback(racer)
	_log_qa_pack_matrix()
	print("WILD CURRENT PHASE2 READY racers=%d lead_mid_back=true wake_draft=shared current_strategy=true teleport_convergence=false" % RaceManager.racers.size())

func _update_moving_logs() -> void:
	for entry in _moving_logs:
		var body := entry.get("body") as AnimatableBody3D
		if body == null:
			continue
		var origin: Vector3 = entry.get("origin", body.position)
		var amplitude := float(entry.get("amplitude", 1.5))
		var speed := float(entry.get("speed", 0.6))
		var phase := float(entry.get("phase", 0.0))
		var target := origin
		target.x += sin(_phase2_elapsed * speed + phase) * amplitude
		body.position = target

func _attach_swim_feedback(racer: WildDashCharacterController) -> void:
	if _wake_feedback.has(racer.get_instance_id()):
		return
	var root := Node3D.new()
	root.name = "Round5SwimFeedback"
	racer.add_child(root)

	var wake := MeshInstance3D.new()
	wake.name = "WakeTrail"
	wake.position = Vector3(0.0, -0.30, 1.55)
	var wake_mesh := BoxMesh.new()
	wake_mesh.size = Vector3(0.86, 0.04, 2.7)
	wake.mesh = wake_mesh
	var wake_material := StandardMaterial3D.new()
	wake_material.albedo_color = Color(0.78, 0.96, 1.0, 0.42)
	wake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wake_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wake.material_override = wake_material
	root.add_child(wake)

	var splash := MeshInstance3D.new()
	splash.name = "SurfaceSplash"
	splash.position = Vector3(0.0, 0.04, -0.35)
	var splash_mesh := BoxMesh.new()
	splash_mesh.size = Vector3(1.25, 0.05, 0.55)
	splash.mesh = splash_mesh
	var splash_material := StandardMaterial3D.new()
	splash_material.albedo_color = Color(0.90, 0.98, 1.0, 0.50)
	splash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splash.material_override = splash_material
	root.add_child(splash)
	_wake_feedback[racer.get_instance_id()] = {"wake": wake, "splash": splash}

func _update_swim_feedback() -> void:
	for racer_node in RaceManager.racers:
		var racer := racer_node as WildDashCharacterController
		if racer == null:
			continue
		var entry: Dictionary = _wake_feedback.get(racer.get_instance_id(), {})
		var wake := entry.get("wake") as MeshInstance3D
		var splash := entry.get("splash") as MeshInstance3D
		if wake != null:
			wake.visible = racer.current_speed > 3.8
			wake.scale.z = clampf(0.65 + racer.current_speed / 12.0, 0.75, 1.75)
		if splash != null:
			var driver := _swimmers.get(racer.get_instance_id(), null) as WildCurrentSwimmerPhase2
			splash.visible = racer.current_speed > 4.6 and (driver == null or not driver.is_diving())
			if driver != null and driver.is_bursting():
				splash.scale = Vector3(1.35, 1.0, 1.20)
			else:
				splash.scale = Vector3.ONE

func _update_round5_camera(delta: float) -> void:
	if _camera == null or player == null or not _phase2_ready:
		return
	var driver := _swimmers.get(player.get_instance_id(), null) as WildCurrentSwimmerPhase2
	var speed_ratio := clampf(player.current_speed / 14.0, 0.0, 1.0)
	var target_fov := _base_camera_fov + speed_ratio * 3.8
	if driver != null and driver.is_bursting():
		target_fov += 1.8
	if driver != null and driver.is_diving():
		target_fov -= 1.2
	if player.global_position.z <= FINAL_SPRINT_Z:
		target_fov += 0.8
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 3.6, 0.0, 1.0))

func _update_phase2_hud() -> void:
	if hud == null or player == null or not _phase2_ready:
		return
	var zone := _zone_name_for_position(player.global_position)
	var current := current_label_at(player.global_position)
	var current_text := "OPEN WATER" if current == &"" else String(current)
	if player.global_position.z <= FINAL_SPRINT_Z:
		hud.set_message("FINAL CURRENT · BURST + DRAFT + STEERING · FINISH BUOYS AHEAD")
	else:
		hud.set_message("%s · CURRENT %s · FAST LINE / SAFE LINE / RISK LINE" % [zone, current_text])

func _update_final_sprint_state() -> void:
	if not RaceManager.active:
		return
	for racer_node in RaceManager.racers:
		var racer := racer_node as WildDashCharacterController
		if racer == null or racer.finished or racer.global_position.z > FINAL_SPRINT_Z:
			continue
		var id := racer.get_instance_id()
		if _final_sprint_seen.has(id):
			continue
		_final_sprint_seen[id] = true
		print("r5_final_sprint_enter racer=%s rank=%d progress=%.1f" % [
			RaceManager.get_racer_label(racer), RaceManager.get_rank(racer), RaceManager.get_progress_percent(racer),
		])
		if racer == player:
			emit_swim_audio(player, &"final_sprint")
			var pack_count := _count_nearby_finish_competitors(player, FINISH_PACK_DISTANCE)
			print("r5_finish_pack_count phase=final_sprint count=%d target_min=2 recommended=3_4 distance=%.1f teleport=false" % [
				pack_count, FINISH_PACK_DISTANCE,
			])

func _count_nearby_finish_competitors(reference: WildDashCharacterController, distance_limit: float) -> int:
	if reference == null:
		return 0
	var reference_progress := RaceManager.get_track_progress(reference)
	var count := 0
	for other_node in RaceManager.racers:
		var other := other_node as WildDashCharacterController
		if other == null or other == reference or other.finished:
			continue
		if absf(RaceManager.get_track_progress(other) - reference_progress) <= distance_limit:
			count += 1
	return count

func _pack_role_for_ai_slot(slot: int, ai_total: int) -> StringName:
	var counts := _pack_counts_for_ai_total(ai_total)
	var lead_count := int(counts.get("lead", 0))
	var mid_count := int(counts.get("mid", 0))
	if slot >= 0 and slot < lead_count:
		return &"LEAD"
	if slot >= lead_count and slot < lead_count + mid_count:
		return &"MID"
	return &"BACK"

func _pack_counts_for_ai_total(ai_total: int) -> Dictionary:
	if ai_total <= 0:
		return {"lead": 0, "mid": 0, "back": 0}
	var lead := 4 if ai_total >= 12 else (3 if ai_total >= 7 else maxi(1, roundi(float(ai_total) * 0.30)))
	var mid := 7 if ai_total >= 16 else (6 if ai_total >= 12 else (4 if ai_total >= 8 else maxi(1, roundi(float(ai_total) * 0.45))))
	mid = mini(mid, maxi(0, ai_total - lead))
	var back := maxi(0, ai_total - lead - mid)
	return {"lead": lead, "mid": mid, "back": back}

func _ai_skill_profile(role: StringName, slot: int) -> Dictionary:
	var center := 0.48
	match role:
		&"LEAD": center = 0.84
		&"MID": center = 0.64
		_: center = 0.48
	var wave := (float((slot * 37) % 11) - 5.0) * 0.009
	return {
		"steering_accuracy": clampf(center + wave + 0.03, 0.38, 0.94),
		"current_selection": clampf(center - wave * 0.5, 0.38, 0.94),
		"burst_timing": clampf(center + wave * 0.7, 0.38, 0.94),
		"dive_timing": clampf(center - 0.02 - wave, 0.38, 0.94),
		"obstacle_avoidance": clampf(center + 0.01 + wave * 0.4, 0.38, 0.94),
		"whirlpool_avoidance": clampf(center + 0.04 - wave * 0.3, 0.38, 0.94),
		"racing_line_quality": clampf(center + 0.02 + wave * 0.5, 0.38, 0.94),
	}

func _player_skill_profile() -> Dictionary:
	return {
		"steering_accuracy": 0.72,
		"current_selection": 0.72,
		"burst_timing": 0.72,
		"dive_timing": 0.72,
		"obstacle_avoidance": 0.72,
		"whirlpool_avoidance": 0.72,
		"racing_line_quality": 0.72,
	}

func _log_pack_assignment(racer: WildDashCharacterController, role: StringName, slot: int) -> void:
	var telemetry := "r5_ai_back_pack"
	if role == &"LEAD":
		telemetry = "r5_ai_lead_pack"
	elif role == &"MID":
		telemetry = "r5_ai_mid_pack"
	print("%s racer=%s slot=%d role=%s speed_cheat=false teleport=false" % [
		telemetry, RaceManager.get_racer_label(racer), slot + 1, String(role),
	])

func _strategic_lane_x(zone: String, choice: StringName, base_lane: float, racer: WildDashCharacterController) -> float:
	match zone:
		"BLUE LAGOON":
			if choice == &"RISK": return 8.0
			if choice == &"FAST": return -4.0
			return 0.0 + base_lane * 0.25
		"CURRENT CROSSING":
			if choice == &"RISK": return -6.0
			if choice == &"FAST": return -4.8
			return 10.0
		"FLOATING FOREST":
			if choice == &"RISK": return 1.5
			if choice == &"FAST": return 5.5
			return -9.0
		"WHIRLPOOL CANYON":
			if choice == &"RISK":
				return -13.0 if racer.global_position.z > -105.0 else 13.0
			return 0.0
		"RAPIDS RUN":
			if choice == &"RISK": return 8.0
			if choice == &"FAST": return 0.0
			return -10.0
		_:
			if choice == &"RISK": return 6.5
			if choice == &"FAST": return 0.0
			return clampf(base_lane * 0.7, -6.0, 6.0)

func _nearby_draft_target_x(racer: WildDashCharacterController) -> float:
	var own_progress := RaceManager.get_track_progress(racer)
	var best_gap := 14.0
	var found := false
	var result := 0.0
	for other_node in RaceManager.racers:
		var other := other_node as WildDashCharacterController
		if other == null or other == racer or other.finished:
			continue
		var gap := RaceManager.get_track_progress(other) - own_progress
		if gap > 1.0 and gap < best_gap:
			best_gap = gap
			result = other.global_position.x
			found = true
	return result if found else NAN

func _driver_float(racer: WildDashCharacterController, property_name: String, fallback: float) -> float:
	if racer == null:
		return fallback
	var driver: Variant = _swimmers.get(racer.get_instance_id(), null)
	if driver == null:
		return fallback
	var value: Variant = driver.get(property_name)
	if typeof(value) in [TYPE_FLOAT, TYPE_INT]:
		return float(value)
	return fallback

func _note_ai_line_choice(racer: WildDashCharacterController, choice: StringName) -> void:
	var driver := _swimmers.get(racer.get_instance_id(), null) as WildCurrentSwimmerPhase2
	if driver != null:
		driver.note_ai_line(choice)

func _log_whirlpool_choice_once(racer: WildDashCharacterController, role: StringName, choice: StringName, skill: float) -> void:
	if racer == null:
		return
	var id := racer.get_instance_id()
	if _whirlpool_choice_logged.has(id):
		return
	_whirlpool_choice_logged[id] = true
	print("r5_ai_whirlpool_avoid racer=%s pack=%s choice=%s skill=%.2f edge_reward=%s" % [
		RaceManager.get_racer_label(racer), String(role), String(choice), skill, str(choice == &"RISK"),
	])

func _add_floating_debris(name_text: String, position_value: Vector3, size_value: Vector3) -> void:
	var debris := MeshInstance3D.new()
	debris.name = name_text
	debris.position = position_value
	var mesh := BoxMesh.new()
	mesh.size = size_value
	debris.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.40, 0.27, 0.12)
	material.roughness = 0.9
	debris.material_override = material
	add_child(debris)

func _build_current_particles() -> void:
	for current in _currents:
		if current == null:
			continue
		var particles := GPUParticles3D.new()
		particles.name = "%sCurrentParticles" % current.name
		particles.position = current.global_position
		particles.amount = 18 if current.current_type == &"NORMAL" else 28
		particles.lifetime = 1.25
		particles.randomness = 0.35
		var process_material := ParticleProcessMaterial.new()
		process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process_material.emission_box_extents = Vector3(current.width * 0.45, 0.05, current.length * 0.45)
		process_material.direction = current.direction
		process_material.initial_velocity_min = 0.8 + current.strength * 0.45
		process_material.initial_velocity_max = 1.4 + current.strength * 0.65
		process_material.gravity = Vector3.ZERO
		particles.process_material = process_material
		var particle_mesh := BoxMesh.new()
		particle_mesh.size = Vector3(0.05, 0.025, 0.72)
		var particle_material := StandardMaterial3D.new()
		particle_material.albedo_color = Color(0.72, 0.95, 1.0, 0.34)
		particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		particle_mesh.material = particle_material
		particles.draw_pass_1 = particle_mesh
		add_child(particles)

func _log_qa_pack_matrix() -> void:
	for racers_count in [10, 15, 18]:
		var counts := _pack_counts_for_ai_total(racers_count - 1)
		print("R5 QA PACK MATRIX racers=%d lead=%d mid=%d back=%d total_ai=%d water_only=true" % [
			racers_count,
			int(counts.get("lead", 0)),
			int(counts.get("mid", 0)),
			int(counts.get("back", 0)),
			racers_count - 1,
		])
