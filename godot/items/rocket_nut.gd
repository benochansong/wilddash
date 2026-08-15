class_name WildDashRocketNut
extends Area3D

@export var speed: float = 25.5
@export var homing_strength: float = 2.25
@export var lifetime: float = 4.5

var owner_racer: Node3D
var target_racer: Node3D
var _direction: Vector3 = Vector3.FORWARD
var _elapsed: float = 0.0

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
		var desired: Vector3 = target_racer.global_position + Vector3.UP * 0.7 - global_position
		if desired.length_squared() > 0.001:
			desired = desired.normalized()
			_direction = _direction.lerp(desired, clampf(homing_strength * delta, 0.0, 0.18)).normalized()
	var from: Vector3 = global_position
	var to: Vector3 = from + _direction * speed * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 3)
	if owner_racer != null and is_instance_valid(owner_racer):
		query.exclude = [owner_racer.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider_value: Variant = hit.get("collider")
		if collider_value is WildDashCharacterController and collider_value != owner_racer:
			_resolve_hit(collider_value as WildDashCharacterController)
		else:
			queue_free()
		return
	global_position = to
	if _direction.length_squared() > 0.001:
		look_at(global_position + _direction, Vector3.UP)

	if target_racer != null and is_instance_valid(target_racer) and not RaceManager.finish_order.has(target_racer):
		if global_position.distance_to(target_racer.global_position + Vector3.UP * 0.6) <= 1.35:
			_resolve_hit(target_racer)

func _on_body_entered(body: Node) -> void:
	if body is WildDashCharacterController:
		_resolve_hit(body as WildDashCharacterController)

func _resolve_hit(body: WildDashCharacterController) -> void:
	if body == null or body == owner_racer:
		return
	var profile: WildDashRaceImpactProfile = WildDashRaceImpactProfile.rocket_nut()
	var attacker: Node = owner_racer as Node
	if WildDashRaceCombatCoreV3.apply_race_impact(attacker, body, &"rocket_nut", profile, global_position):
		_spawn_hit_fx(body.global_position)
		AudioManager.play_sfx_id("hit", 0.95)
		print("ROCKET NUT V3 HIT target=%s speed_loss=%.0f%% knockback=%.2f stagger=%.2f" % [
			RaceManager.get_racer_label(body), profile.speed_loss_ratio * 100.0, profile.knockback, profile.stagger_duration,
		])
		queue_free()

func _spawn_hit_fx(position: Vector3) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.name = "RocketNutDirectHitFX"
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.52
	mesh.height = 0.9
	flash.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.52, 0.08)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.25, 0.02)
	material.emission_energy_multiplier = 2.1
	flash.material_override = material
	parent_node.add_child(flash)
	flash.global_position = position + Vector3.UP * 0.7
	flash.scale = Vector3.ONE * 0.35
	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 2.2, 0.14)
	tween.tween_callback(Callable(flash, "queue_free"))

func _build_visual() -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.42
	mesh.height = 1.25
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.42, 0.12)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.08, 0.01)
	material.emission_energy_multiplier = 1.8
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.62
	collision.shape = shape
	add_child(collision)
