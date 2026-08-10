class_name WildDashStickyFruitTrap
extends Area3D

var owner_racer: Node
var _armed := false
var _life := 0.0
var _visual: Node3D

func _ready() -> void:
	add_to_group("wilddash_item_trap")
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	_build_visual()
	body_entered.connect(_on_body_entered)
	_arm_later()

func _process(delta: float) -> void:
	_life += delta
	if _visual != null:
		_visual.rotation.y += delta * 1.1
		_visual.rotation.z = sin(_life * 3.0) * 0.12
	if _life >= 14.0:
		queue_free()

func _arm_later() -> void:
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	_armed = true
	# Cover racers that entered during the arm delay once, then let Area3D
	# body_entered drive all future hits. This removes the old full-field
	# physics-frame scan from long-lived traps.
	for body in get_overlapping_bodies():
		_resolve_hit(body)
		if is_queued_for_deletion():
			return

func _on_body_entered(body: Node) -> void:
	if _armed:
		_resolve_hit(body)

func _resolve_hit(body: Node) -> void:
	if body == null or body == owner_racer or not body is WildDashCharacterController:
		return
	if ItemSystem.apply_attack(body, owner_racer, &"sticky_fruit", 1.25, 0.52, 0.8):
		print("STICKY FRUIT TRAP HIT target=%s" % RaceManager.get_racer_label(body))
		queue_free()

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.72
	mesh.height = 1.05
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.16, 0.42)
	material.roughness = 0.7
	mesh_instance.material_override = material
	_visual.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	collision.shape = shape
	add_child(collision)
