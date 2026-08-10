class_name WildDashStickyFruitTrap
extends Area3D

@export var lifetime := 12.0
@export var proximity_scan_hz := 6.0

var owner_racer: Node
var _armed := false
var _life := 0.0
var _scan_elapsed := 0.0
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
	if _life >= lifetime:
		queue_free()

func _physics_process(delta: float) -> void:
	if not _armed:
		return
	_scan_elapsed += delta
	if _scan_elapsed < 1.0 / clampf(proximity_scan_hz, 4.0, 8.0):
		return
	_scan_elapsed = 0.0
	for racer in RaceManager.racers:
		if racer == null or racer == owner_racer or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		if global_position.distance_to(racer.global_position) <= 1.45:
			_resolve_hit(racer)
			return

func _arm_later() -> void:
	await get_tree().create_timer(0.35).timeout
	if is_inside_tree():
		_armed = true

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
