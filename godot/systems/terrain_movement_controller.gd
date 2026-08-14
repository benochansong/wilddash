class_name WildDashTerrainMovementController
extends Node

## Applies terrain affinity to every registered race character.
## Runs after normal movement/race-action controllers so the selected terrain
## becomes the final movement rule for the next physics step.

const WATER_CURRENT_MAX_SPEED: float = 3.0

var _last_zone_by_racer: Dictionary = {}

func _ready() -> void:
	process_priority = 96

func _physics_process(_delta: float) -> void:
	if not RaceManager.active:
		_last_zone_by_racer.clear()
		return

	for candidate: Node3D in RaceManager.racers:
		if not candidate is WildDashCharacterController:
			continue
		var racer: WildDashCharacterController = candidate as WildDashCharacterController
		if racer.finished:
			continue
		var zone: WildDashTerrainZone = _find_zone_for_point(racer.global_position)
		_report_transition(racer, zone)
		if zone == null:
			continue
		match zone.get_terrain_type():
			&"water":
				_apply_water(racer, zone)
			&"climb":
				_apply_climb(racer)
			&"rough":
				_apply_rough(racer)

func _find_zone_for_point(point: Vector3) -> WildDashTerrainZone:
	for node: Node in get_tree().get_nodes_in_group("wilddash_terrain_zone"):
		if node is WildDashTerrainZone:
			var zone: WildDashTerrainZone = node as WildDashTerrainZone
			if zone.contains_global_point(point):
				return zone
	return null

func _apply_water(racer: WildDashCharacterController, zone: WildDashTerrainZone) -> void:
	var speed_ratio: float = WildDashRaceTerrainProfile.get_swim_speed_ratio(racer.animal_id)
	var skill_scale: float = clampf(racer.get_active_speed_scale(), 0.75, 1.12)
	var target_speed: float = racer.max_speed * speed_ratio * skill_scale
	if racer.is_player and InputManager.get_throttle_axis() < -0.05:
		target_speed *= 0.35
	# Terrain runs after the ordinary racing action controller. Assigning the
	# final target here lets a strong swimmer actually keep its water advantage
	# instead of being clamped back to ordinary dry-road pace every frame.
	racer.current_speed = maxf(0.0, target_speed)

	var current_direction: Vector3 = zone.get_current_direction()
	if current_direction.length_squared() <= 0.001 or zone.get_current_strength() <= 0.0:
		return
	var susceptibility: float = WildDashRaceTerrainProfile.get_river_current_susceptibility(racer.animal_id)
	var desired_current_speed: float = minf(
		WATER_CURRENT_MAX_SPEED,
		zone.get_current_strength() * susceptibility
	)
	var current_velocity: Vector3 = racer.get_knockback_velocity()
	var existing_current: float = maxf(0.0, current_velocity.dot(current_direction))
	if existing_current < desired_current_speed:
		racer.apply_knockback(current_direction, desired_current_speed - existing_current)

func _apply_climb(racer: WildDashCharacterController) -> void:
	var ratio: float = WildDashRaceTerrainProfile.get_climb_speed_ratio(racer.animal_id)
	racer.current_speed = minf(racer.current_speed, racer.max_speed * ratio)

func _apply_rough(racer: WildDashCharacterController) -> void:
	var ratio: float = WildDashRaceTerrainProfile.get_rough_speed_ratio(racer.animal_id)
	racer.current_speed = minf(racer.current_speed, racer.max_speed * ratio)

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
