class_name WildDashGrandPrixV2DynamicHazard
extends Area3D

## Reusable Stage 3 hazard with a readable warning phase.
## Distant hazards keep their visual presence but skip full physics animation and
## monitoring until a racer enters the activation radius.

const HIT_PROTECTION_MSEC: int = 850
const MIN_WARNING_SECONDS: float = 1.05
const ACTIVATION_CHECK_INTERVAL: float = 0.25
const ACTIVATION_DISTANCE: float = 220.0

var hazard_id: StringName = &"dynamic_hazard"
var hazard_kind: StringName = &"moving_gate"
var travel_axis: Vector3 = Vector3.RIGHT
var travel_distance: float = 7.0
var cycle_seconds: float = 5.0
var active_seconds: float = 2.2
var warning_seconds: float = 1.1
var speed_scale: float = 1.0
var impact_strength: float = 6.0
var base_retention: float = 0.52

var _base_position: Vector3 = Vector3.ZERO
var _base_global_position: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _activation_elapsed: float = ACTIVATION_CHECK_INTERVAL
var _runtime_near_racer: bool = true
var _visual: MeshInstance3D
var _warning_visual: MeshInstance3D
var _warning_ground_global: Vector3 = Vector3.ZERO
var _hit_until_by_racer: Dictionary = {}

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	body_entered.connect(_on_body_entered)

func configure(
	id: StringName,
	kind: StringName,
	size: Vector3,
	material: Material,
	axis: Vector3,
	travel: float,
	cycle: float,
	active: float,
	warning: float,
	difficulty_speed_scale: float,
	strength: float,
	retention: float
) -> void:
	hazard_id = id
	hazard_kind = kind
	var planar_axis: Vector3 = Vector3(axis.x, 0.0, axis.z)
	travel_axis = Vector3.RIGHT if planar_axis.length_squared() <= 0.001 else planar_axis.normalized()
	travel_distance = maxf(0.0, travel)
	cycle_seconds = maxf(2.0, cycle)
	active_seconds = clampf(active, 0.55, cycle_seconds - MIN_WARNING_SECONDS)
	warning_seconds = maxf(MIN_WARNING_SECONDS, warning)
	speed_scale = clampf(difficulty_speed_scale, 0.55, 1.45)
	impact_strength = maxf(0.0, strength)
	base_retention = clampf(retention, 0.28, 0.88)
	_base_position = position
	_base_global_position = global_position
	_warning_ground_global = _base_global_position + Vector3.DOWN * maxf(0.45, size.y * 0.5 - 0.08)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "HazardTrigger"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)

	_visual = MeshInstance3D.new()
	_visual.name = "HazardVisual"
	if hazard_kind == &"rolling_boulder" or hazard_kind == &"rock_fall":
		var rock: SphereMesh = SphereMesh.new()
		rock.radius = 0.5
		rock.height = 1.0
		rock.radial_segments = 8
		rock.rings = 5
		_visual.mesh = rock
		_visual.scale = size
	else:
		var block: BoxMesh = BoxMesh.new()
		block.size = size
		_visual.mesh = block
	_visual.material_override = material
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_visual)

	_warning_visual = MeshInstance3D.new()
	_warning_visual.name = "WarningMarker"
	var warning_mesh: CylinderMesh = CylinderMesh.new()
	warning_mesh.top_radius = maxf(0.7, size.x * 0.45)
	warning_mesh.bottom_radius = warning_mesh.top_radius
	warning_mesh.height = 0.06
	warning_mesh.radial_segments = 16
	_warning_visual.mesh = warning_mesh
	var warning_material: StandardMaterial3D = StandardMaterial3D.new()
	warning_material.albedo_color = Color(1.0, 0.34, 0.05, 0.82)
	warning_material.emission_enabled = true
	warning_material.emission = Color(1.0, 0.16, 0.03)
	warning_material.emission_energy_multiplier = 1.8
	_warning_visual.material_override = warning_material
	_warning_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warning_visual.visible = true
	add_child(_warning_visual)
	_warning_visual.set_as_top_level(true)
	_warning_visual.global_position = _warning_ground_global

func is_runtime_active() -> bool:
	return _runtime_near_racer and RaceManager.active

func _physics_process(delta: float) -> void:
	if not RaceManager.active:
		_elapsed = 0.0
		monitoring = false
		position = _base_position
		_runtime_near_racer = false
		if _warning_visual != null:
			_warning_visual.visible = false
		return

	_activation_elapsed += delta
	if _activation_elapsed >= ACTIVATION_CHECK_INTERVAL:
		_activation_elapsed = 0.0
		_runtime_near_racer = _has_near_racer()
	if not _runtime_near_racer:
		monitoring = false
		if _warning_visual != null:
			_warning_visual.visible = false
		return

	_elapsed += delta * speed_scale
	var cycle: float = maxf(2.0, cycle_seconds)
	var phase: float = fmod(_elapsed, cycle)
	var active_start: float = minf(warning_seconds, cycle - 0.6)
	var active_end: float = minf(cycle, active_start + active_seconds)
	var warning_active: bool = phase < active_start
	var hazard_active: bool = phase >= active_start and phase < active_end

	if _warning_visual != null:
		_warning_visual.global_position = _warning_ground_global
		_warning_visual.visible = warning_active
		if warning_active:
			var pulse: float = 0.82 + 0.18 * sin(_elapsed * 9.0)
			_warning_visual.scale = Vector3.ONE * pulse
	monitoring = hazard_active

	if not hazard_active:
		position = _inactive_position()
		rotation.y = 0.0
		return

	var t: float = clampf((phase - active_start) / maxf(0.01, active_end - active_start), 0.0, 1.0)
	match hazard_kind:
		&"rotating_log":
			position = _base_position
			rotation.y = t * TAU * 1.15
		&"moving_gate":
			position = _base_position + travel_axis * sin(t * PI * 2.0) * travel_distance * 0.5
		&"rolling_boulder":
			position = _base_position + travel_axis * lerpf(-travel_distance * 0.5, travel_distance * 0.5, t)
			if _visual != null:
				_visual.rotation.z = t * TAU * 2.0
		&"rock_fall":
			var fall_t: float = minf(1.0, t / 0.72)
			position = _base_position + Vector3.UP * lerpf(10.0, 0.0, fall_t)
		_:
			position = _base_position

func _has_near_racer() -> bool:
	var max_distance_squared: float = ACTIVATION_DISTANCE * ACTIVATION_DISTANCE
	for candidate: Node3D in RaceManager.racers:
		if not candidate is WildDashCharacterController:
			continue
		var racer: WildDashCharacterController = candidate as WildDashCharacterController
		if racer.finished:
			continue
		if racer.global_position.distance_squared_to(_base_global_position) <= max_distance_squared:
			return true
	return false

func _inactive_position() -> Vector3:
	match hazard_kind:
		&"rolling_boulder":
			return _base_position - travel_axis * travel_distance * 0.5
		&"rock_fall":
			return _base_position + Vector3.UP * 10.0
		_:
			return _base_position

func _on_body_entered(body: Node3D) -> void:
	if not body is WildDashCharacterController:
		return
	var racer: WildDashCharacterController = body as WildDashCharacterController
	var racer_key: int = racer.get_instance_id()
	var now: int = Time.get_ticks_msec()
	if now < int(_hit_until_by_racer.get(racer_key, 0)):
		return
	_hit_until_by_racer[racer_key] = now + HIT_PROTECTION_MSEC

	var defense: float = WildDashRaceCombatBalance.get_defense_rating(racer.animal_id)
	var agility: float = WildDashRaceTerrainProfile.get_agility(racer.animal_id)
	var protection: float = clampf(defense * 0.055 + agility * 0.025, 0.0, 0.72)
	var retention_bonus: float = protection * 0.26
	var final_retention: float = clampf(base_retention + retention_bonus, 0.34, 0.91)
	racer.current_speed *= final_retention

	var impact_direction: Vector3 = travel_axis
	if hazard_kind == &"rotating_log" or hazard_kind == &"rock_fall":
		impact_direction = racer.global_position - global_position
		impact_direction.y = 0.0
	if impact_direction.length_squared() <= 0.001:
		impact_direction = racer.global_transform.basis.z
	var final_strength: float = impact_strength * lerpf(1.0, 0.52, protection)
	racer.apply_knockback(impact_direction.normalized(), final_strength)

	print("GRAND PRIX V2 HAZARD HIT id=%s kind=%s racer=%s animal=%s defense=%.1f agility=%.1f retention=%.2f protection_ms=%d" % [
		String(hazard_id), String(hazard_kind), racer.name, String(racer.animal_id), defense, agility,
		final_retention, HIT_PROTECTION_MSEC,
	])
