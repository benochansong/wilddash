extends "res://modes/fruit_collection/fruit_frenzy_v13_vertical_readability.gd"

## Staged Monkey AI climb execution for tall-tree fruit.
## Target selection stays owned by the V12 intent planner; this layer converts a
## locked TREE target into readable trunk -> low -> mid -> high -> fruit movement.

var _v14_monkey_stage_by_id: Dictionary = {}

func _ready() -> void:
	await super()
	for racer: WildDashCharacterController in ai_racers:
		if racer != null and racer.animal_id == &"monkey":
			_v14_monkey_stage_by_id[racer.get_instance_id()] = 0
	print("FRUIT FRENZY V14 MONKEY CLIMB READY staged=true trunk_low_mid_high_fruit=true fallback=ground")

func _try_ai_vertical_assist(racer: WildDashCharacterController) -> void:
	if racer == null or racer.animal_id != &"monkey":
		super(racer)
		return
	var id: int = racer.get_instance_id()
	var fruit_index: int = int(_v12_target_fruit_by_id.get(id, -1))
	if fruit_index < 0 or fruit_index >= fruits.size() or not fruit_active[fruit_index]:
		_v14_monkey_stage_by_id[id] = 0
		super(racer)
		return
	var fruit: MeshInstance3D = fruits[fruit_index]
	if WildDashFruitAccessSystem.get_access_type(fruit) != WildDashFruitAccessSystem.FruitAccessType.TREE:
		_v14_monkey_stage_by_id[id] = 0
		super(racer)
		return
	var tree_index: int = int(fruit.get_meta(&"wilddash_tree_index", -1))
	if tree_index < 0 or tree_index >= V12_TREE_CENTERS.size():
		super(racer)
		return

	var center: Vector3 = V12_TREE_CENTERS[tree_index]
	var top_height: float = V12_TREE_TOP_HEIGHTS[tree_index]
	var low_y: float = top_height * 0.38
	var mid_y: float = top_height * 0.61
	var high_y: float = top_height * 0.82
	var stage: int = 0
	if racer.global_position.y >= high_y - 0.25:
		stage = 4
	elif racer.global_position.y >= mid_y - 0.25:
		stage = 3
	elif racer.global_position.y >= low_y - 0.25:
		stage = 2
	elif racer.global_position.y >= 0.70:
		stage = 1
	_v14_monkey_stage_by_id[id] = stage

	var stage_target: Vector3 = center
	match stage:
		0:
			stage_target = center + Vector3(1.10, low_y, 0.0)
		1:
			stage_target = center + Vector3(1.10, low_y, 0.0)
		2:
			stage_target = center + Vector3(-0.95, mid_y, 0.45)
		3:
			stage_target = center + Vector3(0.70, high_y, -0.25)
		_:
			stage_target = fruit.global_position

	var planar: Vector3 = stage_target - racer.global_position
	planar.y = 0.0
	var horizontal_distance: float = planar.length()
	if horizontal_distance > 2.4 and stage <= 1:
		# Let the arena driver complete the ground approach before climb assistance.
		return
	if planar.length_squared() > 0.001:
		var horizontal_velocity: Vector3 = planar.normalized() * minf(2.25, maxf(0.75, horizontal_distance * 1.2))
		racer.velocity.x = horizontal_velocity.x
		racer.velocity.z = horizontal_velocity.z
	if racer.global_position.y < fruit.global_position.y - 0.30:
		racer.velocity.y = maxf(racer.velocity.y, 7.15)
	_ai_vertical_assist_cooldown[id] = 0.22

	if stage >= 4 and horizontal_distance <= 1.8:
		var canopy: WildDashCanopyTraversalSystem = _phase3_ai_canopy_by_id.get(id, null) as WildDashCanopyTraversalSystem
		if canopy != null and not canopy.is_swinging():
			var route: WildDashCanopyVineRoute = canopy.find_nearest_vine(racer.global_position, 3.2)
			if route != null:
				canopy.grab_vine(racer, route)
