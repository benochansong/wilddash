class_name WildDashAcornBomb
extends Node3D

## Long-range catch-up bomb for race modes.
## It is still a ballistic throw rather than a homing rocket: the throw samples
## the selected rival once, leads their current velocity, then commits to the arc.

const GRAVITY: float = 20.0
const LIFE_SECONDS: float = 4.6
const HIT_RADIUS: float = 1.45
const EXPLOSION_RADIUS: float = 5.2
const DEFAULT_FORWARD_SPEED: float = 30.0
const DEFAULT_UP_SPEED: float = 11.5
const MIN_FLIGHT_SECONDS: float = 1.00
const MAX_FLIGHT_SECONDS: float = 2.20
const TARGET_SPEED_REFERENCE: float = 30.0
const TARGET_LEAD_FACTOR: float = 0.58

var owner_racer: WildDashCharacterController
var target_racer: WildDashCharacterController
var velocity: Vector3 = Vector3.ZERO
var _life: float = 0.0
var _exploded: bool = false
var _visual: Node3D

func configure(racer: WildDashCharacterController, target: Node3D = null) -> void:
	owner_racer = racer
	target_racer = target as WildDashCharacterController
	if racer == null:
		return
	var forward: Vector3 = -racer.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var launch_origin: Vector3 = racer.global_position + forward * 1.8 + Vector3.UP * 1.25
	if target_racer == null or not is_instance_valid(target_racer):
		velocity = forward * DEFAULT_FORWARD_SPEED + Vector3.UP * DEFAULT_UP_SPEED
		return

	var target_point: Vector3 = target_racer.global_position + Vector3.UP * 0.70
	var initial_planar_distance: float = Vector2(
		target_point.x - launch_origin.x,
		target_point.z - launch_origin.z
	).length()
	var flight_seconds: float = clampf(initial_planar_distance / TARGET_SPEED_REFERENCE, MIN_FLIGHT_SECONDS, MAX_FLIGHT_SECONDS)
	var target_planar_velocity: Vector3 = Vector3(target_racer.velocity.x, 0.0, target_racer.velocity.z)
	target_point += target_planar_velocity * flight_seconds * TARGET_LEAD_FACTOR
	var delta: Vector3 = target_point - launch_origin
	var planar_delta: Vector3 = Vector3(delta.x, 0.0, delta.z)
	velocity = planar_delta / flight_seconds
	velocity.y = (delta.y + 0.5 * GRAVITY * flight_seconds * flight_seconds) / flight_seconds
	print("ACORN LONG BOMB LOCK owner=%s target=%s distance=%.1f flight=%.2f" % [
		RaceManager.get_racer_label(racer), RaceManager.get_racer_label(target_racer), initial_planar_distance, flight_seconds,
	])

func _ready() -> void:
	_build_visual()

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_life += delta
	if _life >= LIFE_SECONDS:
		_explode()
		return
	var previous: Vector3 = global_position
	velocity.y -= GRAVITY * delta
	var next: Vector3 = previous + velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(previous, next, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if owner_racer != null and is_instance_valid(owner_racer):
		query.exclude = [owner_racer.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", next)
		global_position = hit_position
		_explode()
		return
	global_position = next
	if _visual != null:
		_visual.rotate_x(delta * 7.0)
		_visual.rotate_z(delta * 5.0)
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer == owner_racer or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		if global_position.distance_to(racer.global_position + Vector3.UP * 0.7) <= HIT_RADIUS:
			_explode()
			return

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var hits: int = 0
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer == owner_racer or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		if global_position.distance_to(racer.global_position) <= EXPLOSION_RADIUS:
			if ItemSystem.apply_attack(racer, owner_racer, &"acorn_bomb", 1.05, 0.76, 4.0):
				hits += 1
	if hits > 0:
		AudioManager.play_sfx_id("hit", 1.0)
	print("ACORN LONG BOMB EXPLOSION hits=%d radius=%.1f" % [hits, EXPLOSION_RADIUS])
	queue_free()

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var body: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 0.94
	sphere.radial_segments = 10
	sphere.rings = 6
	body.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.47, 0.22, 0.055)
	material.roughness = 0.78
	material.emission_enabled = true
	material.emission = Color(0.95, 0.28, 0.04) * 0.42
	body.material_override = material
	_visual.add_child(body)
	var cap: MeshInstance3D = MeshInstance3D.new()
	var cap_mesh: CylinderMesh = CylinderMesh.new()
	cap_mesh.top_radius = 0.20
	cap_mesh.bottom_radius = 0.34
	cap_mesh.height = 0.24
	cap.mesh = cap_mesh
	cap.position.y = 0.53
	cap.material_override = material
	_visual.add_child(cap)
