extends Node

signal race_started
signal race_finished(rank: int)

const MAX_RACERS := 50
const MAX_AI_RACERS := 49
const QUALIFYING_RANK := 25

var racers: Array[Node3D] = []
var active := false

func register_racer(racer: Node3D) -> void:
	if racer == null or racers.has(racer):
		return
	racers.append(racer)

func unregister_racer(racer: Node3D) -> void:
	racers.erase(racer)

func clear_racers() -> void:
	racers.clear()

func start_race() -> void:
	active = true
	GameManager.set_state(GameManager.GameState.RACE)
	race_started.emit()

func finish_race(player: Node3D) -> int:
	var rank := get_rank(player)
	active = false
	race_finished.emit(rank)
	return rank

func get_rank(racer: Node3D) -> int:
	if racer == null:
		return MAX_RACERS
	var progress := get_test_track_progress(racer)
	var ahead := 0
	for rival in racers:
		if rival != racer and get_test_track_progress(rival) > progress:
			ahead += 1
	return ahead + 1

func get_test_track_progress(racer: Node3D) -> float:
	# The first test track runs toward negative Z. Replace this with checkpoint/
	# spline progress when a production track system is introduced.
	return -racer.global_position.z

func qualifies(rank: int) -> bool:
	return rank > 0 and rank <= QUALIFYING_RANK
