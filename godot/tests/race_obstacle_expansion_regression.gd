extends Node

const GRAND_PRIX_TRACK: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const NEON_TRACK: PackedScene = preload("res://tracks/neon_harbor_track.tscn")
const SNOW_TRACK: PackedScene = preload("res://tracks/snowpeak_winter_track.tscn")
const OBSTACLE_CONTROLLER: Script = preload("res://tracks/race_obstacle_expansion_controller.gd")

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await _verify_track("ROUND1", GRAND_PRIX_TRACK, 4)
	await _verify_track("ROUND3", NEON_TRACK, 5)
	await _verify_track("ROUND5", SNOW_TRACK, 4)
	if not _failures.is_empty():
		for failure in _failures:
			push_error("RACE OBSTACLE EXPANSION REGRESSION FAIL " + failure)
		get_tree().quit(1)
		return
	print("RACE OBSTACLE EXPANSION REGRESSION PASS rounds=1,3,5 safe_lane=true warnings=true")
	get_tree().quit(0)

func _verify_track(label: String, scene: PackedScene, minimum_count: int) -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var harness := Node3D.new()
	harness.name = label + "ObstacleHarness"
	add_child(harness)
	var track := scene.instantiate() as Node3D
	if track == null:
		_failures.append(label + " track instantiate")
		return
	harness.add_child(track)
	var controller: WildDashRaceObstacleExpansionController = OBSTACLE_CONTROLLER.new() as WildDashRaceObstacleExpansionController
	controller.name = "RaceObstacleExpansionController"
	harness.add_child(controller)
	for _frame in range(9):
		await get_tree().physics_frame
	var count := controller.get_obstacle_count()
	var warnings := controller.get_warning_count()
	if count < minimum_count:
		_failures.append("%s obstacles %d < %d" % [label, count, minimum_count])
	if warnings < minimum_count:
		_failures.append("%s warnings %d < %d" % [label, warnings, minimum_count])
	var expanded := controller.get_tree().get_nodes_in_group("wilddash_race_obstacle_expansion")
	var valid_for_harness := 0
	for obstacle in expanded:
		if not harness.is_ancestor_of(obstacle):
			continue
		valid_for_harness += 1
		if not obstacle is CollisionObject3D:
			_failures.append("%s non-collision obstacle %s" % [label, obstacle.name])
			continue
		var collision_object := obstacle as CollisionObject3D
		if collision_object.collision_layer != 1:
			_failures.append("%s obstacle layer %s=%d" % [label, obstacle.name, collision_object.collision_layer])
		if not bool(obstacle.get_meta(&"safe_lane_preserved", false)):
			_failures.append("%s obstacle missing safe-lane marker %s" % [label, obstacle.name])
	if valid_for_harness < minimum_count:
		_failures.append("%s grouped obstacles %d < %d" % [label, valid_for_harness, minimum_count])
	else:
		print("%s OBSTACLE PASS count=%d warnings=%d safe_lane=true" % [label, count, warnings])
	harness.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
