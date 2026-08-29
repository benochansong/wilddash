class_name WildDashSnowballProjectile
extends Node3D

const SPEED: float = 24.5
const LIFE_SECONDS: float = 3.0
const HIT_RADIUS: float = 0.95
const HIT_DURATION: float = 0.82
const HIT_SLOW_MULTIPLIER: float = 0.72
const HIT_KNOCKBACK: float = 3.05

var owner_racer: WildDashCharacterController
var direction: Vector3 = Vector3.FORWARD
var _life: float = LIFE_SECONDS

func configure(owner: WildDashCharacterController, forward: Vector3) -> void:
	owner_racer = owner
	direction = Vector3(forward.x, 0.0, forward.z).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD

func _ready() -> void:
	_build_visual()

func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var motion: Vector3 = direction * SPEED * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + motion
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 3)
	if owner_racer != null and is_instance_valid(owner_racer):
		query.exclude = [owner_racer.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		var collider: Variant = hit.get("collider")
		if collider is WildDashCharacterController and collider != owner_racer:
			_resolve_hit(collider as WildDashCharacterController)
		queue_free()
		return
	global_position = to
	rotation.x += delta * 8.0
	rotation.z += delta * 5.5
	for rival_value: Variant in RaceManager.racers:
		var rival: WildDashCharacterController = rival_value as WildDashCharacterController
		if rival == null or rival == owner_racer or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		if global_position.distance_to(rival.global_position + Vector3.UP * 0.7) <= HIT_RADIUS:
			_resolve_hit(rival)
			queue_free()
			return

func _resolve_hit(target: WildDashCharacterController) -> void:
	if target == null:
		return
	if ItemSystem.apply_attack(
		target,
		owner_racer,
		&"snowball",
		HIT_DURATION,
		HIT_SLOW_MULTIPLIER,
		HIT_KNOCKBACK
	):
		AudioManager.play_sfx_id("hit", 0.78)
		print("SNOWBALL POWER HIT target=%s slow=%.2f duration=%.2f knockback=%.2f" % [
			RaceManager.get_racer_label(target), HIT_SLOW_MULTIPLIER, HIT_DURATION, HIT_KNOCKBACK,
		])

func _build_visual() -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "SnowballVisual"
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.1
	mesh.radial_segments = 10
	mesh.rings = 6
	mesh_instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.93, 0.98, 1.0)
	material.roughness = 0.82
	material.emission_enabled = true
	material.emission = Color(0.08, 0.16, 0.22)
	material.emission_energy_multiplier = 0.9
	mesh_instance.material_override = material
	add_child(mesh_instance)
