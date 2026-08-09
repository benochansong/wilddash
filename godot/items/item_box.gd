class_name WildDashItemBox
extends Area3D

@export var respawn_seconds := 5.0

var _active := true
var _visual_root: Node3D
var _collision: CollisionShape3D
var _time := 0.0
var _scan_elapsed := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	_build_visual()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	if _visual_root != null and _active:
		_visual_root.rotation.y += delta * 1.9
		_visual_root.position.y = sin(_time * 2.6) * 0.22

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_scan_elapsed += delta
	if _scan_elapsed < 0.10:
		return
	_scan_elapsed = 0.0
	for racer in RaceManager.racers:
		if racer == null or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		if global_position.distance_to(racer.global_position + Vector3.UP * 0.8) <= 3.3:
			if _try_pickup(racer):
				return

func force_pickup(racer: Node) -> bool:
	return _try_pickup(racer)

func is_active() -> bool:
	return _active

func _on_body_entered(body: Node) -> void:
	_try_pickup(body)

func _try_pickup(body: Node) -> bool:
	if not _active or body == null or not body.has_method("get_held_item"):
		return false
	if StringName(body.call("get_held_item")) != &"":
		return false
	if not ItemSystem.grant_weighted_item(body):
		return false
	var item_id := StringName(body.call("get_held_item"))
	print("ITEM BOX PICKUP racer=%s item=%s rank=%d" % [
		RaceManager.get_racer_label(body) if body is Node3D else body.name,
		ItemSystem.get_display_name(item_id),
		RaceManager.get_rank(body) if body is Node3D else 0,
	])
	_deactivate()
	return true

func _deactivate() -> void:
	if not _active:
		return
	_active = false
	set_deferred("monitoring", false)
	if _collision != null:
		_collision.set_deferred("disabled", true)
	if _visual_root != null:
		_visual_root.visible = false
	_respawn_later()

func _respawn_later() -> void:
	await get_tree().create_timer(respawn_seconds).timeout
	if not is_inside_tree():
		return
	_active = true
	monitoring = true
	if _collision != null:
		_collision.disabled = false
	if _visual_root != null:
		_visual_root.visible = true

func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.45, 1.45, 1.45)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.78, 0.16)
	material.emission_enabled = true
	material.emission = Color(0.24, 0.18, 0.02)
	material.emission_energy_multiplier = 1.6
	material.metallic = 0.18
	material.roughness = 0.35
	mesh_instance.material_override = material
	_visual_root.add_child(mesh_instance)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.76
	torus.outer_radius = 0.92
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.2, 0.86, 1.0)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.05, 0.35, 0.55)
	ring_material.emission_energy_multiplier = 2.0
	ring.material_override = ring_material
	_visual_root.add_child(ring)

	_collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.45
	_collision.shape = shape
	add_child(_collision)
