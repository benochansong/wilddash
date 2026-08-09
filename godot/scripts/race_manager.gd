extends Node

signal race_started
signal racer_finished(racer: Node3D, rank: int)
signal race_finished(rank: int)
signal race_completed

const MAX_RACERS := 50
const MAX_AI_RACERS := 49
const QUALIFYING_RANK := 25
const VERTICAL_SLICE_RACERS := 4

var racers: Array[Node3D] = []
var finish_order: Array[Node3D] = []
var active := false
var _race_started_at_ms := 0

func register_racer(racer: Node3D) -> void:
	if racer == null or racers.has(racer):
		return
	racers.append(racer)

func unregister_racer(racer: Node3D) -> void:
	racers.erase(racer)
	finish_order.erase(racer)

func clear_racers() -> void:
	racers.clear()
	finish_order.clear()

func start_race() -> void:
	finish_order.clear()
	active = true
	_race_started_at_ms = Time.get_ticks_msec()
	GameManager.set_state(GameManager.GameState.RACE)
	race_started.emit()

func record_finish(racer: Node3D) -> int:
	if racer == null:
		return MAX_RACERS
	if finish_order.has(racer):
		return finish_order.find(racer) + 1
	if not racers.has(racer):
		register_racer(racer)

	finish_order.append(racer)
	var rank := finish_order.size()
	if racer is WildDashCharacterController:
		var controller := racer as WildDashCharacterController
		controller.set_finished(rank)

	racer_finished.emit(racer, rank)
	if racer is WildDashCharacterController and (racer as WildDashCharacterController).is_player:
		race_finished.emit(rank)

	if finish_order.size() >= racers.size() and not racers.is_empty():
		active = false
		race_completed.emit()
	return rank

func finish_race(player: Node3D) -> int:
	# Compatibility seam for Prototype-derived callers. The real 3D vertical
	# slice records finish order through FinishLine Area3D.
	return record_finish(player)

func get_rank(racer: Node3D) -> int:
	if racer == null:
		return MAX_RACERS
	if finish_order.has(racer):
		return finish_order.find(racer) + 1

	var progress := get_test_track_progress(racer)
	var ahead := finish_order.size()
	for rival in racers:
		if rival == racer or finish_order.has(rival):
			continue
		if get_test_track_progress(rival) > progress:
			ahead += 1
	return ahead + 1

func get_standings() -> Array[Node3D]:
	var standings := racers.duplicate()
	standings.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var a_finished := finish_order.find(a)
		var b_finished := finish_order.find(b)
		if a_finished >= 0 or b_finished >= 0:
			if a_finished >= 0 and b_finished >= 0:
				return a_finished < b_finished
			return a_finished >= 0
		return get_test_track_progress(a) > get_test_track_progress(b)
	)
	return standings

func get_test_track_progress(racer: Node3D) -> float:
	# Vertical Slice 01 uses a straight track toward negative Z.
	# Production tracks should replace this with checkpoint + Curve3D progress.
	return -racer.global_position.z

func get_elapsed_seconds() -> float:
	if _race_started_at_ms <= 0:
		return 0.0
	return maxf(0.0, (Time.get_ticks_msec() - _race_started_at_ms) / 1000.0)

func get_racer_label(racer: Node3D) -> String:
	if racer is WildDashCharacterController:
		var controller := racer as WildDashCharacterController
		var label := String(controller.animal_id).capitalize()
		if controller.is_player:
			label += " (YOU)"
		return label
	return racer.name

func qualifies(rank: int) -> bool:
	return rank > 0 and rank <= QUALIFYING_RANK
