class_name WildDashSnowballProjectile
extends Node3D

const SPEED := 23.0
const LIFE_SECONDS := 3.0
const HIT_RADIUS := 0.9

var owner_racer: WildDashCharacterController
var direction := Vector3.FORWARD
var _life := LIFE_SECONDS

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
	var motion := direction * SPEED * delta
	var from := global_position
	var to := from + motion
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 3)
	if owner_racer != null and is_instance_valid(owner_racer):
		query.exclude = [owner_racer.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider is WildDashCharacterController and collider != owner_racer:
			ItemSystem.apply_attack(collider, owner_racer, &"snowball", 0.72, 0.76, 2.4)
		queue_free()
		return
	global_position = to
	rotation.x += delta * 8.0
	rotation.z += delta * 5.5
	for rival in RaceManager.racers:
		if rival == owner_racer or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		if global_position.distance_to(rival.global_position + Vector3.UP * 0.7) <= HIT_RADIUS:
			ItemSystem.apply_attack(rival, owner_racer, &"snowball", 0.72, 0.76, 2.4)
			queue_free()
			return

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SnowballVisual"
	var mesh := SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.1
	mesh.radial_segments = 10
	mesh.rings = 6
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.93, 0.98, 1.0)
	material.roughness = 0.82
	material.emission_enabled = true
	material.emission = Color(0.08, 0.16, 0.22)
	material.emission_energy_multiplier = 0.7
	mesh_instance.material_override = material
	add_child(mesh_instance)
