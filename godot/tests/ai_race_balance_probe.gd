extends Node

const GRAND_PRIX_SCENE: PackedScene = preload("res://modes/grand_prix/grand_prix.tscn")
const SAMPLE_INTERVAL := 0.25
const PERMANENT_STALL_SECONDS := 12.0

var _target_racers := 15
var _run_index := 1
var _run_total := 1
var _seed := 1
var _sample_elapsed := 0.0
var _reported := false
var _previous_progress: Dictionary = {}
var _stagnant_seconds: Dictionary = {}
var _max_stagnant_seconds: Dictionary = {}
var _previous_ranks: Dictionary = {}
var _rank_changes := 0
var _item_pickups := 0
var _item_uses := 0
var _skill_uses := 0
var _finish_times: Array[float] = []
var _animal_results: Dictionary = {}

func _ready() -> void:
	_target_racers = clampi(int(OS.get_environment("WILDDASH_BALANCE_RACERS")) if OS.has_environment("WILDDASH_BALANCE_RACERS") else 15, 15, 18)
	_run_index = maxi(1, int(OS.get_environment("WILDDASH_BALANCE_RUN_INDEX")) if OS.has_environment("WILDDASH_BALANCE_RUN_INDEX") else 1)
	_run_total = maxi(1, int(OS.get_environment("WILDDASH_BALANCE_RUNS")) if OS.has_environment("WILDDASH_BALANCE_RUNS") else 1)
	_seed = int(OS.get_environment("WILDDASH_BALANCE_SEED")) if OS.has_environment("WILDDASH_BALANCE_SEED") else _run_index
	var difficulty: StringName = &"nightmare" if _target_racers >= 18 else &"chaos"

	GameManager.reset_run()
	GameManager.configure_run(&"dog", difficulty, {}, _target_racers - 1)
	GameManager.current_round_index = 0
	GameManager.campaign_running = true
	GameManager.chimera_enabled = false

	ItemSystem.item_granted.connect(_on_item_granted)
	ItemSystem.item_used.connect(_on_item_used)
	SkillSystem.skill_used.connect(_on_skill_used)
	RaceManager.racer_finished.connect(_on_racer_finished)
	RaceManager.race_completed.connect(_on_race_completed)

	var grand_prix := GRAND_PRIX_SCENE.instantiate()
	if grand_prix == null:
		_fail("Grand Prix scene did not instantiate")
		return
	add_child(grand_prix)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_seed_samples()
	print("AI_BALANCE_START racers=%d difficulty=%s run=%d/%d seed=%d" % [
		_target_racers, String(difficulty), _run_index, _run_total, _seed,
	])

func _physics_process(delta: float) -> void:
	if _reported or not RaceManager.active:
		return
	var elapsed := RaceManager.get_elapsed_seconds()
	var timeout_seconds := 275.0 if _target_racers >= 18 else 255.0
	if elapsed > timeout_seconds:
		_fail("race timeout %.1fs > %.1fs" % [elapsed, timeout_seconds])
		return
	_sample_elapsed += delta
	if _sample_elapsed < SAMPLE_INTERVAL:
		return
	var sample_delta := _sample_elapsed
	_sample_elapsed = 0.0
	_sample_progress_and_ranks(sample_delta)

func _seed_samples() -> void:
	for racer in RaceManager.racers:
		if racer == null or not is_instance_valid(racer):
			continue
		var id := racer.get_instance_id()
		_previous_progress[id] = RaceManager.get_track_progress(racer)
		_previous_ranks[id] = RaceManager.get_rank(racer)
		_stagnant_seconds[id] = 0.0
		_max_stagnant_seconds[id] = 0.0

func _sample_progress_and_ranks(delta: float) -> void:
	for racer in RaceManager.racers:
		if racer == null or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		var id := racer.get_instance_id()
		var progress := RaceManager.get_track_progress(racer)
		var previous_progress := float(_previous_progress.get(id, progress))
		if progress - previous_progress < 0.45:
			_stagnant_seconds[id] = float(_stagnant_seconds.get(id, 0.0)) + delta
		else:
			_stagnant_seconds[id] = 0.0
		_max_stagnant_seconds[id] = maxf(float(_max_stagnant_seconds.get(id, 0.0)), float(_stagnant_seconds[id]))
		_previous_progress[id] = progress

		var rank := RaceManager.get_rank(racer)
		var previous_rank := int(_previous_ranks.get(id, rank))
		if rank != previous_rank:
			_rank_changes += abs(rank - previous_rank)
		_previous_ranks[id] = rank

func _on_item_granted(_character: Node, _item_id: StringName) -> void:
	_item_pickups += 1

func _on_item_used(_character: Node, _item_id: StringName) -> void:
	_item_uses += 1

func _on_skill_used(_character: Node, _skill_id: StringName) -> void:
	_skill_uses += 1

func _on_racer_finished(racer: Node3D, rank: int) -> void:
	var elapsed := RaceManager.get_elapsed_seconds()
	_finish_times.append(elapsed)
	if racer == null or not racer is WildDashCharacterController:
		return
	var animal := String((racer as WildDashCharacterController).animal_id)
	if not _animal_results.has(animal):
		_animal_results[animal] = {"starts": 0, "rank_sum": 0.0, "wins": 0}
	var result: Dictionary = _animal_results[animal]
	result["starts"] = int(result.get("starts", 0)) + 1
	result["rank_sum"] = float(result.get("rank_sum", 0.0)) + float(rank)
	if rank == 1:
		result["wins"] = int(result.get("wins", 0)) + 1
	_animal_results[animal] = result

func _on_race_completed() -> void:
	if _reported:
		return
	_report_and_exit()

func _report_and_exit() -> void:
	_reported = true
	var finishers := RaceManager.finish_order.size()
	var first_finish := _finish_times[0] if not _finish_times.is_empty() else 0.0
	var last_finish := _finish_times[-1] if not _finish_times.is_empty() else RaceManager.get_elapsed_seconds()
	var spread := maxf(0.0, last_finish - first_finish)
	var soft_recoveries := 0
	var hard_recoveries := 0
	var emergency_recoveries := 0
	var collisions := 0
	var overtakes := 0
	var low_speed_seconds := 0.0
	var permanent_stalls := 0
	var max_stall := 0.0

	for driver_node in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		if not driver_node is WildDashAIController:
			continue
		var driver := driver_node as WildDashAIController
		var racer := driver.get_racer()
		if racer == null:
			continue
		var telemetry := driver.get_balance_telemetry()
		soft_recoveries += int(telemetry.get("soft_recoveries", 0))
		hard_recoveries += int(telemetry.get("hard_recoveries", 0))
		emergency_recoveries += int(telemetry.get("emergency_recoveries", 0))
		collisions += int(telemetry.get("collisions", 0))
		overtakes += int(telemetry.get("overtakes", 0))
		low_speed_seconds += float(telemetry.get("low_speed_seconds", 0.0))
		var racer_stall := float(_max_stagnant_seconds.get(racer.get_instance_id(), 0.0))
		max_stall = maxf(max_stall, racer_stall)
		if racer_stall >= PERMANENT_STALL_SECONDS:
			permanent_stalls += 1
		print("AI_BALANCE_RACER racer=%s animal=%s rank=%d cp=%d soft=%d hard=%d emergency=%d collisions=%d overtakes=%d low_speed=%.2f max_stall=%.2f" % [
			racer.name, String(racer.animal_id), RaceManager.get_rank(racer), RaceManager.get_checkpoint_progress(racer),
			int(telemetry.get("soft_recoveries", 0)), int(telemetry.get("hard_recoveries", 0)),
			int(telemetry.get("emergency_recoveries", 0)), int(telemetry.get("collisions", 0)),
			int(telemetry.get("overtakes", 0)), float(telemetry.get("low_speed_seconds", 0.0)), racer_stall,
		])

	for animal in _animal_results.keys():
		var result: Dictionary = _animal_results[animal]
		var starts := maxi(1, int(result.get("starts", 0)))
		var average_rank := float(result.get("rank_sum", 0.0)) / float(starts)
		print("AI_BALANCE_CHARACTER animal=%s starts=%d wins=%d average_rank=%.2f" % [
			String(animal), starts, int(result.get("wins", 0)), average_rank,
		])

	var all_finish := finishers == _target_racers
	var healthy_rank_changes := _rank_changes >= _target_racers
	var interaction_ok := _item_pickups > 0 and _item_uses > 0 and _skill_uses > 0
	var recovery_loop_ok := permanent_stalls == 0
	var target_spread := 65.0 if _target_racers >= 18 else 50.0
	var spread_review := spread <= target_spread

	print("AI_BALANCE_RESULT racers=%d difficulty=%s run=%d/%d seed=%d finishers=%d first=%.2f last=%.2f spread=%.2f target_spread=%.1f rank_changes=%d item_pickups=%d item_uses=%d skill_uses=%d soft=%d hard=%d emergency=%d collisions=%d overtakes=%d low_speed=%.2f permanent_stalls=%d max_stall=%.2f" % [
		_target_racers, String(GameManager.difficulty), _run_index, _run_total, _seed,
		finishers, first_finish, last_finish, spread, target_spread, _rank_changes,
		_item_pickups, _item_uses, _skill_uses, soft_recoveries, hard_recoveries,
		emergency_recoveries, collisions, overtakes, low_speed_seconds, permanent_stalls, max_stall,
	])

	if not spread_review:
		print("AI_BALANCE_SPREAD_REVIEW racers=%d spread=%.2f target<=%.1f" % [_target_racers, spread, target_spread])
	if not all_finish or not healthy_rank_changes or not interaction_ok or not recovery_loop_ok:
		push_error("AI balance safety gate failed all_finish=%s rank_changes=%s interaction=%s recovery=%s" % [
			str(all_finish), str(healthy_rank_changes), str(interaction_ok), str(recovery_loop_ok),
		])
		get_tree().quit(2)
		return
	print("AI_BALANCE_PASS racers=%d run=%d seed=%d" % [_target_racers, _run_index, _seed])
	get_tree().quit(0)

func _fail(message: String) -> void:
	if _reported:
		return
	_reported = true
	push_error("AI_BALANCE_FAIL " + message)
	get_tree().quit(1)
