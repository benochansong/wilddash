class_name WildDashTerrainMovementController
extends Node

## Applies terrain affinity to every registered race character.
## Terrain effects still apply every physics frame, but expensive zone discovery
## runs at 10Hz through a spatial grid instead of scanning the whole zone group
## once per racer on every physics tick.

const WATER_CURRENT_MAX_SPEED: float = 3.0
const TERRAIN_HUD_SECONDS: float = 1.5
const ZONE_QUERY_INTERVAL: float = 0.10
const ZONE_CACHE_REFRESH_INTERVAL: float = 1.0
const ZONE_GRID_SIZE: float = 64.0

var _last_zone_by_racer: Dictionary = {}
var _zone_by_racer: Dictionary = {}
var _zone_grid: Dictionary = {}
var _zone_query_elapsed: float = 0.0
var _zone_cache_elapsed: float = ZONE_CACHE_REFRESH_INTERVAL
var _cached_zone_count: int = -1
var _terrain_hud_panel: PanelContainer
var _terrain_hud_label: Label
var _hud_hide_at_msec: int = 0

func _ready() -> void:
	process_priority = 96
	_build_terrain_hud()

func _physics_process(delta: float) -> void:
	_update_terrain_hud_visibility()
	_zone_cache_elapsed += delta
	if _zone_cache_elapsed >= ZONE_CACHE_REFRESH_INTERVAL or _zone_grid.is_empty():
		_zone_cache_elapsed = 0.0
		_refresh_zone_grid()

	if not RaceManager.active:
		_last_zone_by_racer.clear()
		_zone_by_racer.clear()
		_zone_query_elapsed = 0.0
		return

	_zone_query_elapsed += delta
	var resolve_zones: bool = _zone_query_elapsed >= ZONE_QUERY_INTERVAL
	if resolve_zones:
		_zone_query_elapsed = 0.0

	for candidate: Node3D in RaceManager.racers:
		if not candidate is WildDashCharacterController:
			continue
		var racer: WildDashCharacterController = candidate as WildDashCharacterController
		if racer.finished:
			continue
		var racer_key: int = racer.get_instance_id()
		var zone: WildDashTerrainZone = _zone_by_racer.get(racer_key, null) as WildDashTerrainZone
		if resolve_zones:
			zone = _find_zone_for_point(racer.global_position, zone)
			_zone_by_racer[racer_key] = zone
			_report_transition(racer, zone)
		if zone == null:
			continue
		match zone.get_terrain_type():
			&"water":
				_apply_water(racer, zone, delta)
			&"climb":
				_apply_climb(racer, delta)
			&"rough":
				_apply_rough(racer, delta)
			&"summit":
				pass

func _refresh_zone_grid() -> void:
	var next_grid: Dictionary = {}
	var zones: Array[Node] = get_tree().get_nodes_in_group("wilddash_terrain_zone")
	var valid_count: int = 0
	for node: Node in zones:
		if not node is WildDashTerrainZone:
			continue
		var zone: WildDashTerrainZone = node as WildDashTerrainZone
		valid_count += 1
		var radius: float = maxf(zone.half_length, zone.half_width) + 4.0
		var min_x: int = floori((zone.center.x - radius) / ZONE_GRID_SIZE)
		var max_x: int = floori((zone.center.x + radius) / ZONE_GRID_SIZE)
		var min_z: int = floori((zone.center.z - radius) / ZONE_GRID_SIZE)
		var max_z: int = floori((zone.center.z + radius) / ZONE_GRID_SIZE)
		for cell_x: int in range(min_x, max_x + 1):
			for cell_z: int in range(min_z, max_z + 1):
				var key: Vector2i = Vector2i(cell_x, cell_z)
				var bucket: Array = next_grid.get(key, [])
				bucket.append(zone)
				next_grid[key] = bucket
	_zone_grid = next_grid
	if valid_count != _cached_zone_count:
		_cached_zone_count = valid_count
		print("GRAND PRIX TERRAIN LOOKUP CACHE zones=%d buckets=%d query_hz=%.1f grid=%.0fm" % [
			valid_count, _zone_grid.size(), 1.0 / ZONE_QUERY_INTERVAL, ZONE_GRID_SIZE,
		])

func _find_zone_for_point(point: Vector3, previous: WildDashTerrainZone) -> WildDashTerrainZone:
	if previous != null and previous.contains_global_point(point):
		return previous
	var key: Vector2i = Vector2i(floori(point.x / ZONE_GRID_SIZE), floori(point.z / ZONE_GRID_SIZE))
	var bucket: Array = _zone_grid.get(key, [])
	for value: Variant in bucket:
		var zone: WildDashTerrainZone = value as WildDashTerrainZone
		if zone != null and zone.contains_global_point(point):
			return zone
	return null

func _apply_water(racer: WildDashCharacterController, zone: WildDashTerrainZone, delta: float) -> void:
	var speed_ratio: float = WildDashRaceTerrainProfile.get_swim_speed_ratio(racer.animal_id)
	var acceleration_scale: float = WildDashRaceTerrainProfile.get_swim_acceleration_scale(racer.animal_id)
	var skill_scale: float = clampf(racer.get_active_speed_scale(), 0.75, 1.12)
	var target_speed: float = racer.max_speed * speed_ratio * skill_scale
	if racer.is_player and InputManager.get_throttle_axis() < -0.05:
		target_speed *= 0.35
	var water_acceleration: float = racer.acceleration * acceleration_scale * 1.15
	racer.current_speed = move_toward(racer.current_speed, maxf(0.0, target_speed), water_acceleration * delta)

	var current_direction: Vector3 = zone.get_current_direction()
	if current_direction.length_squared() <= 0.001 or zone.get_current_strength() <= 0.0:
		return
	var susceptibility: float = WildDashRaceTerrainProfile.get_river_current_susceptibility(racer.animal_id)
	var desired_current_speed: float = minf(WATER_CURRENT_MAX_SPEED, zone.get_current_strength() * susceptibility)
	var current_velocity: Vector3 = racer.get_knockback_velocity()
	var existing_current: float = maxf(0.0, current_velocity.dot(current_direction))
	if existing_current < desired_current_speed:
		racer.apply_knockback(current_direction, desired_current_speed - existing_current)

func _apply_climb(racer: WildDashCharacterController, delta: float) -> void:
	var ratio: float = WildDashRaceTerrainProfile.get_climb_speed_ratio(racer.animal_id)
	var target_speed: float = racer.max_speed * ratio * clampf(racer.get_active_speed_scale(), 0.78, 1.12)
	if racer.current_speed > target_speed:
		racer.current_speed = move_toward(racer.current_speed, target_speed, racer.acceleration * 1.55 * delta)
	elif ratio >= 0.96:
		racer.current_speed = move_toward(racer.current_speed, target_speed, racer.acceleration * 0.32 * delta)

func _apply_rough(racer: WildDashCharacterController, delta: float) -> void:
	var ratio: float = WildDashRaceTerrainProfile.get_rough_speed_ratio(racer.animal_id)
	var target_speed: float = racer.max_speed * ratio * clampf(racer.get_active_speed_scale(), 0.80, 1.10)
	if racer.current_speed > target_speed:
		racer.current_speed = move_toward(racer.current_speed, target_speed, racer.acceleration * 1.40 * delta)
	elif ratio >= 0.95:
		racer.current_speed = move_toward(racer.current_speed, target_speed, racer.acceleration * 0.24 * delta)

func _report_transition(racer: WildDashCharacterController, zone: WildDashTerrainZone) -> void:
	var racer_key: int = racer.get_instance_id()
	var next_id: StringName = &"" if zone == null else zone.get_zone_id()
	var previous_id: StringName = StringName(_last_zone_by_racer.get(racer_key, &""))
	if previous_id == next_id:
		return
	_last_zone_by_racer[racer_key] = next_id
	if zone == null:
		if previous_id != &"":
			print("RC9 TERRAIN EXIT racer=%s zone=%s" % [racer.name, String(previous_id)])
		return
	var profile: Dictionary = WildDashRaceTerrainProfile.get_profile(racer.animal_id)
	print("RC9 TERRAIN ENTER racer=%s animal=%s zone=%s type=%s swim=%.1f climb=%.1f agility=%.1f power=%.1f rough=%.1f" % [
		racer.name,
		String(racer.animal_id),
		String(zone.get_zone_id()),
		String(zone.get_terrain_type()),
		float(profile["swim"]),
		float(profile["climb"]),
		float(profile["agility"]),
		float(profile["power"]),
		float(profile["rough"]),
	])
	if racer.is_player:
		_show_player_terrain_feedback(racer, zone)

func _build_terrain_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var canvas := CanvasLayer.new()
	canvas.name = "TerrainFeedbackLayer"
	canvas.layer = 35
	add_child(canvas)
	_terrain_hud_panel = PanelContainer.new()
	_terrain_hud_panel.name = "TerrainFeedback"
	_terrain_hud_panel.position = Vector2(34.0, 148.0)
	_terrain_hud_panel.custom_minimum_size = Vector2(320.0, 54.0)
	_terrain_hud_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.075, 0.88)
	panel_style.border_color = Color(0.10, 0.78, 0.72, 0.82)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	_terrain_hud_panel.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(_terrain_hud_panel)
	_terrain_hud_label = Label.new()
	_terrain_hud_label.name = "TerrainFeedbackText"
	_terrain_hud_label.text = "TERRAIN"
	_terrain_hud_label.add_theme_font_size_override("font_size", 20)
	_terrain_hud_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	_terrain_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terrain_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_terrain_hud_panel.add_child(_terrain_hud_label)

func _show_player_terrain_feedback(racer: WildDashCharacterController, zone: WildDashTerrainZone) -> void:
	if _terrain_hud_panel == null or _terrain_hud_label == null:
		return
	var terrain_type: StringName = zone.get_terrain_type()
	match terrain_type:
		&"water":
			_terrain_hud_label.text = "WATER  ·  SWIM %.1f" % WildDashRaceTerrainProfile.get_swim(racer.animal_id)
		&"climb":
			_terrain_hud_label.text = "MOUNTAIN  ·  CLIMB %.1f" % WildDashRaceTerrainProfile.get_climb(racer.animal_id)
		&"rough":
			_terrain_hud_label.text = "ROUGH DESCENT  ·  ROUGH %.1f" % WildDashRaceTerrainProfile.get_rough(racer.animal_id)
		&"summit":
			_terrain_hud_label.text = "SUMMIT RIDGE  ·  58m"
		_:
			_terrain_hud_label.text = "TERRAIN"
	_terrain_hud_panel.visible = true
	_hud_hide_at_msec = Time.get_ticks_msec() + int(TERRAIN_HUD_SECONDS * 1000.0)

func _update_terrain_hud_visibility() -> void:
	if _terrain_hud_panel == null or not _terrain_hud_panel.visible:
		return
	if Time.get_ticks_msec() >= _hud_hide_at_msec:
		_terrain_hud_panel.visible = false
