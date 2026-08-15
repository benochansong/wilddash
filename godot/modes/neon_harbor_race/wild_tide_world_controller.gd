class_name WildDashWildTideWorldController
extends Node3D

## Runtime world layer for ROUND 3 — WILD TIDE: JUNGLE HARBOR.
##
## The previous Water/Jungle overhaul prompt was not present on the branch, so
## this controller supplies the missing foundation without deleting the proven
## Neon Harbor track: selected authoritative road bands become flooded gameplay
## terrain, jungle dressing is added around the middle race, and dynamic tide /
## whirlpool / wake systems sit on top of the same checkpoint-safe route.

const BASE_WATER_SEGMENTS: Array[int] = [5, 6, 7, 8, 9, 10, 11, 16, 17, 18, 19, 20]
const DEEP_WATER_SEGMENTS: Array[int] = [7, 8, 9, 17, 18, 19]
const TIDE_PHASE_ONE_SEGMENTS: Array[int] = [13, 14]
const TIDE_PHASE_TWO_SEGMENTS: Array[int] = [15]
const JUNGLE_SEGMENTS: Array[int] = [8, 9, 10, 11, 12, 13, 14, 15]
const WATER_VISUAL_WIDTH: float = 18.0
const WATER_AREA_HEIGHT: float = 3.6
const TIDE_ONE_TRIGGER_PROGRESS: float = 0.52
const TIDE_TWO_TRIGGER_PROGRESS: float = 0.73
const HIGH_TIDE_COUNTDOWN: int = 5
const WHIRLPOOL_RADIUS: float = 7.5
const WHIRLPOOL_PULL: float = 8.0
const WAKE_RADIUS: float = 6.2
const WAKE_ACCELERATION: float = 3.8

var _track: Node3D
var _route_points: Array[Vector3] = []
var _active_water_segments: Dictionary = {}
var _water_areas_by_segment: Dictionary = {}
var _water_visuals_by_segment: Dictionary = {}
var _water_membership_by_racer: Dictionary = {}
var _movement_base_by_racer: Dictionary = {}
var _whirlpool_centers: Array[Vector3] = []
var _boats: Array[Node3D] = []
var _boat_routes: Array[Dictionary] = []
var _elapsed: float = 0.0
var _tide_one_started: bool = false
var _tide_one_active: bool = false
var _tide_two_started: bool = false
var _tide_two_active: bool = false
var _bootstrapped: bool = false
var _water_distance: float = 0.0
var _track_distance: float = 0.0

func _ready() -> void:
	add_to_group("wild_tide_world")
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	for _attempt: int in range(40):
		var parent_node: Node = get_parent()
		if parent_node != null:
			_track = parent_node.get_node_or_null("NeonHarborWorldTrack") as Node3D
		if _track != null and _track.has_method("get_route_points"):
			break
		await get_tree().physics_frame
	if _track == null or not _track.has_method("get_route_points"):
		push_warning("WILD TIDE world bootstrap skipped: NeonHarborWorldTrack unavailable")
		return

	var route_value: Variant = _track.call("get_route_points")
	if not route_value is Array:
		push_warning("WILD TIDE route unavailable")
		return
	for point_value: Variant in route_value:
		if point_value is Vector3:
			_route_points.append(point_value as Vector3)
	if _route_points.size() < 3:
		return

	_build_flooded_world()
	_build_jungle_dressing()
	_build_elevated_dock_route()
	_build_whirlpools()
	_build_moving_boats()
	_build_safe_respawn_markers()
	_bootstrapped = true
	var water_ratio: float = 0.0 if _track_distance <= 0.01 else _water_distance / _track_distance
	print("WILD TIDE WORLD READY segments=%d baseline_water=%.1f%% jungle_segments=%d whirlpools=%d boats=%d checkpoint_route_preserved=true" % [
		_route_points.size() - 1,
		water_ratio * 100.0,
		JUNGLE_SEGMENTS.size(),
		_whirlpool_centers.size(),
		_boats.size(),
	])

func _physics_process(delta: float) -> void:
	if not _bootstrapped:
		return
	_elapsed += delta
	_update_high_tide()
	_update_whirlpools(delta)
	_update_boats(delta)
	_update_breakable_barriers()

func is_position_water(world_position: Vector3) -> bool:
	if _route_points.size() < 2:
		return false
	for raw_index: Variant in _active_water_segments.keys():
		var segment_index: int = int(raw_index)
		if segment_index < 0 or segment_index >= _route_points.size() - 1:
			continue
		var distance: float = _planar_distance_to_segment(
			world_position,
			_route_points[segment_index],
			_route_points[segment_index + 1]
		)
		if distance <= WATER_VISUAL_WIDTH * 0.58:
			return true
	return false

func get_baseline_water_ratio() -> float:
	return 0.0 if _track_distance <= 0.01 else _water_distance / _track_distance

func get_route_state() -> Dictionary:
	return {
		"baseline_water_ratio": get_baseline_water_ratio(),
		"high_tide_one": _tide_one_active,
		"high_tide_two": _tide_two_active,
		"active_water_segments": _active_water_segments.size(),
		"jungle_shortcut": get_tree().get_first_node_in_group("wild_tide_jungle_shortcut") != null,
	}

func _build_flooded_world() -> void:
	_track_distance = 0.0
	_water_distance = 0.0
	for segment_index: int in range(_route_points.size() - 1):
		var segment_length: float = _route_points[segment_index].distance_to(_route_points[segment_index + 1])
		_track_distance += segment_length
		if BASE_WATER_SEGMENTS.has(segment_index):
			_water_distance += segment_length
			_create_water_segment(segment_index, DEEP_WATER_SEGMENTS.has(segment_index), true)
		elif TIDE_PHASE_ONE_SEGMENTS.has(segment_index) or TIDE_PHASE_TWO_SEGMENTS.has(segment_index):
			_create_water_segment(segment_index, false, false)

func _create_water_segment(segment_index: int, deep: bool, active: bool) -> void:
	if segment_index < 0 or segment_index >= _route_points.size() - 1:
		return
	var a: Vector3 = _route_points[segment_index]
	var b: Vector3 = _route_points[segment_index + 1]
	var length: float = a.distance_to(b)
	var midpoint: Vector3 = a.lerp(b, 0.5)
	var visual: CSGBox3D = CSGBox3D.new()
	visual.name = "WildTideWater_%02d" % segment_index
	visual.size = Vector3(WATER_VISUAL_WIDTH, 0.10, maxf(1.0, length - 0.5))
	visual.use_collision = false
	visual.position = midpoint + Vector3.UP * (0.13 if active else -0.82)
	visual.material = _water_material(deep)
	visual.look_at(b + Vector3.UP * visual.position.y, Vector3.UP)
	add_child(visual)
	_water_visuals_by_segment[segment_index] = visual

	var area: Area3D = Area3D.new()
	area.name = "WildTideWaterArea_%02d" % segment_index
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = active
	area.monitorable = false
	area.position = midpoint + Vector3.UP * 1.20
	area.look_at(b + Vector3.UP * area.position.y, Vector3.UP)
	area.set_meta(&"wild_tide_terrain", WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER if deep else WildDashTerrainAbilitySystem.TERRAIN_SHALLOW_WATER)
	area.set_meta(&"wild_tide_segment", segment_index)
	area.add_to_group("wild_tide_water_zone")
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(WATER_VISUAL_WIDTH, WATER_AREA_HEIGHT, maxf(2.0, length - 0.4))
	shape_node.shape = box
	area.add_child(shape_node)
	area.body_entered.connect(_on_water_body_entered.bind(area))
	area.body_exited.connect(_on_water_body_exited.bind(area))
	add_child(area)
	_water_areas_by_segment[segment_index] = area
	if active:
		_active_water_segments[segment_index] = true

func _on_water_body_entered(body: Node, area: Area3D) -> void:
	var racer: WildDashCharacterController = body as WildDashCharacterController
	if racer == null or racer.finished:
		return
	var racer_id: int = racer.get_instance_id()
	var memberships: Dictionary = _water_membership_by_racer.get(racer_id, {}) as Dictionary
	var terrain_value: Variant = area.get_meta(&"wild_tide_terrain", WildDashTerrainAbilitySystem.TERRAIN_SHALLOW_WATER)
	memberships[area.get_instance_id()] = StringName(terrain_value)
	_water_membership_by_racer[racer_id] = memberships
	_refresh_racer_water_state(racer, memberships)

func _on_water_body_exited(body: Node, area: Area3D) -> void:
	var racer: WildDashCharacterController = body as WildDashCharacterController
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	var memberships: Dictionary = _water_membership_by_racer.get(racer_id, {}) as Dictionary
	memberships.erase(area.get_instance_id())
	if memberships.is_empty():
		_water_membership_by_racer.erase(racer_id)
		_restore_racer_movement(racer)
	else:
		_water_membership_by_racer[racer_id] = memberships
		_refresh_racer_water_state(racer, memberships)

func _refresh_racer_water_state(racer: WildDashCharacterController, memberships: Dictionary) -> void:
	if racer == null:
		return
	var terrain: StringName = WildDashTerrainAbilitySystem.TERRAIN_SHALLOW_WATER
	for value: Variant in memberships.values():
		if StringName(value) == WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER:
			terrain = WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER
			break
	var racer_id: int = racer.get_instance_id()
	if not _movement_base_by_racer.has(racer_id):
		_movement_base_by_racer[racer_id] = {
			"max_speed": racer.max_speed,
			"cruise_speed": racer.cruise_speed,
			"acceleration": racer.acceleration,
			"turn_speed": racer.turn_speed,
		}
	var base: Dictionary = _movement_base_by_racer[racer_id] as Dictionary
	var multiplier: float = WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(racer.animal_id, terrain)
	racer.max_speed = float(base.get("max_speed", racer.max_speed)) * multiplier
	racer.cruise_speed = float(base.get("cruise_speed", racer.cruise_speed)) * multiplier
	racer.acceleration = float(base.get("acceleration", racer.acceleration)) * lerpf(0.92, 1.12, clampf(multiplier, 0.80, 1.45) / 1.45)
	var turn_scale: float = 1.10 if racer.animal_id == &"crocodile" else clampf(1.0 + (multiplier - 1.0) * 0.35, 0.90, 1.08)
	racer.turn_speed = float(base.get("turn_speed", racer.turn_speed)) * turn_scale
	racer.set_meta(&"wild_tide_terrain", terrain)
	racer.set_meta(&"wild_tide_speed_multiplier", multiplier)
	if racer.is_player:
		_show_hud("WATER ROUTE!  %s %.2fx" % [String(racer.animal_id).to_upper(), multiplier])

func _restore_racer_movement(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	if not _movement_base_by_racer.has(racer_id):
		return
	var base: Dictionary = _movement_base_by_racer[racer_id] as Dictionary
	racer.max_speed = float(base.get("max_speed", racer.max_speed))
	racer.cruise_speed = float(base.get("cruise_speed", racer.cruise_speed))
	racer.acceleration = float(base.get("acceleration", racer.acceleration))
	racer.turn_speed = float(base.get("turn_speed", racer.turn_speed))
	racer.remove_meta(&"wild_tide_terrain")
	racer.remove_meta(&"wild_tide_speed_multiplier")
	_movement_base_by_racer.erase(racer_id)

func _build_jungle_dressing() -> void:
	var jungle_root: Node3D = Node3D.new()
	jungle_root.name = "WildTideMangroveJungle"
	add_child(jungle_root)
	var trunk_material: StandardMaterial3D = _simple_material(Color(0.16, 0.09, 0.04), 0.90)
	var leaf_material: StandardMaterial3D = _emissive_material(Color(0.04, 0.30, 0.13), Color(0.04, 0.75, 0.30), 0.22)
	var tree_index: int = 0
	for segment_index: int in JUNGLE_SEGMENTS:
		if segment_index < 0 or segment_index >= _route_points.size() - 1:
			continue
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var direction: Vector3 = b - a
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		for side: float in [-1.0, 1.0]:
			var t: float = 0.25 if tree_index % 2 == 0 else 0.70
			var lateral: float = 14.0 + float(tree_index % 4) * 2.4
			var base_position: Vector3 = a.lerp(b, t) + right * lateral * side
			var trunk_height: float = 7.0 + float(tree_index % 5) * 1.1
			var trunk: CSGCylinder3D = CSGCylinder3D.new()
			trunk.name = "MangroveTrunk_%02d" % tree_index
			trunk.radius = 0.85
			trunk.height = trunk_height
			trunk.sides = 8
			trunk.use_collision = false
			trunk.position = base_position + Vector3.UP * (trunk_height * 0.5)
			trunk.material = trunk_material
			jungle_root.add_child(trunk)
			var crown: CSGSphere3D = CSGSphere3D.new()
			crown.name = "MangroveCrown_%02d" % tree_index
			crown.radius = 3.6 + float(tree_index % 3) * 0.7
			crown.radial_segments = 10
			crown.rings = 6
			crown.use_collision = false
			crown.scale = Vector3(1.35, 0.72, 1.05)
			crown.position = base_position + Vector3.UP * (trunk_height + 1.0)
			crown.material = leaf_material
			jungle_root.add_child(crown)
			tree_index += 1

func _build_elevated_dock_route() -> void:
	# A short readable high route gives Cat/Rabbit/Monkey a flood escape without
	# replacing the authoritative checkpoint path below it.
	var root: Node3D = Node3D.new()
	root.name = "WildTideElevatedDockRoute"
	root.add_to_group("wild_tide_elevated_route")
	add_child(root)
	var material: StandardMaterial3D = _emissive_material(Color(0.18, 0.20, 0.22), Color(0.05, 0.82, 1.0), 0.30)
	for segment_index: int in [16, 17, 18]:
		if segment_index >= _route_points.size() - 1:
			continue
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var direction: Vector3 = b - a
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var offset_a: Vector3 = a + right * 9.5 + Vector3.UP * 2.8
		var offset_b: Vector3 = b + right * 9.5 + Vector3.UP * 2.8
		var platform: CSGBox3D = _segment_box("ElevatedDock_%02d" % segment_index, offset_a, offset_b, 4.2, 0.45, material, true)
		root.add_child(platform)

func _build_whirlpools() -> void:
	for segment_index: int in [8, 18]:
		if segment_index >= _route_points.size() - 1:
			continue
		var center: Vector3 = _route_points[segment_index].lerp(_route_points[segment_index + 1], 0.55) + Vector3.UP * 0.24
		_whirlpool_centers.append(center)
		var ring: CSGCylinder3D = CSGCylinder3D.new()
		ring.name = "WildTideWhirlpool_%02d" % segment_index
		ring.radius = WHIRLPOOL_RADIUS
		ring.height = 0.05
		ring.sides = 24
		ring.use_collision = false
		ring.position = center
		ring.material = _emissive_material(Color(0.02, 0.24, 0.34, 0.58), Color(0.08, 0.78, 1.0), 0.55)
		ring.add_to_group("wild_tide_whirlpool_visual")
		add_child(ring)

func _build_moving_boats() -> void:
	for segment_index: int in [6, 19]:
		if segment_index >= _route_points.size() - 1:
			continue
		var boat: Node3D = Node3D.new()
		boat.name = "WildTideWakeBoat_%02d" % segment_index
		add_child(boat)
		var hull: CSGBox3D = CSGBox3D.new()
		hull.size = Vector3(2.8, 0.75, 5.4)
		hull.use_collision = false
		hull.position.y = 0.45
		hull.material = _emissive_material(Color(0.10, 0.14, 0.18), Color(0.0, 0.70, 1.0), 0.28)
		boat.add_child(hull)
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		_boats.append(boat)
		_boat_routes.append({"a": a, "b": b, "phase": float(_boats.size() - 1) * 0.42})

func _build_safe_respawn_markers() -> void:
	for segment_index: int in [5, 11, 16, 20]:
		if segment_index >= _route_points.size():
			continue
		var marker: Marker3D = Marker3D.new()
		marker.name = "WildTideSafeRespawn_%02d" % segment_index
		marker.position = _route_points[segment_index] + Vector3.UP * 1.0
		marker.add_to_group("wild_tide_safe_respawn")
		add_child(marker)

func _update_high_tide() -> void:
	var player: WildDashCharacterController = _get_player()
	if player == null or player.finished or not RaceManager.active:
		return
	var progress: float = RaceManager.get_progress_percent(player) / 100.0
	if not _tide_one_started and progress >= TIDE_ONE_TRIGGER_PROGRESS:
		_tide_one_started = true
		_start_tide_countdown(1)
	if not _tide_two_started and progress >= TIDE_TWO_TRIGGER_PROGRESS:
		_tide_two_started = true
		_start_tide_countdown(2)

func _start_tide_countdown(phase: int) -> void:
	var timer_callable: Callable = func() -> void:
		for second: int in range(HIGH_TIDE_COUNTDOWN, 0, -1):
			_show_hud("HIGH TIDE INCOMING — %d" % second)
			AudioManager.play_sfx_id("wave", 0.55)
			await get_tree().create_timer(1.0).timeout
		_activate_tide_phase(phase)
	timer_callable.call()

func _activate_tide_phase(phase: int) -> void:
	var segments: Array[int] = TIDE_PHASE_ONE_SEGMENTS if phase == 1 else TIDE_PHASE_TWO_SEGMENTS
	for segment_index: int in segments:
		_activate_water_segment(segment_index)
	if phase == 1:
		_tide_one_active = true
	else:
		_tide_two_active = true
	_show_hud("FLOODED ROUTE!  HIGH TIDE PHASE %d" % phase)
	AudioManager.play_sfx_id("splash", 0.92)
	print("ROUND3 EVENT type=HIGH_TIDE phase=%d progress=%.1f active_water_segments=%d" % [
		phase,
		RaceManager.get_progress_percent(_get_player()),
		_active_water_segments.size(),
	])

func _activate_water_segment(segment_index: int) -> void:
	if _active_water_segments.has(segment_index):
		return
	_active_water_segments[segment_index] = true
	var area: Area3D = _water_areas_by_segment.get(segment_index) as Area3D
	if area != null:
		area.monitoring = true
	var visual: CSGBox3D = _water_visuals_by_segment.get(segment_index) as CSGBox3D
	if visual != null:
		var target_y: float = _route_points[segment_index].lerp(_route_points[segment_index + 1], 0.5).y + 0.13
		var tween: Tween = visual.create_tween()
		tween.tween_property(visual, "position:y", target_y, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_whirlpools(delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group("wild_tide_whirlpool_visual"):
		var visual: Node3D = node as Node3D
		if visual != null:
			visual.rotate_y(delta * 1.9)
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		for center: Vector3 in _whirlpool_centers:
			var planar: Vector3 = center - racer.global_position
			planar.y = 0.0
			var distance: float = planar.length()
			if distance <= 0.2 or distance > WHIRLPOOL_RADIUS:
				continue
			var resistance: float = WildDashTerrainAbilitySystem.get_wave_knockback_multiplier(racer.animal_id)
			var pull: float = (1.0 - distance / WHIRLPOOL_RADIUS) * WHIRLPOOL_PULL * resistance
			racer.velocity += planar.normalized() * pull * delta

func _update_boats(delta: float) -> void:
	for i: int in range(_boats.size()):
		if i >= _boat_routes.size():
			break
		var boat: Node3D = _boats[i]
		if boat == null:
			continue
		var route: Dictionary = _boat_routes[i]
		var a: Vector3 = route.get("a", Vector3.ZERO)
		var b: Vector3 = route.get("b", Vector3.ZERO)
		var phase: float = float(route.get("phase", 0.0))
		var t: float = (sin(_elapsed * 0.58 + phase * TAU) + 1.0) * 0.5
		boat.global_position = a.lerp(b, t) + Vector3.UP * 0.30
		var tangent: Vector3 = b - a
		tangent.y = 0.0
		if tangent.length_squared() > 0.001:
			boat.look_at(boat.global_position + tangent.normalized(), Vector3.UP)
		for racer_value: Variant in RaceManager.racers:
			var racer: WildDashCharacterController = racer_value as WildDashCharacterController
			if racer == null or racer.finished:
				continue
			if racer.global_position.distance_to(boat.global_position) <= WAKE_RADIUS:
				var current_multiplier: float = float(racer.get_meta(&"wild_tide_speed_multiplier", 1.0))
				if current_multiplier < 1.10:
					racer.current_speed = minf(racer.current_speed + WAKE_ACCELERATION * delta, racer.max_speed * 1.16)
					racer.set_meta(&"wild_tide_wake_boost", true)

func _update_breakable_barriers() -> void:
	for node: Node in get_tree().get_nodes_in_group("wild_tide_breakable"):
		var barrier: Node3D = node as Node3D
		if barrier == null:
			continue
		for racer_value: Variant in RaceManager.racers:
			var racer: WildDashCharacterController = racer_value as WildDashCharacterController
			if racer == null or racer.finished or racer.animal_id != &"elephant":
				continue
			if racer.global_position.distance_to(barrier.global_position) <= 3.2 and racer.current_speed >= 7.0:
				_show_hud("ELEPHANT BREAKTHROUGH!")
				AudioManager.play_sfx_id("tree_break", 0.9)
				barrier.queue_free()
				break

func _get_player() -> WildDashCharacterController:
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer != null and racer.is_player:
			return racer
	return null

func _show_hud(text: String) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var hud_value: Variant = parent_node.get("hud")
	var mode_hud: WildDashModeHUD = hud_value as WildDashModeHUD
	if mode_hud != null:
		mode_hud.set_message(text)

func _planar_distance_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var p: Vector2 = Vector2(point.x, point.z)
	var av: Vector2 = Vector2(a.x, a.z)
	var bv: Vector2 = Vector2(b.x, b.z)
	var ab: Vector2 = bv - av
	var length_squared: float = ab.length_squared()
	if length_squared <= 0.0001:
		return p.distance_to(av)
	var t: float = clampf((p - av).dot(ab) / length_squared, 0.0, 1.0)
	return p.distance_to(av + ab * t)

func _segment_box(
	node_name: String,
	a: Vector3,
	b: Vector3,
	width: float,
	height: float,
	material: Material,
	collision: bool
) -> CSGBox3D:
	var box: CSGBox3D = CSGBox3D.new()
	box.name = node_name
	box.size = Vector3(width, height, maxf(1.0, a.distance_to(b)))
	box.use_collision = collision
	box.position = a.lerp(b, 0.5)
	box.material = material
	box.look_at(b, Vector3.UP)
	return box

func _water_material(deep: bool) -> StandardMaterial3D:
	var color: Color = Color(0.015, 0.18, 0.30, 0.74) if deep else Color(0.02, 0.30, 0.39, 0.66)
	var material: StandardMaterial3D = _emissive_material(color, Color(0.0, 0.62, 0.86), 0.42 if deep else 0.28)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _simple_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.48
	material.emission_enabled = true
	material.emission = emission * energy
	return material
