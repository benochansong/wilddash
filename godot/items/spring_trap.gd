class_name WildDashSpringTrap
extends Area3D

const LIFE_SECONDS := 10.0

var owner_racer: WildDashCharacterController
var _life := LIFE_SECONDS

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.95
	shape.height = 0.45
	collision.shape = shape
	add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.85
	mesh.bottom_radius = 1.05
	mesh.height = 0.22
	mesh.radial_segments = 10
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.18, 0.23)
	material.metallic = 0.35
	material.roughness = 0.42
	material.emission_enabled = true
	material.emission = Color(0.28, 0.02, 0.03)
	material.emission_energy_multiplier = 0.9
	visual.material_override = material
	add_child(visual)

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == owner_racer or not body is WildDashCharacterController:
		return
	var racer := body as WildDashCharacterController
	if ItemSystem.has_shield(racer):
		ItemSystem.apply_attack(racer, owner_racer, &"spring_trap", 0.0, 1.0, 0.0)
		queue_free()
		return
	racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 0.76)
	racer.current_speed *= 0.86
	queue_free()
