extends "res://modes/wild_current/wild_current_race_phase2.gd"

## WILD CURRENT: RIVER RUSH — Phase 3 Long River Battle.
## Expands the short 590m final into a long water race with repeated comeback
## opportunities, shared item combat, visible leader-pressure gates and denser
## but readable obstacle decisions. No hidden teleport/rubber-band authority.

const PHASE3_SWIMMER_SCRIPT: Script = preload("res://modes/wild_current/wild_current_swimmer_phase3_item_combat.gd")
const ITEM_BOX_SCENE: PackedScene = preload("res://items/item_box.tscn")

const LONG_FINISH_Z: float = -1040.0
const LONG_MIN_Z: float = -1075.0
const LONG_FINAL_SPRINT_Z: float = -955.0
const ITEM_STATION_LANES: Array[float] = [-8.0, 0.0, 8.0]
const ITEM_STATION_Z: Array[float] = [205.0, 130.0, 48.0, -62.0, -176.0, -294.0, -405.0, -518.0, -632.0, -748.0, -862.0, -968.0]
const LEADER_WAVE_POWER: float = 6.2
const LEADER_WAVE_RETENTION: float = 0.84
const LEADER_WAVE_TRIGGER_HALF_DEPTH: float = 5.5

var _phase3_item_boxes: Array[WildDashItemBox] = []
var _leader_wave_gates: Array[Dictionary] = []
var _leader_wave_triggered: Dictionary = {}

func _process(delta: float) -> void:
	super(delta)
	_update_leader_wave_gates()

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
		Vector3(5.5, WATER_SURFACE_Y, -330.0),
		Vector3(-6.0, WATER_SURFACE_Y, -378.0),
		Vector3(4.5, WATER_SURFACE_Y, -426.0),
		Vector3(-3.0, WATER_SURFACE_Y, -474.0),
		Vector3(7.0, WATER_SURFACE_Y, -522.0),
		Vector3(-7.5, WATER_SURFACE_Y, -570.0),
		Vector3(3.0, WATER_SURFACE_Y, -618.0),
		Vector3(-5.5, WATER_SURFACE_Y, -666.0),
		Vector3(6.5, WATER_SURFACE_Y, -714.0),
		Vector3(-2.5, WATER_SURFACE_Y, -762.0),
		Vector3(5.5, WATER_SURFACE_Y, -810.0),
		Vector3(-6.5, WATER_SURFACE_Y, -858.0),
		Vector3(3.5, WATER_SURFACE_Y, -906.0),
		Vector3(-2.0, WATER_SURFACE_Y, -954.0),
		Vector3(2.0, WATER_SURFACE_Y, -990.0),
		Vector3(0.0, WATER_SURFACE_Y, -1020.0),
		Vector3(0.0, WATER_SURFACE_Y, LONG_FINISH_Z),
	]

func _build_checkpoint_positions() -> Array[Vector3]:
	return [
		Vector3(3.5, WATER_SURFACE_Y, 182.0),
		Vector3(2.0, WATER_SURFACE_Y, 108.0),
		Vector3(-4.0, WATER_SURFACE_Y, 34.0),
		Vector3(-5.0, WATER_SURFACE_Y, -82.0),
		Vector3(-3.5, WATER_SURFACE_Y, -202.0),
		Vector3(-6.0, WATER_SURFACE_Y, -378.0),
		Vector3(-7.5, WATER_SURFACE_Y, -570.0),
		Vector3(-2.5, WATER_SURFACE_Y, -762.0),
		Vector3(3.5, WATER_SURFACE_Y, -906.0),
		Vector3(2.0, WATER_SURFACE_Y, -990.0),
	]

func _build_water_world() -> void:
	var center_z := (COURSE_START_Z + LONG_FINISH_Z) * 0.5
	var course_length := absf(COURSE_START_Z - LONG_FINISH_Z) + 56.0
	create_box("ContinuousWaterSurface", Vector3(0.0, -0.18, center_z), Vector3(COURSE_HALF_WIDTH * 2.0, 0.24, course_length), Color(0.04, 0.63, 0.77), false)
	create_box("RiverBed", Vector3(0.0, -4.2, center_z), Vector3(COURSE_HALF_WIDTH * 2.0, 0.55, course_length), Color(0.08, 0.24, 0.30), true)
	create_box("WestRiverBank", Vector3(-COURSE_HALF_WIDTH - 0.55, -0.2, center_z), Vector3(1.1, 8.0, course_length), Color(0.18, 0.31, 0.22), true)
	create_box("EastRiverBank", Vector3(COURSE_HALF_WIDTH + 0.55, -0.2, center_z), Vector3(1.1, 8.0, course_length), Color(0.18, 0.31, 0.22), true)
	create_box("StartWaterBoundary", Vector3(0.0, -0.4, COURSE_MAX_Z), Vector3(COURSE_HALF_WIDTH * 2.0, 7.0, 1.0), Color(0.15, 0.28, 0.24), true)
	create_box("FinishWaterRunoutBoundary", Vector3(0.0, -0.4, LONG_MIN_Z), Vector3(COURSE_HALF_WIDTH * 2.0, 7.0, 1.0), Color(0.15, 0.28, 0.24), true)
	print("WILD CURRENT PHASE3 LONG WATER length=%.1f width=%.1f checkpoints=%d target_track=1.3km land_requirement=false" % [
		course_length, COURSE_HALF_WIDTH * 2.0, _checkpoint_positions.size(),
	])

func _build_currents() -> void:
	super()
	_add_current("DriftwoodCrossCurrent", Vector3(7.0, WATER_SURFACE_Y, -382.0), Vector3(-0.42, 0.0, -1.0), 1.55, 10.0, 96.0, &"CROSS")
	_add_current("StoneFastRight", Vector3(8.0, WATER_SURFACE_Y, -510.0), Vector3(-0.03, 0.0, -1.0), 2.05, 7.0, 104.0, &"FAST")
	_add_current("StoneSafeCenter", Vector3(0.0, WATER_SURFACE_Y, -520.0), Vector3(0.0, 0.0, -1.0), 0.82, 8.0, 112.0, &"NORMAL")
	_add_current("MangroveFastLeft", Vector3(-8.0, WATER_SURFACE_Y, -668.0), Vector3(0.06, 0.0, -1.0), 2.12, 7.0, 118.0, &"FAST")
	_add_current("StormRapidCenter", Vector3(0.0, WATER_SURFACE_Y, -822.0), Vector3(0.0, 0.0, -1.0), 3.05, 18.0, 132.0, &"RAPID")
	_add_current("StormSafeLeft", Vector3(-10.0, WATER_SURFACE_Y, -824.0), Vector3(0.02, 0.0, -1.0), 1.25, 6.5, 126.0, &"NORMAL")
	_add_current("LongFinalFastCenter", Vector3(0.0, WATER_SURFACE_Y, -978.0), Vector3(0.0, 0.0, -1.0), 1.86, 10.0, 122.0, &"FAST")
	print("WILD CURRENT PHASE3 CURRENT NETWORK extended_z=-340..-1040 safe_fast_risk=true")

func _build_whirlpools() -> void:
	super()
	_add_whirlpool("WhirlpoolDriftwood", Vector3(-9.0, WATER_SURFACE_Y, -442.0), 6.8, 4.0)
	_add_whirlpool("WhirlpoolMangrove", Vector3(9.0, WATER_SURFACE_Y, -676.0), 7.3, 4.5)
	_add_whirlpool("WhirlpoolStorm", Vector3(-7.5, WATER_SURFACE_Y, -842.0), 7.0, 4.3)

func _build_basic_hazards() -> void:
	super()
	_add_floating_log("LongLogC", Vector3(2.0, 1.65, -352.0), Vector3(13.0, 1.0, 2.2))
	_add_floating_log("LongLogD", Vector3(-5.0, 1.65, -438.0), Vector3(10.5, 1.0, 2.2))
	_add_floating_log("LongLogE", Vector3(6.0, 1.65, -548.0), Vector3(12.0, 1.0, 2.2))
	_add_floating_log("LongLogF", Vector3(-4.0, 1.65, -646.0), Vector3(11.5, 1.0, 2.2))
	_add_floating_log("LongLogG", Vector3(3.0, 1.65, -742.0), Vector3(14.0, 1.0, 2.2))
	_add_floating_log("LongLogH", Vector3(-6.0, 1.65, -836.0), Vector3(10.0, 1.0, 2.2))
	_add_floating_log("LongLogI", Vector3(4.0, 1.65, -930.0), Vector3(12.5, 1.0, 2.2))

	_add_rock("LongRockD", Vector3(-8.0, -0.2, -392.0), 2.1)
	_add_rock("LongRockE", Vector3(8.5, -0.2, -486.0), 2.3)
	_add_rock("LongRockF", Vector3(-2.0, -0.2, -590.0), 2.0)
	_add_rock("LongRockG", Vector3(9.0, -0.2, -704.0), 2.4)
	_add_rock("LongRockH", Vector3(-9.0, -0.2, -792.0), 2.0)
	_add_rock("LongRockI", Vector3(7.0, -0.2, -888.0), 2.2)

	_add_reed_cluster("LongReedsWestA", Vector3(-12.0, 0.4, -462.0))
	_add_reed_cluster("LongReedsEastA", Vector3(12.0, 0.4, -612.0))
	_add_reed_cluster("LongReedsWestB", Vector3(-12.5, 0.4, -770.0))
	_add_reed_cluster("LongReedsEastB", Vector3(12.0, 0.4, -914.0))

	_add_floating_debris("LongDebrisD", Vector3(7.0, WATER_SURFACE_Y + 0.08, -410.0), Vector3(1.3, 0.14, 0.8))
	_add_floating_debris("LongDebrisE", Vector3(-6.0, WATER_SURFACE_Y + 0.08, -602.0), Vector3(1.5, 0.14, 0.7))
	_add_floating_debris("LongDebrisF", Vector3(4.0, WATER_SURFACE_Y + 0.08, -804.0), Vector3(1.2, 0.14, 0.8))
	_add_floating_debris("LongDebrisG", Vector3(-3.0, WATER_SURFACE_Y + 0.08, -948.0), Vector3(1.4, 0.14, 0.7))

	_build_item_box_stations()
	_build_leader_wave_gates()
	print("WILD CURRENT PHASE3 BATTLE FIELD item_boxes=%d item_stations=%d moving_logs=%d rocks_total=9 reeds_total=6 whirlpools=%d leader_wave_gates=%d" % [
		_phase3_item_boxes.size(), ITEM_STATION_Z.size(), _moving_logs.size(), _whirlpools.size(), _leader_wave_gates.size(),
	])

func _attach_swimmer(racer: WildDashCharacterController, is_player_swimmer: bool, lane: float) -> void:
	if racer == null:
		return
	var swimmer := PHASE3_SWIMMER_SCRIPT.new() as WildCurrentSwimmerPhase3
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

func _build_item_box_stations() -> void:
	for station_index in range(ITEM_STATION_Z.size()):
		var station_z := ITEM_STATION_Z[station_index]
		var lane_shift := 1.4 if station_index % 2 == 1 else -1.4
		for lane_index in range(ITEM_STATION_LANES.size()):
			var box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "R5BattleItem_S%02d_L%d" % [station_index + 1, lane_index + 1]
			box.position = Vector3(ITEM_STATION_LANES[lane_index] + lane_shift, WATER_SURFACE_Y + 1.05, station_z)
			box.respawn_seconds = 4.2
			box.configure_pickup_profile(0.82, 0.82, 520, true, 1.85)
			add_child(box)
			_phase3_item_boxes.append(box)
	print("r5_item_box_network stations=%d boxes=%d lanes=3 weighted_by_rank=true comeback_items=true replace_player=true" % [
		ITEM_STATION_Z.size(), _phase3_item_boxes.size(),
	])

func _build_leader_wave_gates() -> void:
	_add_leader_wave_gate("LeaderWaveA", -108.0, 1.0)
	_add_leader_wave_gate("LeaderWaveB", -338.0, -1.0)
	_add_leader_wave_gate("LeaderWaveC", -548.0, 1.0)
	_add_leader_wave_gate("LeaderWaveD", -754.0, -1.0)
	_add_leader_wave_gate("LeaderWaveE", -918.0, 1.0)
	print("r5_leader_wave_network gates=%d visible=true leader_only=true one_shot_per_gate=true teleport=false" % _leader_wave_gates.size())

func _add_leader_wave_gate(name_text: String, z_value: float, push_sign: float) -> void:
	var gate_index := _leader_wave_gates.size()
	create_box("%s_LeftBeacon" % name_text, Vector3(-10.5, 2.8, z_value), Vector3(0.7, 5.6, 0.7), Color(0.95, 0.30, 0.12), false)
	create_box("%s_RightBeacon" % name_text, Vector3(10.5, 2.8, z_value), Vector3(0.7, 5.6, 0.7), Color(0.95, 0.30, 0.12), false)
	create_box("%s_WaveBar" % name_text, Vector3(0.0, 5.7, z_value), Vector3(21.0, 0.34, 0.42), Color(1.0, 0.63, 0.12), false)
	_leader_wave_gates.append({
		"index": gate_index,
		"name": name_text,
		"z": z_value,
		"direction": Vector3(push_sign, 0.0, -0.10).normalized(),
	})

func _update_leader_wave_gates() -> void:
	if not RaceManager.active or _leader_wave_gates.is_empty():
		return
	var leader := _current_unfinished_leader()
	if leader == null:
		return
	for gate in _leader_wave_gates:
		var gate_index := int(gate.get("index", -1))
		if gate_index < 0 or _leader_wave_triggered.has(gate_index):
			continue
		var gate_z := float(gate.get("z", 99999.0))
		if absf(leader.global_position.z - gate_z) > LEADER_WAVE_TRIGGER_HALF_DEPTH:
			continue
		var driver := _swimmers.get(leader.get_instance_id(), null) as WildCurrentSwimmerPhase2
		if driver == null:
			continue
		var push_direction: Vector3 = gate.get("direction", Vector3.RIGHT)
		if driver.apply_water_combat_push(push_direction, LEADER_WAVE_POWER, LEADER_WAVE_RETENTION):
			_leader_wave_triggered[gate_index] = true
			print("r5_leader_wave_trigger gate=%s leader=%s rank=1 power=%.2f retention=%.2f visible=true teleport=false" % [
				str(gate.get("name", "LeaderWave")), RaceManager.get_racer_label(leader), LEADER_WAVE_POWER, LEADER_WAVE_RETENTION,
			])

func _current_unfinished_leader() -> WildDashCharacterController:
	for racer_node in RaceManager.racers:
		var racer := racer_node as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		if RaceManager.get_rank(racer) == 1:
			return racer
	return null

func should_ai_use_item_phase3(racer: WildDashCharacterController) -> bool:
	if racer == null or racer.finished or racer.get_held_item() == &"":
		return false
	var item_id := racer.get_held_item()
	var role := ItemSystem.get_role(item_id)
	if role in [&"speed", &"defense", &"recovery", &"utility"]:
		return true
	var own_progress := RaceManager.get_track_progress(racer)
	for other_node in RaceManager.racers:
		var other := other_node as WildDashCharacterController
		if other == null or other == racer or other.finished:
			continue
		if absf(RaceManager.get_track_progress(other) - own_progress) <= 16.0:
			return true
	return RaceManager.get_rank(racer) >= maxi(4, RaceManager.racers.size() / 2)

func should_ai_burst_phase2(racer: WildDashCharacterController, pack_role: StringName, timing_skill: float, burst_clock: float) -> bool:
	if racer == null:
		return false
	var progress_gap := 0.0
	if player != null and is_instance_valid(player):
		progress_gap = RaceManager.get_track_progress(player) - RaceManager.get_track_progress(racer)
	var current := current_label_at(racer.global_position)
	if racer.global_position.z <= LONG_FINAL_SPRINT_Z:
		return timing_skill >= 0.58 and burst_clock >= lerpf(4.6, 3.1, timing_skill)
	if pack_role == &"LEAD" and progress_gap > 10.0:
		return burst_clock >= lerpf(5.2, 4.0, timing_skill)
	if current in [&"FAST", &"RAPID"] and timing_skill >= 0.62:
		return burst_clock >= lerpf(6.6, 4.8, timing_skill)
	return false

func _update_final_sprint_state() -> void:
	if not RaceManager.active:
		return
	for racer_node in RaceManager.racers:
		var racer := racer_node as WildDashCharacterController
		if racer == null or racer.finished or racer.global_position.z > LONG_FINAL_SPRINT_Z:
			continue
		var id := racer.get_instance_id()
		if _final_sprint_seen.has(id):
			continue
		_final_sprint_seen[id] = true
		print("r5_final_sprint_enter racer=%s rank=%d progress=%.1f phase3_long=true" % [
			RaceManager.get_racer_label(racer), RaceManager.get_rank(racer), RaceManager.get_progress_percent(racer),
		])
		if racer == player:
			emit_swim_audio(player, &"final_sprint")
			var pack_count := _count_nearby_finish_competitors(player, FINISH_PACK_DISTANCE)
			print("r5_finish_pack_count phase=final_sprint count=%d target_min=2 recommended=3_4 distance=%.1f teleport=false" % [
				pack_count, FINISH_PACK_DISTANCE,
			])

func _update_phase2_hud() -> void:
	if hud == null or player == null or not _phase2_ready:
		return
	var zone := _zone_name_for_position(player.global_position)
	var current := current_label_at(player.global_position)
	var current_text := "OPEN WATER" if current == &"" else String(current)
	if player.global_position.z <= LONG_FINAL_SPRINT_Z:
		hud.set_message("FINAL RIVER BATTLE · Q/B ITEM · BURST + DRAFT · LEADER WAVE AHEAD")
	else:
		hud.set_message("%s · CURRENT %s · Q/B ITEM · SAFE / FAST / RISK" % [zone, current_text])

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
	if player.global_position.z <= LONG_FINAL_SPRINT_Z:
		target_fov += 0.8
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 3.6, 0.0, 1.0))

func _strategic_lane_x(zone: String, choice: StringName, base_lane: float, racer: WildDashCharacterController) -> float:
	match zone:
		"DRIFTWOOD GAUNTLET":
			if choice == &"RISK": return 7.5
			if choice == &"FAST": return 0.0
			return -9.0
		"STONE SLALOM":
			if choice == &"RISK": return -8.0
			if choice == &"FAST": return 8.0
			return 0.0
		"MANGROVE MAZE":
			if choice == &"RISK": return 8.5
			if choice == &"FAST": return -8.0
			return 0.0
		"STORM CHANNEL":
			if choice == &"RISK": return 0.0
			if choice == &"FAST": return 7.0
			return -10.0
		"FINAL BATTLE SPRINT":
			if choice == &"RISK": return -6.5
			if choice == &"FAST": return 0.0
			return 6.0
		_:
			return super(zone, choice, base_lane, racer)

func _build_finish_gate() -> void:
	var finish_position := Vector3(0.0, WATER_SURFACE_Y, LONG_FINISH_Z)
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
	for x in [-7.5, 7.5]:
		create_box("LongFinalSightBeacon_%s" % ("L" if x < 0.0 else "R"), finish_position + Vector3(x, 5.2, 0.0), Vector3(0.68, 10.2, 0.68), Color(1.0, 0.78, 0.12), false)
	create_box("LongFinalSightCrossbar", finish_position + Vector3(0.0, 9.7, 0.0), Vector3(15.0, 0.42, 0.45), Color(1.0, 0.78, 0.12), false)
	print("WILD CURRENT PHASE3 FINAL GATE z=%.1f sightline=true final_sprint_z=%.1f obstacle_density=low" % [LONG_FINISH_Z, LONG_FINAL_SPRINT_Z])

func _on_player_finished(rank: int) -> void:
	_player_rank = rank
	var finish_pack := _count_nearby_finish_competitors(player, 42.0)
	print("r5_finish_pack_count phase=finish count=%d target=2_4 teleport=false phase3_long=true" % finish_pack)
	if not GameManager.campaign_running:
		_promote_direct_round5_to_campaign_final()
	var elapsed := RaceManager.get_elapsed_seconds()
	finish_mode(true, rank, {
		"rank": rank,
		"racers": RaceManager.racers.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"player_finish_seconds": elapsed,
		"round5_rebuild": "wild_current_phase3_long_battle",
		"water_only": true,
		"finish_pack_count": finish_pack,
		"competitive_swimming": true,
		"item_battle": true,
		"leader_wave_gates": _leader_wave_gates.size(),
	})

func _is_invalid_water_position(position_value: Vector3) -> bool:
	return absf(position_value.x) > COURSE_HALF_WIDTH + 5.0 \
		or position_value.z > COURSE_MAX_Z + 4.0 \
		or position_value.z < LONG_MIN_Z - 4.0 \
		or position_value.y < -5.3 \
		or position_value.y > 5.2

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
	if position_value.z > -430.0:
		return "DRIFTWOOD GAUNTLET"
	if position_value.z > -590.0:
		return "STONE SLALOM"
	if position_value.z > -750.0:
		return "MANGROVE MAZE"
	if position_value.z > -900.0:
		return "STORM CHANNEL"
	return "FINAL BATTLE SPRINT"
