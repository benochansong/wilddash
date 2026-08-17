extends "res://modes/logspire_leap/logspire_phase3_director_v3_water_priority.gd"

## Player-tested collision authority for the large Phase 3 tree geometry.
## Production visuals remain lightweight, but the trunk and giant roots now
## have simple gameplay collision so swimming/recovery cannot pass through them.

const MAJOR_WORLD_COLLISION_LAYER: int = 5 # layer 1 gameplay + layer 3 traversal query
const TITAN_TRUNK_COLLISION_RADIUS: float = 9.15
const TITAN_TRUNK_COLLISION_HEIGHT: float = 84.0
const TITAN_ROOT_COLLISION_SIZE := Vector3(4.6, 2.0, 22.0)

var _major_collision_root: Node3D

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_build_major_world_collision()

func _build_major_world_collision() -> void:
	if _world == null:
		return
	var existing := _world.get_node_or_null("LogspireMajorWorldCollision") as Node3D
	if existing != null:
		existing.queue_free()

	_major_collision_root = Node3D.new()
	_major_collision_root.name = "LogspireMajorWorldCollision"
	_world.add_child(_major_collision_root)

	# The production TitanTrunk was previously visual-only. A tapered mesh does
	# not need expensive mesh collision here; one conservative cylinder gives the
	# player a readable solid obstacle at a tiny physics cost.
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = TITAN_TRUNK_COLLISION_RADIUS
	trunk_shape.height = TITAN_TRUNK_COLLISION_HEIGHT
	_add_major_static_body(
		"TitanTrunkCollision",
		Vector3(_titan_center.x, 37.0, _titan_center.z),
		Vector3.ZERO,
		trunk_shape
	)

	# Giant roots are also visible enough that walking/swimming through them looks
	# broken. Their collision is slightly smaller than the visual boxes to avoid
	# snagging racers on decorative edges.
	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var root_shape := BoxShape3D.new()
		root_shape.size = TITAN_ROOT_COLLISION_SIZE
		_add_major_static_body(
			"TitanRootCollision_%02d" % i,
			Vector3(_titan_center.x, 2.0, _titan_center.z) + direction * 9.0,
			Vector3(0.0, angle, 0.0),
			root_shape
		)

	print("LOGSPIRE MAJOR WORLD COLLISION READY trunk=1 roots=8 layer1=true traversal_query_layer=4 phase_through=false")

func _add_major_static_body(
	body_name: String,
	position: Vector3,
	rotation_value: Vector3,
	shape: Shape3D
) -> void:
	if _major_collision_root == null:
		return
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = MAJOR_WORLD_COLLISION_LAYER
	body.collision_mask = 0
	body.add_to_group("logspire_major_world_collision")
	_major_collision_root.add_child(body)
	body.global_position = position
	body.rotation = rotation_value
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
