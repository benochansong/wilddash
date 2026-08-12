class_name WildDashRocketNut
extends Area3D

@export var speed := 24.0
@export var homing_strength := 2.2
@export var lifetime := 4.5

var owner_racer: Node3D
var target_racer: Node3D
var _direction := Vector3.FORWARD
var _elapsed := 0.0

func configure(owner: Node3D, target: Node3D) -> void:
	owner_racer = owner
	target_racer = target
	if owner_racer != null:
		_direction = -owner_racer.global_transform.basis.z.normalized()

func _ready() -> void:
	add_to_group("wilddash_rocket_nut")
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	_build_visual()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	if target_racer != null and is_instance_valid(target_racer) and not RaceManager.finish_order.has(target_racer):
		var desired := target_racer.global_position + Vector3.UP * 0.7 - global_position
		if desired.length_squared() > 0.001:
			desired = desired.normalized()
			_direction = _direction.lerp(desired, clampf(homing_strength * delta, 0.0, 0.18)).normalized()
	var from := global_position
	var to := from + _direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 3)
	if owner_racer != null and is_instance_valid(owner_racer):
		query.exclude = [owner_racer.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider is WildDashCharacterController and collider != owner_racer:
			_resolve_hit(collider)
		else:
			# World layer 1 wins over visual tunnelling: projectiles disappear on
			# tunnel/warehouse/guardrail contact rather than spawning outside.
			queue_free()
		return
	global_position = to
	if _direction.length_squared() > 0.001:
		look_at(global_position + _direction, Vector3.UP)

	# Area3D catches incidental racers. The homing target gets one direct
	# distance check to guard against fast-moving overlap misses without
	# scanning every racer every physics frame.
	if target_racer != null and is_instance_valid(target_racer) and not RaceManager.finish_order.has(target_racer):
		if global_position.distance_to(target_racer.global_position + Vector3.UP * 0.6) <= 1.35:
			_resolve_hit(target_racer)

func _on_body_entered(body: Node) -> void:
	_resolve_hit(body)

func _resolve_hit(body: Node) -> void:
	if body == null or body == owner_racer or not body is WildDashCharacterController:
		return
	if ItemSystem.apply_attack(body, owner_racer, &"rocket_nut", 1.0, 0.58, 2.4):
		print("ROCKET NUT HIT target=%s" % RaceManager.get_racer_label(body))
		queue_free()

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.42
	mesh.height = 1.25
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.42, 0.12)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.08, 0.01)
	material.emission_energy_multiplier = 1.8
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.62
	collision.shape = shape
	add_child(collision)
