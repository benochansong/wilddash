class_name WildDashAcornBomb
extends Node3D

const GRAVITY := 20.0
const LIFE_SECONDS := 4.0
const HIT_RADIUS := 1.35
const EXPLOSION_RADIUS := 4.6

var owner_racer: WildDashCharacterController
var velocity := Vector3.ZERO
var _life := 0.0
var _exploded := false
var _visual: Node3D

func configure(racer: WildDashCharacterController) -> void:
	owner_racer = racer
	if racer == null:
		return
	var forward := -racer.global_transform.basis.z.normalized()
	velocity = forward * 17.0 + Vector3.UP * 7.6

func _ready() -> void:
	_build_visual()

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_life += delta
	if _life >= LIFE_SECONDS:
		_explode()
		return
	var previous := global_position
	velocity.y -= GRAVITY * delta
	var next := previous + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(previous, next, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if owner_racer != null and is_instance_valid(owner_racer):
		query.exclude = [owner_racer.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.get("position", next)
		_explode()
		return
	global_position = next
	if _visual != null:
		_visual.rotate_x(delta * 7.0)
		_visual.rotate_z(delta * 5.0)
	for racer in RaceManager.racers:
		if racer == null or racer == owner_racer or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		if global_position.distance_to(racer.global_position + Vector3.UP * 0.7) <= HIT_RADIUS:
			_explode()
			return

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var hits := 0
	for racer in RaceManager.racers:
		if racer == null or racer == owner_racer or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		if global_position.distance_to(racer.global_position) <= EXPLOSION_RADIUS:
			if ItemSystem.apply_attack(racer, owner_racer, &"acorn_bomb", 0.9, 0.72, 3.4):
				hits += 1
	print("ACORN BOMB EXPLOSION hits=%d radius=%.1f" % [hits, EXPLOSION_RADIUS])
	queue_free()

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.48
	sphere.height = 0.82
	body.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.43, 0.22, 0.08)
	material.roughness = 0.82
	body.material_override = material
	_visual.add_child(body)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.2
	cap_mesh.bottom_radius = 0.32
	cap_mesh.height = 0.22
	cap.mesh = cap_mesh
	cap.position.y = 0.48
	cap.material_override = material
	_visual.add_child(cap)
