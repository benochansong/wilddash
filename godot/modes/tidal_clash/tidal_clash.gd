extends WildDashModeController

const ITEM_BOX_SCENE: PackedScene = preload("res://items/item_box.tscn")
const CHASE_CAMERA_SCRIPT: Script = preload("res://camera/chase_camera.gd")

const ITEM_STATION_PROGRESS: Array[float] = [
	0.08, 0.16, 0.25, 0.34, 0.43, 0.52, 0.61, 0.70, 0.78, 0.85, 0.91, 0.96, 0.985,
]
const START_GRID_COLUMNS: int = 5
const START_GRID_X_SPACING: float = 3.55
const START_GRID_Z_SPACING: float = 4.10
const FINISH_RUNOUT_DISTANCE: float = 15.0
const TARGET_MIN_TRACK_LENGTH: float = 1500.0
const TARGET_MAX_TRACK_LENGTH: float = 1700.0

var _track: WildDashTidalClashTrack
var _route_points: Array[Vector3] = []
var _item_boxes: Array[WildDashItemBox] = []
var _player_rank: int = 0
var _finish_times: Array[float] = []
var _fps_sum: float = 0.0
var _fps_samples: int = 0
var _headless_progress_elapsed: float = 0.0

func _ready() -> void:
	setup_mode(
		&"tidal_clash",
		"ROUND 5 — TIDAL CLASH",
		"W/↑ 가속 · A/D 조향 · Space 파도 점프 · E/X 스킬 · Q/B 아이템 · 100% WATER BATTLE RACE",
		false,
	)
	var legacy_sun: DirectionalLight3D = get_node_or_null("Sun") as DirectionalLight3D
	if legacy_sun != null:
		legacy_sun.visible = false
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()

	_track = get_node_or_null("TidalClashTrack") as WildDashTidalClashTrack
	if _track == null:
		push_error("TIDAL CLASH missing TidalClashTrack")
		return
	# Child track _ready() already configured RaceManager before this root _ready.
	_route_points = _track.get_route_points()
	if _route_points.size() < 2:
		push_error("TIDAL CLASH route unavailable")
		return
	if RaceManager.get_track_length() <= 0.01:
		RaceManager.configure_track(_route_points, _track.get_checkpoint_positions())

	var start: Vector3 = _track.get_start_position()
	player = spawn_racer(
		"Player",
		&"dog",
		start + _get_start_grid_offset(0),
		true,
		WildDashCharacterController.MovementMode.RACE
	)
	_mark_water_racer(player)

	var ai_total: int = GameManager.ai_count
	for index: int in range(ai_total):
		var spawn_position: Vector3 = start + _get_start_grid_offset(index + 1)
		var racer: WildDashCharacterController = spawn_racer(
			"AI_%02d" % (index + 1),
			&"dog",
			spawn_position,
			false,
			WildDashCharacterController.MovementMode.RACE
		)
		_mark_water_racer(racer)
		var lane: float = _start_lane_for_slot(index + 1)
		var speed: float = _ai_target_speed(racer, index)
		var driver: WildDashAIController = spawn_ai_driver(
			racer,
			WildDashAIController.AIMode.RACE,
			speed,
			lane,
			0.13
		)
		driver.steering_strength = 6.9 if not _is_light(racer.animal_id) else 7.5
		driver.acceleration = 24.5 if not _is_light(racer.animal_id) else 26.0
		driver.avoidance_distance = 9.2
		driver.set_race_route(_build_race_route_with_runout())

	_spawn_item_boxes()

	var headless: bool = DisplayServer.get_name() == "headless"
	if headless and player != null:
		var test_driver: WildDashAIController = spawn_ai_driver(
			player,
			WildDashAIController.AIMode.RACE,
			maxf(30.0, player.max_speed * 2.05),
			0.0,
			0.0,
			true
		)
		test_driver.steering_strength = 11.5
		test_driver.acceleration = 78.0
		test_driver.avoidance_distance = 8.0
		test_driver.set_race_route(_build_race_route_with_runout())

	var camera: Camera3D = CHASE_CAMERA_SCRIPT.new() as Camera3D
	if camera != null:
		camera.name = "ChaseCamera"
		camera.current = true
		camera.fov = 72.0
		add_child(camera)
		camera.call("set_target", player)

	if not RaceManager.racer_finished.is_connected(_on_any_racer_finished):
		RaceManager.racer_finished.connect(_on_any_racer_finished)
	if not RaceManager.race_finished.is_connected(_on_player_finished):
		RaceManager.race_finished.connect(_on_player_finished)
	if not RaceManager.race_completed.is_connected(_on_race_completed):
		RaceManager.race_completed.connect(_on_race_completed)

	# Let water profile, hazard, combat AI and camera adapters discover the shared
	# racers/drivers before the race goes live.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not headless:
		await get_tree().create_timer(0.75).timeout

	GameManager.begin_round(&"tidal_clash")
	RaceManager.start_race()
	var track_length: float = RaceManager.get_track_length()
	print("TIDAL CLASH READY")
	print("track_length=%.1f" % track_length)
	print("water_ratio=100%")
	print("stations=%d" % ITEM_STATION_PROGRESS.size())
	print("race_combat_v3=true")
	print("party_item_boxes=true")
	print("TIDAL CLASH SECTIONS count=5 launch=%.1fm wave_field=%.1fm whirlpool=%.1fm combat_sea=%.1fm final_sprint=%.1fm widths=30/27/28/38/34" % [
		track_length * 0.18,
		track_length * 0.20,
		track_length * 0.20,
		track_length * 0.24,
		track_length * 0.18,
	])
	if track_length < TARGET_MIN_TRACK_LENGTH or track_length > TARGET_MAX_TRACK_LENGTH:
		push_warning("TIDAL CLASH length validation failed target=1500..1700 actual=%.1f" % track_length)

func _process(_delta: float) -> void:
	if player == null or hud == null:
		return
	var fps: int = int(Engine.get_frames_per_second())
	if fps > 0:
		_fps_sum += float(fps)
		_fps_samples += 1
	var rank: int = RaceManager.get_rank(player)
	var checkpoint_progress: int = RaceManager.get_checkpoint_progress(player)
	var progress_percent: float = RaceManager.get_progress_percent(player)
	var section: String = _section_name(progress_percent * 0.01)
	hud.set_metrics("Rank %d / %d   CP %d/%d   %s   Progress %d%%   Speed %.1f   FPS %d" % [
		rank,
		RaceManager.racers.size(),
		checkpoint_progress,
		RaceManager.get_checkpoint_count(),
		section,
		roundi(progress_percent),
		player.current_speed,
		fps,
	])
	hud.set_item_state(ItemSystem.get_display_name(player.get_held_item()), ItemSystem.get_status_text(player))

func _physics_process(delta: float) -> void:
	if RaceManager.active:
		for value: Variant in RaceManager.racers.duplicate():
			var racer: WildDashCharacterController = value as WildDashCharacterController
			if racer == null or not is_instance_valid(racer):
				continue
			RaceManager.sync_checkpoint_from_position(racer)
			RaceManager.sync_finish_from_position(racer)
			if racer.global_position.y < -12.0 and not racer.finished:
				racer.reset_motion(RaceManager.get_respawn_position(racer))
				_orient_to_route(racer)
	if DisplayServer.get_name() != "headless" or not RaceManager.active:
		return
	_headless_progress_elapsed += delta
	if _headless_progress_elapsed < 5.0:
		return
	_headless_progress_elapsed = 0.0
	print("TIDAL CLASH PROGRESS finishers=%d/%d player=%.0f%% section=%s" % [
		RaceManager.finish_order.size(),
		RaceManager.racers.size(),
		RaceManager.get_progress_percent(player),
		_section_name(RaceManager.get_progress_percent(player) * 0.01),
	])

func _spawn_item_boxes() -> void:
	if _track == null:
		return
	for station_progress: float in ITEM_STATION_PROGRESS:
		var center: Vector3 = _track.sample_route(station_progress)
		var right: Vector3 = _track.route_right(station_progress)
		var width: float = _track.get_width_at_progress(station_progress)
		var lane_offsets: Array[float] = _lane_offsets_for_station(station_progress, width)
		for lane_offset: float in lane_offsets:
			var box: WildDashItemBox = ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "TidalItem_P%04d_L%s" % [
				roundi(station_progress * 1000.0),
				str(lane_offset).replace("-", "N").replace(".", "_"),
			]
			box.position = center + right * lane_offset + Vector3.UP * 1.25
			# Legacy fallback only; race pickup is racer-specific in RC9.
			box.respawn_seconds = 4.0
			add_child(box)
			_item_boxes.append(box)
	print("TIDAL CLASH PARTY ITEMS READY stations=%d boxes=%d distance_sampled=true progresses=%s party_pickup=true one_slot=true" % [
		ITEM_STATION_PROGRESS.size(), _item_boxes.size(), str(ITEM_STATION_PROGRESS),
	])

func _lane_offsets_for_station(progress: float, width: float) -> Array[float]:
	if progress >= 0.58 and progress < 0.82 and width >= 34.0:
		return [-8.0, -2.7, 2.7, 8.0]
	if width >= 26.0:
		return [-6.0, -2.0, 2.0, 6.0]
	if width >= 22.0:
		return [-5.0, -1.7, 1.7, 5.0]
	return [-3.5, 0.0, 3.5]

func _build_race_route_with_runout() -> Array[Vector3]:
	var route: Array[Vector3] = _route_points.duplicate()
	if _route_points.size() < 2:
		return route
	var finish: Vector3 = _route_points[-1]
	var previous: Vector3 = _route_points[-2]
	var direction: Vector3 = finish - previous
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		route.append(finish + direction.normalized() * FINISH_RUNOUT_DISTANCE)
	return route

func _get_start_grid_offset(slot: int) -> Vector3:
	var row: int = slot / START_GRID_COLUMNS
	var column: int = slot % START_GRID_COLUMNS
	var center: float = float(START_GRID_COLUMNS - 1) * 0.5
	var stagger: float = 0.72 if row % 2 == 1 else 0.0
	return Vector3((float(column) - center) * START_GRID_X_SPACING + stagger, 0.15, float(row) * START_GRID_Z_SPACING)

func _start_lane_for_slot(slot: int) -> float:
	var column: int = slot % START_GRID_COLUMNS
	return (float(column) - 2.0) * 2.15

func _ai_target_speed(racer: WildDashCharacterController, slot: int) -> float:
	if racer == null:
		return 14.0
	var definition: WildDashAnimalDefinition = WildDashAnimalCatalog.get_definition(racer.animal_id)
	var canonical: float = racer.max_speed
	if definition != null and definition.max_speed > 0.01:
		canonical = definition.max_speed
	var water_scale: float = _round5_water_multiplier(racer.animal_id)
	var slot_scale: float = 1.0 - float(slot % 5) * 0.006
	return canonical * water_scale * 1.035 * slot_scale

func _round5_water_multiplier(animal_id: StringName) -> float:
	match animal_id:
		&"crocodile": return 1.09
		&"raccoon": return 1.02
		&"bear": return 1.01
		&"elephant": return 1.00
		&"boar", &"wolf": return 0.99
		&"dog": return 1.00
		&"deer", &"fox": return 0.98
		&"monkey", &"cat": return 0.97
		&"rabbit": return 0.96
		_: return 0.99

func _is_light(animal_id: StringName) -> bool:
	return animal_id in [&"rabbit", &"cat", &"fox"]

func _mark_water_racer(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	# Immediate marker lets existing Turbo/FX code treat Round 5 as water even
	# before the deferred world-profile adapter runs.
	racer.set_meta(&"wild_tide_terrain", WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER)
	racer.set_meta(&"tidal_clash_water", true)

func _orient_to_route(racer: WildDashCharacterController) -> void:
	if racer == null or _track == null:
		return
	var progress: float = RaceManager.get_progress_percent(racer) * 0.01
	var direction: Vector3 = _track.route_direction(progress)
	racer.rotation.y = atan2(-direction.x, -direction.z)

func _section_name(progress: float) -> String:
	if progress < 0.18:
		return "OCEAN LAUNCH"
	if progress < 0.38:
		return "WAVE FIELD"
	if progress < 0.58:
		return "WHIRLPOOL BASIN"
	if progress < 0.82:
		return "COMBAT SEA"
	return "FINAL TIDAL SPRINT"

func _on_any_racer_finished(_racer: Node3D, _rank: int) -> void:
	_finish_times.append(RaceManager.get_elapsed_seconds())

func _on_player_finished(rank: int) -> void:
	_player_rank = rank
	var elapsed: float = RaceManager.get_elapsed_seconds()
	print("TIDAL CLASH PLAYER FINISH rank=%d elapsed=%.2fs" % [rank, elapsed])
	if DisplayServer.get_name() == "headless":
		return
	_finish_round_result()

func _on_race_completed() -> void:
	if _player_rank <= 0 and player != null:
		var index: int = RaceManager.finish_order.find(player)
		if index >= 0:
			_player_rank = index + 1
	var average_finish: float = 0.0
	for finish_time: float in _finish_times:
		average_finish += finish_time
	if not _finish_times.is_empty():
		average_finish /= float(_finish_times.size())
	var average_fps: float = 0.0 if _fps_samples == 0 else _fps_sum / float(_fps_samples)
	print("TIDAL CLASH COMPLETE racers=%d finishers=%d average_finish=%.2fs field_complete=%.2fs fps=%.1f" % [
		RaceManager.racers.size(),
		RaceManager.finish_order.size(),
		average_finish,
		RaceManager.get_elapsed_seconds(),
		average_fps,
	])
	_finish_round_result(average_finish, average_fps)

func _finish_round_result(average_finish: float = 0.0, average_fps: float = 0.0) -> void:
	if mode_finished:
		return
	var racers_total: int = RaceManager.racers.size()
	var qualifying_rank: int = ceili(float(maxi(1, racers_total)) * 0.5)
	var success: bool = _player_rank > 0 and _player_rank <= qualifying_rank
	finish_mode(success, _player_rank, {
		"rank": _player_rank,
		"racers": racers_total,
		"finishers": RaceManager.finish_order.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"water_ratio": 1.0,
		"item_stations": ITEM_STATION_PROGRESS.size(),
		"item_boxes": _item_boxes.size(),
		"average_finish_seconds": average_finish,
		"field_complete_seconds": RaceManager.get_elapsed_seconds(),
		"average_fps": average_fps,
		"mode_identity": "100% WATER PARTY RACING BATTLE",
	})
