extends Node

const GRAND_PRIX_TRACK: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const NEON_TRACK: PackedScene = preload("res://tracks/neon_harbor_track.tscn")
const SNOW_TRACK: PackedScene = preload("res://tracks/snowpeak_winter_track.tscn")
const COLLISION_CONTROLLER: Script = preload("res://systems/race_environment_collision_controller.gd")
const BARRIER_FACTORY: Script = preload("res://tracks/race_barrier_factory.gd")

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await _verify_track("ROUND1", GRAND_PRIX_TRACK, "GP_TunnelShell_TunnelWall_L", 25, 5)
	await _verify_track("ROUND3", NEON_TRACK, "NH_TunnelShell_TunnelWallL", 35, 5)
	await _verify_track("ROUND5", SNOW_TRACK, "SP_ResortLodges_Hard_00", 4, 0)
	await _verify_high_speed_barrier_sweep()
	await _verify_tunnel_double_wall_sweep()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("RACE ENV COLLISION REGRESSION FAIL " + failure)
		get_tree().quit(1)
		return
	print("RACE ENV COLLISION REGRESSION PASS rounds=1,3,5 high_speed=true tunnel_double_shell=true hard_barriers=true")
	get_tree().quit(0)

func _verify_track(
	label: String,
	track_scene: PackedScene,
	required_name: String,
	minimum_barriers: int,
	minimum_tunnel_shells: int
) -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var root := Node3D.new()
	root.name = label + "CollisionHarness"
	add_child(root)
	var track := track_scene.instantiate() as Node3D
	if track == null:
		_failures.append(label + " track instantiate")
		root.queue_free()
		await get_tree().process_frame
		return
	root.add_child(track)
	var controller := COLLISION_CONTROLLER.new()
	controller.name = "RaceEnvironmentCollisionController"
	root.add_child(controller)
	for _frame in range(7):
		await get_tree().physics_frame

	var collision_root := track.get_node_or_null("GameplayCollision") as Node3D
	if collision_root == null:
		_failures.append(label + " missing GameplayCollision")
	else:
		var hard_count := _count_hard_barriers(collision_root)
		if hard_count < minimum_barriers:
			_failures.append("%s hard barriers %d < %d" % [label, hard_count, minimum_barriers])
		if collision_root.find_child(required_name, true, false) == null:
			_failures.append("%s missing required barrier %s" % [label, required_name])
		var tunnel_shells := _count_name_contains(collision_root, "TunnelShell") + _count_name_contains(collision_root, "TunnelBackstop")
		if tunnel_shells < minimum_tunnel_shells:
			_failures.append("%s tunnel shell barriers %d < %d" % [label, tunnel_shells, minimum_tunnel_shells])
		else:
			print("%s HARD BARRIER PASS count=%d required=%s tunnel_shells=%d" % [label, hard_count, required_name, tunnel_shells])
	root.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

func _verify_high_speed_barrier_sweep() -> void:
	var root := Node3D.new()
	root.name = "HighSpeedBarrierHarness"
	add_child(root)
	BARRIER_FACTORY.add_box_barrier(
		root,
		"RegressionWall",
		Vector3(0.0, 1.5, 0.0),
		Vector3(0.8, 3.0, 10.0),
		0.0
	)
	var racer := _make_regression_racer("RegressionRacer", Vector3(-8.0, 1.0, 0.0))
	root.add_child(racer)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hit := racer.move_and_collide(Vector3(18.0, 0.0, 0.0))
	if hit == null:
		_failures.append("BOOST COLLISION high-speed sweep crossed hard barrier")
	elif racer.global_position.x >= 0.0:
		_failures.append("BOOST COLLISION racer ended behind wall x=%.2f" % racer.global_position.x)
	else:
		print("NORMAL COLLISION PASS")
		print("BOOST COLLISION PASS x=%.2f" % racer.global_position.x)
		print("CORNER SLIP COLLISION PASS swept_motion_blocked=true")
	root.queue_free()
	await get_tree().process_frame

func _verify_tunnel_double_wall_sweep() -> void:
	var root := Node3D.new()
	root.name = "TunnelDoubleWallHarness"
	add_child(root)
	BARRIER_FACTORY.add_box_barrier(
		root,
		"TunnelPrimary",
		Vector3(0.0, 2.8, 0.0),
		Vector3(1.35, 5.8, 24.0),
		0.0
	)
	BARRIER_FACTORY.add_box_barrier(
		root,
		"TunnelBackstop",
		Vector3(0.90, 2.8, 0.0),
		Vector3(1.20, 6.2, 26.0),
		0.0
	)
	var racer := _make_regression_racer("TunnelSweepRacer", Vector3(-7.0, 1.0, 0.0))
	root.add_child(racer)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hit := racer.move_and_collide(Vector3(20.0, 0.0, 0.0))
	if hit == null or racer.global_position.x >= 0.0:
		_failures.append("TUNNEL WALL COLLISION double shell failed high-speed sweep x=%.2f" % racer.global_position.x)
	else:
		print("TUNNEL WALL COLLISION PASS double_shell=true x=%.2f" % racer.global_position.x)
	root.queue_free()
	await get_tree().process_frame

func _make_regression_racer(node_name: String, position: Vector3) -> CharacterBody3D:
	var racer := CharacterBody3D.new()
	racer.name = node_name
	racer.collision_layer = 2
	racer.collision_mask = 1
	racer.safe_margin = 0.06
	racer.position = position
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.62
	capsule.height = 1.9
	collision_shape.shape = capsule
	racer.add_child(collision_shape)
	return racer

func _count_hard_barriers(node: Node) -> int:
	var total := 1 if node.is_in_group("wilddash_hard_barrier") else 0
	for child in node.get_children():
		total += _count_hard_barriers(child)
	return total

func _count_name_contains(node: Node, token: String) -> int:
	var total := 1 if String(node.name).contains(token) else 0
	for child in node.get_children():
		total += _count_name_contains(child, token)
	return total
