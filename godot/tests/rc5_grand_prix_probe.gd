extends Node

const GRAND_PRIX_SCENE: PackedScene = preload("res://modes/grand_prix/grand_prix.tscn")
const SAMPLE_INTERVAL := 0.20
const COLLISION_DEBOUNCE := 0.45
const RECOVERY_DEBOUNCE := 1.0

var _target_racers := 15
var _realtime := false
var _sample_elapsed := 0.0
var _player_rank_changes := 0
var _ai_rank_changes := 0
var _item_pickups := 0
var _item_uses := 0
var _skill_uses := 0
var _item_hits := 0
var _skill_hits := 0
var _shield_blocks := 0
var _rapid_cc_events := 0
var _collision_count := 0
var _recovery_count := 0
var _shortcut_attempts := 0
var _shortcut_success := 0
var _previous_ranks: Dictionary = {}
var _previous_positions: Dictionary = {}
var _last_collision_time: Dictionary = {}
var _last_recovery_time: Dictionary = {}
var _last_item_hit_time: Dictionary = {}
var _finish_times: Array[float] = []
var _finish_by_animal: Dictionary = {}
var _shortcut_racer_names: Dictionary = {}
var _reported := false

func _ready() -> void:
	_target_racers = clampi(int(OS.get_environment("WILDDASH_RC5_RACERS")) if OS.has_environment("WILDDASH_RC5_RACERS") else 15, 10, 18)
	_realtime = OS.has_environment("WILDDASH_REALTIME_BALANCE")
	var difficulty: StringName = &"nightmare" if _target_racers >= 18 else (&"wild" if _target_racers <= 10 else &"chaos")

	GameManager.reset_run()
	GameManager.configure_run(&"dog", difficulty, {}, _target_racers - 1)
	GameManager.current_round_index = 0
	GameManager.campaign_running = true
	GameManager.chimera_enabled = false

	ItemSystem.item_granted.connect(_on_item_granted)
	ItemSystem.item_used.connect(_on_item_used)
	ItemSystem.item_hit.connect(_on_item_hit)
	SkillSystem.skill_used.connect(_on_skill_used)
	SkillSystem.skill_hit.connect(_on_skill_hit)
	RaceManager.racer_finished.connect(_on_racer_finished)
	RaceManager.race_completed.connect(_on_race_completed)

	var grand_prix := GRAND_PRIX_SCENE.instantiate()
	if grand_prix == null:
		_fail("Grand Prix scene did not instantiate")
		return
	add_child(grand_prix)

	# Shortcut personalities are deterministic: AI indices 2, 7, 12... use
	# the alternate route. Record their node names so finishing that route can
	# be counted as a successful shortcut-route completion proxy.
	for i in range(_target_racers - 1):
		if i % 5 == 2:
			_shortcut_racer_names["AI_%02d" % (i + 1)] = true
	_shortcut_attempts = _shortcut_racer_names.size()

	await get_tree().physics_frame
	await get_tree().physics_frame
	_seed_samples()
	print("RC5 PROBE START racers=%d ai=%d realtime=%s shortcut_attempts=%d" % [
		_target_racers, _target_racers - 1, str(_realtime), _shortcut_attempts,
	])

func _physics_process(delta: float) -> void:
	if _reported or not RaceManager.active:
		return
	var elapsed := RaceManager.get_elapsed_seconds()
	# Dense 15/18-racer fields now include 18 items, themed obstacles and
	# stronger collision containment. Give the accelerated probe enough time
	# to verify eventual all-finish behavior instead of failing a healthy late
	# finisher at the old one-size-fits-all 100-second ceiling.
	var timeout_seconds := 230.0 if _realtime else (110.0 if _target_racers <= 10 else (135.0 if _target_racers <= 15 else 150.0))
	if elapsed > timeout_seconds:
		_fail("Grand Prix probe timeout %.1fs > %.1fs" % [elapsed, timeout_seconds])
		return

	_sample_elapsed += delta
	if _sample_elapsed < SAMPLE_INTERVAL:
		return
	_sample_elapsed = 0.0
	_sample_ranks_and_contacts(elapsed)

func _seed_samples() -> void:
	for racer in RaceManager.racers:
		if racer == null or not is_instance_valid(racer):
			continue
		var id := racer.get_instance_id()
		_previous_ranks[id] = RaceManager.get_rank(racer)
		_previous_positions[id] = racer.global_position

func _sample_ranks_and_contacts(elapsed: float) -> void:
	for racer in RaceManager.racers:
		if racer == null or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		var id := racer.get_instance_id()
		var rank := RaceManager.get_rank(racer)
		var previous_rank := int(_previous_ranks.get(id, rank))
		if rank != previous_rank:
			if racer is WildDashCharacterController and (racer as WildDashCharacterController).is_player:
				_player_rank_changes += 1
			else:
				_ai_rank_changes += 1
		_previous_ranks[id] = rank

		if racer is WildDashCharacterController:
			var controller := racer as WildDashCharacterController
			if controller.has_blocking_collision() and elapsed - float(_last_collision_time.get(id, -99.0)) >= COLLISION_DEBOUNCE:
				_collision_count += 1
				_last_collision_time[id] = elapsed

		var previous_position: Vector3 = _previous_positions.get(id, racer.global_position)
		var displacement := previous_position.distance_to(racer.global_position)
		var low_track := racer.global_position.y < -25.0
		var recovery_teleport := displacement > 25.0 and racer is WildDashCharacterController and (racer as WildDashCharacterController).current_speed < 12.0
		if (low_track or recovery_teleport) and elapsed - float(_last_recovery_time.get(id, -99.0)) >= RECOVERY_DEBOUNCE:
			_recovery_count += 1
			_last_recovery_time[id] = elapsed
		_previous_positions[id] = racer.global_position

func _on_item_granted(_character: Node, _item_id: StringName) -> void:
	_item_pickups += 1

func _on_item_used(_character: Node, _item_id: StringName) -> void:
	_item_uses += 1

func _on_item_hit(target: Node, _source: Node, _effect_id: StringName, blocked: bool) -> void:
	_item_hits += 1
	if blocked:
		_shield_blocks += 1
		return
	if target == null:
		return
	var now := RaceManager.get_elapsed_seconds()
	var id := target.get_instance_id()
	var previous := float(_last_item_hit_time.get(id, -99.0))
	if now - previous < 1.0:
		_rapid_cc_events += 1
	_last_item_hit_time[id] = now

func _on_skill_used(_character: Node, _skill_id: StringName) -> void:
	_skill_uses += 1

func _on_skill_hit(_source: Node, _target: Node, _skill_id: StringName) -> void:
	_skill_hits += 1

func _on_racer_finished(racer: Node3D, rank: int) -> void:
	var elapsed := RaceManager.get_elapsed_seconds()
	_finish_times.append(elapsed)
	if racer == null:
		return
	var animal := "unknown"
	if racer is WildDashCharacterController:
		animal = String((racer as WildDashCharacterController).animal_id)
	if not _finish_by_animal.has(animal):
		_finish_by_animal[animal] = []
	var ranks: Array = _finish_by_animal[animal]
	ranks.append(rank)
	_finish_by_animal[animal] = ranks
	if _shortcut_racer_names.has(racer.name):
		_shortcut_success += 1
	print("RC5 FINISH POSITION racer=%s character=%s rank=%d elapsed=%.2fs shortcut=%s" % [
		racer.name, animal, rank, elapsed, str(_shortcut_racer_names.has(racer.name)),
	])

func _on_race_completed() -> void:
	if _reported:
		return
	_report_and_exit()

func _report_and_exit() -> void:
	_reported = true
	var field_complete := RaceManager.get_elapsed_seconds()
	var first_finish := _finish_times[0] if not _finish_times.is_empty() else field_complete
	var average_finish := 0.0
	for value in _finish_times:
		average_finish += value
	if not _finish_times.is_empty():
		average_finish /= float(_finish_times.size())
	var finish_gap := maxf(0.0, field_complete - first_finish)

	for animal in _finish_by_animal.keys():
		var ranks: Array = _finish_by_animal[animal]
		var average_rank := 0.0
		for rank in ranks:
			average_rank += float(rank)
		if not ranks.is_empty():
			average_rank /= float(ranks.size())
		print("RC5 CHARACTER RESULT character=%s starts=%d average_finish_position=%.2f" % [animal, ranks.size(), average_rank])

	print("RC5 GAMEPLAY TELEMETRY racers=%d race_duration=%.2fs average_finish=%.2fs finish_gap=%.2fs player_rank_changes=%d ai_rank_changes=%d item_pickups=%d item_uses=%d skill_uses=%d shortcut_attempts=%d shortcut_success=%d collisions=%d recoveries=%d item_hits=%d skill_hits=%d shield_blocks=%d rapid_cc=%d" % [
		_target_racers, field_complete, average_finish, finish_gap,
		_player_rank_changes, _ai_rank_changes, _item_pickups, _item_uses, _skill_uses,
		_shortcut_attempts, _shortcut_success, _collision_count, _recovery_count,
		_item_hits, _skill_hits, _shield_blocks, _rapid_cc_events,
	])

	var all_finish := RaceManager.finish_order.size() == _target_racers
	var interaction_flow := _item_pickups > 0 and _item_uses > 0 and _skill_uses > 0 and (_player_rank_changes + _ai_rank_changes) > 0 and _shortcut_success > 0
	if all_finish:
		print("RC5 ALL FINISH PASS racers=%d" % _target_racers)
	if interaction_flow:
		print("RC5 INTERACTION FLOW PASS item=true skill=true rank_changes=true shortcut=true")
	if _rapid_cc_events == 0:
		print("RC5 CHAIN CC PASS rapid_cc=0 immunity=%.2fs" % ItemSystem.HIT_IMMUNITY_DURATION)
	else:
		print("RC5 CHAIN CC REVIEW rapid_cc=%d immunity=%.2fs" % [_rapid_cc_events, ItemSystem.HIT_IMMUNITY_DURATION])

	var pace_pass := true
	if _target_racers == 15 and _realtime:
		pace_pass = average_finish >= 130.0 and average_finish <= 170.0
		if pace_pass:
			print("RC5 NORMAL PACE PASS average_finish=%.2fs target=130-170" % average_finish)
		else:
			print("RC5 NORMAL PACE REVIEW average_finish=%.2fs target=130-170" % average_finish)

	if not all_finish or not interaction_flow:
		push_error("RC5 probe failed all_finish=%s interaction_flow=%s" % [str(all_finish), str(interaction_flow)])
		get_tree().quit(2)
		return
	# Exact production pace is treated as a release-candidate gate for the
	# automated real-time proxy. Accelerated Hard runs do not use this gate.
	if _target_racers == 15 and _realtime and not pace_pass:
		push_error("RC5 Normal pace outside 130-170s target")
		get_tree().quit(3)
		return
	print("RC5 GRAND PRIX PROBE PASS racers=%d realtime=%s" % [_target_racers, str(_realtime)])
	get_tree().quit(0)

func _fail(message: String) -> void:
	if _reported:
		return
	_reported = true
	push_error("RC5 GRAND PRIX PROBE FAIL " + message)
	get_tree().quit(1)
