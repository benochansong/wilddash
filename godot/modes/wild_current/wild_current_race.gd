extends WildDashModeController

## WILD CURRENT: RIVER RUSH — Round 5 Phase 1 vertical slice.
## This mode replaces the legacy Neon Harbor campaign slot with a continuous
## water-only race. Legacy Neon Harbor assets remain source-only so Round 1-4
## dependencies are never deleted by the Round 5 rebuild.

const SWIMMER_SCRIPT: Script = preload("res://modes/wild_current/wild_current_swimmer.gd")
const CURRENT_SCRIPT: Script = preload("res://modes/wild_current/wild_current_volume.gd")
const WHIRLPOOL_SCRIPT: Script = preload("res://modes/wild_current/wild_whirlpool_volume.gd")
const CHASE_CAMERA_SCRIPT: Script = preload("res://camera/chase_camera.gd")

const WATER_SURFACE_Y: float = 0.58
const COURSE_HALF_WIDTH: float = 22.0
const COURSE_START_Z: float = 258.0
const COURSE_FINISH_Z: float = -336.0
const COURSE_MIN_Z: float = -365.0
const COURSE_MAX_Z: float = 278.0
const DIRECT_ROUND5_INDEX: int = 4
const START_GRID_COLUMNS: int = 4
const START_GRID_X_SPACING: float = 2.55
const START_GRID_Z_SPACING: float = 3.0
const AI_LANES: Array[float] = [-4.8, -2.8, -0.9, 1.0, 3.0, 4.9, -3.8, -1.8, 0.2, 2.0, 4.0, -4.4, -2.2, 1.8, 4.5, 0.8, -0.4]

var _route_points: Array[Vector3] = []
var _checkpoint_positions: Array[Vector3] = []
var _currents: Array[WildCurrentVolume] = []
var _whirlpools: Array[WildWhirlpoolVolume] = []
var _swimmers: Dictionary = {}
var _floating_log_positions: Array[Vector3] = []
var _player_swimmer: WildCurrentSwimmer
var _finish_gate: Area3D
var _player_rank: int = 0
var _camera: Camera3D

func _ready() -> void:
	setup_mode(
		&"wild_current",
		"ROUND 5 — WILD CURRENT: RIVER RUSH",
		"W/↑ 수영 · A/D 조향 · SHIFT Swim Burst · SPACE Dive Burst · 물살을 타고 FINAL BUOY까지",
		false,
	)
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()

	_route_points = _build_route_points()
	_checkpoint_positions = _build_checkpoint_positions()
	RaceManager.configure_track(_route_points, _checkpoint_positions)

	_build_water_world()
	_build_currents()
	_build_whirlpools()
	_build_basic_hazards()
	_build_checkpoint_markers()
	_build_finish_gate()
	_spawn_field()
	_build_camera()

	RaceManager.checkpoint_reached.connect(_on_checkpoint_reached)
	RaceManager.racer_finished.connect(_on_any_racer_finished)
	RaceManager.race_finished.connect(_on_player_finished)

	await get_tree().physics_frame
	await get_tree().physics_frame
	GameManager.begin_round(&"wild_current")
	RaceManager.start_race()
	print("r5_swim_start racers=%d ai=%d water_only=true route_points=%d checkpoints=%d legacy_neon_harbor=false" % [
		RaceManager.racers.size(), ai_racers.size(), _route_points.size(), _checkpoint_positions.size(),
	])

func _process(_delta: float) -> void:
	if player == null or hud == null:
		return
	var rank := RaceManager.get_rank(player)
	var cp := RaceManager.get_checkpoint_progress(player)
	var progress := roundi(RaceManager.get_progress_percent(player))
	var zone := _zone_name_for_position(player.global_position)
	hud.set_metrics("Rank %d/%d   CP %d/%d   %s   Progress %d%%   Swim %.1f" % [
		rank, RaceManager.racers.size(), cp, RaceManager.get_checkpoint_count(), zone, progress, player.current_speed,
	])
	if _player_swimmer != null:
		var burst_percent := roundi(_player_swimmer.get_burst_ready_ratio() * 100.0)
		var dive_state := "DIVING" if _player_swimmer.is_diving() else "SPACE DIVE"
		hud.set_item_state("SWIM BURST %d%%" % burst_percent, "SHIFT BURST · %s" % dive_state)

func _physics_process(_delta: float) -> void:
	if not RaceManager.active:
		return
	for racer_node in RaceManager.racers.duplicate():
		var racer := racer_node as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		RaceManager.sync_checkpoint_from_position(racer)
		if _is_invalid_water_position(racer.global_position):
			_recover_to_safe_water(racer)

func sample_water_force(world_position: Vector3, burst_active: bool, dive_active: bool) -> Vector3:
	# A mild river-wide downstream drift means every part of the course is water,
	# while authored Current Volumes create the meaningful racing lines.
	var force := Vector3(0.0, 0.0, -0.48)
	for current in _currents:
		if current != null and current.contains_world_point(world_position):
			force += current.sample_force(world_position)
	for whirlpool in _whirlpools:
		if whirlpool == null or not whirlpool.contains_world_point(world_position):
			continue
		var whirl_force := whirlpool.sample_force(world_position)
		# Burst/Dive remain real escape tools rather than a scripted reset.
		if burst_active or dive_active:
			whirl_force *= 0.48
		force += whirl_force
	return force

func current_label_at(world_position: Vector3) -> StringName:
	var strongest: WildCurrentVolume = null
	for current in _currents:
		if current == null or not current.contains_world_point(world_position):
			continue
		if strongest == null or current.strength > strongest.strength:
			strongest = current
	return &"" if strongest == null else strongest.current_type

func is_in_whirlpool(world_position: Vector3) -> bool:
	for whirlpool in _whirlpools:
		if whirlpool != null and whirlpool.contains_world_point(world_position):
			return true
	return false

func should_ai_dive(world_position: Vector3) -> bool:
	# AI uses the same Dive Burst as the player when a floating log spans its lane.
	for log_position in _floating_log_positions:
		var forward_distance := world_position.z - log_position.z
		if forward_distance >= 0.0 and forward_distance <= 13.0 and absf(world_position.x - log_position.x) <= 7.5:
			return true
	return false

func _build_route_points() -> Array[Vector3]:
	return [
		Vector3(0.0, WATER_SURFACE_Y, 250.0),
		Vector3(0.0, WATER_SURFACE_Y, 220.0),
		Vector3(3.5, WATER_SURFACE_Y, 182.0),
		Vector3(-2.5, WATER_SURFACE_Y, 145.0),
		Vector3(2.0, WATER_SURFACE_Y, 108.0),
		Vector3(0.0, WATER_SURFACE_Y, 72.0),
		Vector3(-4.0, WATER_SURFACE_Y, 34.0),
		Vector3(4.0, WATER_SURFACE_Y, -4.0),
		Vector3(0.0, WATER_SURFACE_Y, -42.0),
		Vector3(-5.0, WATER_SURFACE_Y, -82.0),
		Vector3(5.0, WATER_SURFACE_Y, -122.0),
		Vector3(0.0, WATER_SURFACE_Y, -162.0),
		Vector3(-3.5, WATER_SURFACE_Y, -202.0),
		Vector3(2.0, WATER_SURFACE_Y, -242.0),
		Vector3(0.0, WATER_SURFACE_Y, -282.0),
		Vector3(0.0, WATER_SURFACE_Y, COURSE_FINISH_Z),
	]

func _build_checkpoint_positions() -> Array[Vector3]:
	return [
		Vector3(3.5, WATER_SURFACE_Y, 182.0),
		Vector3(2.0, WATER_SURFACE_Y, 108.0),
		Vector3(-4.0, WATER_SURFACE_Y, 34.0),
		Vector3(-5.0, WATER_SURFACE_Y, -82.0),
		Vector3(-3.5, WATER_SURFACE_Y, -202.0),
		Vector3(0.0, WATER_SURFACE_Y, -282.0),
	]

func _build_water_world() -> void:
	var center_z := (COURSE_START_Z + COURSE_FINISH_Z) * 0.5
	var course_length := absf(COURSE_START_Z - COURSE_FINISH_Z) + 48.0
	create_box("ContinuousWaterSurface", Vector3(0.0, -0.18, center_z), Vector3(COURSE_HALF_WIDTH * 2.0, 0.24, course_length), Color(0.04, 0.63, 0.77), false)
	create_box("RiverBed", Vector3(0.0, -4.2, center_z), Vector3(COURSE_HALF_WIDTH * 2.0, 0.55, course_length), Color(0.08, 0.24, 0.30), true)
	create_box("WestRiverBank", Vector3(-COURSE_HALF_WIDTH - 0.55, -0.2, center_z), Vector3(1.1, 8.0, course_length), Color(0.18, 0.31, 0.22), true)
	create_box("EastRiverBank", Vector3(COURSE_HALF_WIDTH + 0.55, -0.2, center_z), Vector3(1.1, 8.0, course_length), Color(0.18, 0.31, 0.22), true)
	create_box("StartWaterBoundary", Vector3(0.0, -0.4, COURSE_MAX_Z), Vector3(COURSE_HALF_WIDTH * 2.0, 7.0, 1.0), Color(0.15, 0.28, 0.24), true)
	create_box("FinishWaterRunoutBoundary", Vector3(0.0, -0.4, COURSE_MIN_Z), Vector3(COURSE_HALF_WIDTH * 2.0, 7.0, 1.0), Color(0.15, 0.28, 0.24), true)
	print("WILD CURRENT WATER WORLD continuous=true surface_y=%.2f width=%.1f length=%.1f land_requirement=false" % [
		WATER_SURFACE_Y, COURSE_HALF_WIDTH * 2.0, course_length,
	])

func _build_currents() -> void:
	_add_current("LagoonCurrent", Vector3(0.0, WATER_SURFACE_Y, 220.0), Vector3(0.0, 0.0, -1.0), 0.65, 36.0, 70.0, &"NORMAL")
	_add_current("FastLeftCurrent", Vector3(-6.0, WATER_SURFACE_Y, 145.0), Vector3(0.08, 0.0, -1.0), 1.75, 9.0, 92.0, &"FAST")
	_add_current("CrossCurrent", Vector3(6.0, WATER_SURFACE_Y, 88.0), Vector3(-0.48, 0.0, -1.0), 1.25, 10.0, 76.0, &"CROSS")
	_add_current("ForestFastLane", Vector3(5.0, WATER_SURFACE_Y, 8.0), Vector3(-0.05, 0.0, -1.0), 1.60, 8.0, 86.0, &"FAST")
	_add_current("RapidsCurrent", Vector3(0.0, WATER_SURFACE_Y, -220.0), Vector3(0.0, 0.0, -1.0), 2.85, 38.0, 118.0, &"RAPID")
	_add_current("FinalCurrent", Vector3(0.0, WATER_SURFACE_Y, -304.0), Vector3(0.0, 0.0, -1.0), 1.15, 34.0, 70.0, &"NORMAL")

func _add_current(
	name_text: String,
	position_value: Vector3,
	direction_value: Vector3,
	strength_value: float,
	width_value: float,
	length_value: float,
	type_value: StringName,
) -> void:
	var current := CURRENT_SCRIPT.new() as WildCurrentVolume
	if current == null:
		return
	current.name = name_text
	add_child(current)
	current.configure(position_value, direction_value, strength_value, width_value, length_value, type_value)
	_currents.append(current)

func _build_whirlpools() -> void:
	_add_whirlpool("WhirlpoolWest", Vector3(-7.0, WATER_SURFACE_Y, -78.0), 7.5, 4.1)
	_add_whirlpool("WhirlpoolEast", Vector3(7.0, WATER_SURFACE_Y, -124.0), 7.2, 4.4)

func _add_whirlpool(name_text: String, position_value: Vector3, radius_value: float, strength_value: float) -> void:
	var whirlpool := WHIRLPOOL_SCRIPT.new() as WildWhirlpoolVolume
	if whirlpool == null:
		return
	whirlpool.name = name_text
	add_child(whirlpool)
	whirlpool.configure(position_value, radius_value, strength_value)
	_whirlpools.append(whirlpool)

	var visual := CSGCylinder3D.new()
	visual.name = "%sVisual" % name_text
	visual.position = position_value + Vector3(0.0, -0.04, 0.0)
	visual.radius = radius_value
	visual.height = 0.08
	visual.sides = 24
	visual.use_collision = false
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.35, 0.52, 0.82)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.35
	visual.material = material
	add_child(visual)

func _build_basic_hazards() -> void:
	_add_floating_log("FloatingLogA", Vector3(0.0, 1.65, 43.0), Vector3(14.0, 1.0, 2.2))
	_add_floating_log("FloatingLogB", Vector3(-4.0, 1.65, 4.0), Vector3(11.0, 1.0, 2.2))
	_add_rock("RiverRockA", Vector3(8.0, -0.2, 118.0), 2.0)
	_add_rock("RiverRockB", Vector3(-9.0, -0.3, -174.0), 2.4)
	_add_rock("RiverRockC", Vector3(7.5, -0.2, -232.0), 1.8)
	_add_reed_cluster("ReedsWest", Vector3(-12.5, 0.4, 70.0))
	_add_reed_cluster("ReedsEast", Vector3(12.5, 0.4, -20.0))
	print("WILD CURRENT HAZARDS floating_logs=%d rocks=3 reeds=2 whirlpools=%d simple_collision=true" % [
		_floating_log_positions.size(), _whirlpools.size(),
	])

func _add_floating_log(name_text: String, position_value: Vector3, size_value: Vector3) -> void:
	create_box(name_text, position_value, size_value, Color(0.52, 0.29, 0.12), true)
	var water_reference := position_value
	water_reference.y = WATER_SURFACE_Y
	_floating_log_positions.append(water_reference)

func _add_rock(name_text: String, position_value: Vector3, radius_value: float) -> void:
	var rock := CSGSphere3D.new()
	rock.name = name_text
	rock.position = position_value
	rock.radius = radius_value
	rock.radial_segments = 16
	rock.rings = 8
	rock.use_collision = true
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.29, 0.28)
	material.roughness = 0.92
	rock.material = material
	add_child(rock)

func _add_reed_cluster(name_text: String, position_value: Vector3) -> void:
	var root := Node3D.new()
	root.name = name_text
	root.position = position_value
	add_child(root)
	for index in range(5):
		var reed := CSGBox3D.new()
		reed.name = "Reed_%02d" % index
		reed.position = Vector3(float(index - 2) * 0.55, 0.0, float(index % 2) * 0.45)
		reed.size = Vector3(0.20, 2.1 + float(index % 3) * 0.35, 0.20)
		reed.use_collision = true
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.22, 0.58, 0.25)
		material.roughness = 0.9
		reed.material = material
		root.add_child(reed)

func _build_checkpoint_markers() -> void:
	for index in range(_checkpoint_positions.size()):
		var cp := _checkpoint_positions[index]
		var marker := CSGBox3D.new()
		marker.name = "WaterCheckpoint_%02d" % (index + 1)
		marker.position = cp + Vector3(0.0, 2.9, 0.0)
		marker.size = Vector3(17.0, 0.26, 0.32)
		marker.use_collision = false
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.96, 0.82, 0.24)
		material.emission_enabled = true
		material.emission = Color(0.35, 0.25, 0.05)
		marker.material = material
		add_child(marker)

func _build_finish_gate() -> void:
	var finish_position := Vector3(0.0, WATER_SURFACE_Y, COURSE_FINISH_Z)
	_finish_gate = Area3D.new()
	_finish_gate.name = "FinalBuoyGate"
	_finish_gate.position = finish_position
	_finish_gate.collision_layer = 0
	_finish_gate.collision_mask = 2
	_finish_gate.monitoring = true
	add_child(_finish_gate)

	var shape_node := CollisionShape3D.new()
	shape_node.name = "FinishGateShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(22.0, 4.5, 4.0)
	shape_node.shape = shape
	_finish_gate.add_child(shape_node)
	_finish_gate.body_entered.connect(_on_finish_gate_body_entered)

	for x in [-10.0, 10.0]:
		var buoy := CSGCylinder3D.new()
		buoy.name = "FinishBuoy_%s" % ("L" if x < 0.0 else "R")
		buoy.position = finish_position + Vector3(x, 1.35, 0.0)
		buoy.radius = 0.8
		buoy.height = 3.2
		buoy.sides = 16
		buoy.use_collision = false
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.98, 0.42, 0.16)
		material.roughness = 0.65
		buoy.material = material
		add_child(buoy)
	create_box("FinishGateBanner", finish_position + Vector3(0.0, 4.0, 0.0), Vector3(20.0, 0.6, 0.8), Color(1.0, 0.83, 0.18), false)

func _spawn_field() -> void:
	var start := _route_points[0]
	player = spawn_racer("Player", GameManager.selected_animal, start + _start_grid_offset(0), true, WildDashCharacterController.MovementMode.RACE)
	_attach_swimmer(player, true, 0.0)

	for index in range(GameManager.ai_count):
		var spawn_position := start + _start_grid_offset(index + 1)
		var racer := spawn_racer("AI_%02d" % (index + 1), &"dog", spawn_position, false, WildDashCharacterController.MovementMode.RACE)
		var lane := AI_LANES[index % AI_LANES.size()]
		_attach_swimmer(racer, false, lane)

func _attach_swimmer(racer: WildDashCharacterController, is_player_swimmer: bool, lane: float) -> void:
	if racer == null:
		return
	var swimmer := SWIMMER_SCRIPT.new() as WildCurrentSwimmer
	if swimmer == null:
		return
	swimmer.name = "%sSwimDriver" % racer.name
	add_child(swimmer)
	swimmer.configure(racer, self, _route_points, is_player_swimmer, lane)
	_swimmers[racer.get_instance_id()] = swimmer
	if is_player_swimmer:
		_player_swimmer = swimmer

func _start_grid_offset(slot: int) -> Vector3:
	var row := slot / START_GRID_COLUMNS
	var column := slot % START_GRID_COLUMNS
	var center := float(START_GRID_COLUMNS - 1) * 0.5
	var stagger := 0.45 if row % 2 == 1 else 0.0
	return Vector3((float(column) - center) * START_GRID_X_SPACING + stagger, 0.0, float(row) * START_GRID_Z_SPACING)

func _build_camera() -> void:
	_camera = CHASE_CAMERA_SCRIPT.new() as Camera3D
	if _camera == null:
		return
	_camera.name = "WildCurrentChaseCamera"
	_camera.current = true
	_camera.fov = 74.0
	add_child(_camera)
	_camera.call("set_target", player)

func _on_checkpoint_reached(racer: Node3D, checkpoint_index: int, total: int) -> void:
	print("r5_checkpoint racer=%s checkpoint=%d/%d zone=%s water_spawn=true" % [
		RaceManager.get_racer_label(racer), checkpoint_index + 1, total, _zone_name_for_position(racer.global_position),
	])

func _on_finish_gate_body_entered(body: Node3D) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished:
		return
	print("r5_finish_enter racer=%s checkpoints=%d/%d" % [
		RaceManager.get_racer_label(racer), RaceManager.get_checkpoint_progress(racer), RaceManager.get_checkpoint_count(),
	])
	if not RaceManager.can_finish(racer):
		return
	RaceManager.record_finish(racer)

func _on_any_racer_finished(racer: Node3D, rank: int) -> void:
	print("r5_finish_clear racer=%s rank=%d final_buoy=true" % [RaceManager.get_racer_label(racer), rank])

func _on_player_finished(rank: int) -> void:
	_player_rank = rank
	if not GameManager.campaign_running:
		_promote_direct_round5_to_campaign_final()
	var elapsed := RaceManager.get_elapsed_seconds()
	finish_mode(true, rank, {
		"rank": rank,
		"racers": RaceManager.racers.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"player_finish_seconds": elapsed,
		"round5_rebuild": "wild_current_phase1",
		"water_only": true,
	})

func _promote_direct_round5_to_campaign_final() -> void:
	ResultManager.reset_campaign()
	GameManager.campaign_running = true
	GameManager.current_round_index = DIRECT_ROUND5_INDEX
	GameManager.round_active = true
	GameManager._transition_pending = false
	print("r5_direct_finish_promoted_to_campaign_final round_index=5 final_result=true")

func _is_invalid_water_position(position_value: Vector3) -> bool:
	return absf(position_value.x) > COURSE_HALF_WIDTH + 5.0 \
		or position_value.z > COURSE_MAX_Z + 4.0 \
		or position_value.z < COURSE_MIN_Z - 4.0 \
		or position_value.y < -5.3 \
		or position_value.y > 5.2

func _recover_to_safe_water(racer: WildDashCharacterController) -> void:
	var checkpoint_progress := RaceManager.get_checkpoint_progress(racer)
	var target := _route_points[0]
	if checkpoint_progress > 0 and not _checkpoint_positions.is_empty():
		var checkpoint_index := mini(checkpoint_progress - 1, _checkpoint_positions.size() - 1)
		target = _checkpoint_positions[checkpoint_index] + Vector3(0.0, 0.0, -5.0)
	target.y = WATER_SURFACE_Y
	var value: Variant = _swimmers.get(racer.get_instance_id(), null)
	var swimmer := value as WildCurrentSwimmer
	if swimmer != null:
		swimmer.force_water_reset(target)
	else:
		racer.global_position = target
		racer.velocity = Vector3.ZERO
	print("r5_recovery racer=%s reason=out_of_water_bounds target=(%.1f,%.1f,%.1f) dive_false_positive=false" % [
		RaceManager.get_racer_label(racer), target.x, target.y, target.z,
	])

func _zone_name_for_position(position_value: Vector3) -> String:
	if position_value.z > 180.0:
		return "BLUE LAGOON"
	if position_value.z > 72.0:
		return "CURRENT CROSSING"
	if position_value.z > -42.0:
		return "FLOATING FOREST"
	if position_value.z > -162.0:
		return "WHIRLPOOL CANYON"
	if position_value.z > -282.0:
		return "RAPIDS RUN"
	return "OPEN WATER SPRINT"
