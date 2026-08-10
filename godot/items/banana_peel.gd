class_name WildDashBananaPeel
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
		_visual.rotation.y += delta * 0.7
	if _life >= 16.0:
		queue_free()

func _arm_later() -> void:
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	_armed = true
	# A racer can already overlap while the trap is arming. Check the Area3D
	# overlap set once here, then rely on body_entered rather than scanning the
	# entire race field every physics frame for the rest of the trap lifetime.
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
	if ItemSystem.apply_spin(body, owner_racer, 0.85):
		print("BANANA PEEL HIT target=%s spin=0.85s" % RaceManager.get_racer_label(body))
		queue_free()

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.84, 0.08)
	material.roughness = 0.72
	for i in range(3):
		var peel := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.16
		mesh.height = 0.9
		peel.mesh = mesh
		peel.rotation_degrees = Vector3(0, float(i) * 120.0, 58.0)
		peel.position = Vector3(cos(float(i) * TAU / 3.0), 0.08, sin(float(i) * TAU / 3.0)) * 0.28
		peel.material_override = material
		_visual.add_child(peel)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.85
	collision.shape = shape
	add_child(collision)
