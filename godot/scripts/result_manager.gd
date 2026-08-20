extends Node

signal round_result_recorded(mode_id: StringName, success: bool, score: int)
signal highlight_event_recorded(mode_id: StringName, event: Dictionary)

const HIGHLIGHT_NORMAL: int = 10
const HIGHLIGHT_COOL: int = 30
const HIGHLIGHT_EPIC: int = 60
const HIGHLIGHT_LEGENDARY: int = 100

const REPLAY_SAMPLE_INTERVAL: float = 0.10
const REPLAY_SECONDS: float = 4.0
const REPLAY_MAX_SAMPLES: int = 40
const REPLAY_MAX_RACERS: int = 5

var round_results: Array[Dictionary] = []
var _pending_highlights_by_mode: Dictionary = {}
var _replay_samples: Array[Dictionary] = []
var _replay_sample_elapsed: float = 0.0
var _replay_mode_id: StringName = &""

func _process(delta: float) -> void:
	if not _should_sample_replay():
		_replay_sample_elapsed = 0.0
		return
	var mode_id: StringName = GameManager.get_current_round_id()
	if mode_id != _replay_mode_id:
		_replay_mode_id = mode_id
		_replay_samples.clear()
		_replay_sample_elapsed = 0.0
	_replay_sample_elapsed += delta
	if _replay_sample_elapsed < REPLAY_SAMPLE_INTERVAL:
		return
	_replay_sample_elapsed = fmod(_replay_sample_elapsed, REPLAY_SAMPLE_INTERVAL)
	_capture_replay_sample(mode_id)

func reset_campaign() -> void:
	round_results.clear()
	_pending_highlights_by_mode.clear()
	_replay_samples.clear()
	_replay_sample_elapsed = 0.0
	_replay_mode_id = &""

func record_highlight_event(mode_id: StringName, event: Dictionary) -> void:
	if event.is_empty():
		return
	var key: String = String(mode_id)
	var existing_value: Variant = _pending_highlights_by_mode.get(key, [])
	var existing: Array = existing_value if existing_value is Array else []
	var copy: Dictionary = event.duplicate(true)
	copy["mode_id"] = mode_id
	copy["type"] = StringName(copy.get("type", &"wild_moment"))
	copy["racer"] = String(copy.get("racer", "PLAYER"))
	copy["target"] = String(copy.get("target", ""))
	copy["timestamp"] = float(copy.get("timestamp", _highlight_timestamp()))
	copy["importance"] = clampi(int(copy.get("importance", HIGHLIGHT_NORMAL)), HIGHLIGHT_NORMAL, HIGHLIGHT_LEGENDARY)
	copy["zone"] = String(copy.get("zone", ""))
	copy["title"] = String(copy.get("title", "WILD MOMENT!"))
	copy["description"] = String(copy.get("description", "Great play!"))
	var metadata_value: Variant = copy.get("metadata", {})
	copy["metadata"] = metadata_value.duplicate(true) if metadata_value is Dictionary else {}
	copy["round"] = GameManager.current_round_index + 1
	if int(copy["importance"]) >= HIGHLIGHT_EPIC:
		var clip: Array = _snapshot_replay_clip(mode_id)
		if not clip.is_empty():
			copy["replay_clip"] = clip
			copy["replay_ready"] = true
	existing.append(copy)
	while existing.size() > 16:
		existing.pop_front()
	_pending_highlights_by_mode[key] = existing
	print("WILD HIGHLIGHT EVENT type=%s importance=%d round=%d racer=%s target=%s zone=%s replay=%s" % [
		String(copy["type"]), int(copy["importance"]), int(copy["round"]), String(copy["racer"]),
		String(copy["target"]), String(copy["zone"]), str(bool(copy.get("replay_ready", false))),
	])
	highlight_event_recorded.emit(mode_id, copy)

func record_round_result(mode_id: StringName, success: bool, score: int, details: Dictionary = {}) -> void:
	var highlights: Array = _consume_pending_highlights(mode_id)
	var detail_highlights_value: Variant = details.get("highlight_events", [])
	if detail_highlights_value is Array:
		for value: Variant in detail_highlights_value:
			if value is Dictionary:
				highlights.append((value as Dictionary).duplicate(true))
	var entry: Dictionary = {
		"mode_id": mode_id,
		"success": success,
		"score": score,
		"details": details.duplicate(true),
		"highlights": highlights,
	}
	round_results.append(entry)
	round_result_recorded.emit(mode_id, success, score)

func _consume_pending_highlights(mode_id: StringName) -> Array:
	var key: String = String(mode_id)
	var value: Variant = _pending_highlights_by_mode.get(key, [])
	_pending_highlights_by_mode.erase(key)
	var result: Array = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result

func _should_sample_replay() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if not GameManager.campaign_running or not GameManager.round_active:
		return false
	if not GameManager.is_gameplay_state() or not RaceManager.active:
		return false
	return not RaceManager.racers.is_empty()

func _capture_replay_sample(mode_id: StringName) -> void:
	var player_racer: WildDashCharacterController = null
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer != null and is_instance_valid(racer) and racer.is_player:
			player_racer = racer
			break
	if player_racer == null:
		return
	var nearby: Array = []
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer == player_racer:
			continue
		nearby.append({
			"racer": racer,
			"distance": player_racer.global_position.distance_squared_to(racer.global_position),
		})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	var racers_data: Array = [_replay_racer_state(player_racer)]
	for i: int in range(mini(REPLAY_MAX_RACERS - 1, nearby.size())):
		var racer_value: Variant = (nearby[i] as Dictionary).get("racer", null)
		var racer := racer_value as WildDashCharacterController
		if racer != null and is_instance_valid(racer):
			racers_data.append(_replay_racer_state(racer))
	_replay_samples.append({
		"mode_id": mode_id,
		"timestamp": _highlight_timestamp(),
		"racers": racers_data,
	})
	while _replay_samples.size() > REPLAY_MAX_SAMPLES:
		_replay_samples.pop_front()

func _replay_racer_state(racer: WildDashCharacterController) -> Dictionary:
	return {
		"name": RaceManager.get_racer_label(racer),
		"player": racer.is_player,
		"position": racer.global_position,
		"rotation": racer.rotation,
		"action": _replay_action_state(racer),
	}

func _replay_action_state(racer: WildDashCharacterController) -> String:
	if racer.finished:
		return "finished"
	if not racer.is_on_floor():
		return "airborne"
	if racer.current_speed > 1.0:
		return "moving"
	return "idle"

func _snapshot_replay_clip(mode_id: StringName) -> Array:
	var result: Array = []
	for sample: Dictionary in _replay_samples:
		if StringName(sample.get("mode_id", &"")) == mode_id:
			result.append(sample.duplicate(true))
	return result

func _highlight_timestamp() -> float:
	if RaceManager.active:
		return RaceManager.get_elapsed_seconds()
	return float(Time.get_ticks_msec()) / 1000.0

func get_latest_round_result() -> Dictionary:
	if round_results.is_empty():
		return {}
	return round_results[round_results.size() - 1].duplicate(true)

func get_round_result(index: int) -> Dictionary:
	if index < 0 or index >= round_results.size():
		return {}
	return round_results[index].duplicate(true)

func get_success_count() -> int:
	var count := 0
	for entry: Dictionary in round_results:
		if bool(entry.get("success", false)):
			count += 1
	return count

func get_campaign_total_score() -> int:
	var total: int = 0
	for entry: Dictionary in round_results:
		total += get_round_points(entry)
	return total

func get_round_points(entry: Dictionary) -> int:
	if entry.is_empty():
		return 0
	var total: int = 1000 if bool(entry.get("success", false)) else 0
	var mode_id: StringName = StringName(entry.get("mode_id", &"unknown"))
	var raw_score: int = int(entry.get("score", 0))
	var details_value: Variant = entry.get("details", {})
	var details: Dictionary = details_value as Dictionary if typeof(details_value) == TYPE_DICTIONARY else {}
	match mode_id:
		&"grand_prix", &"neon_harbor_race", &"snowpeak_winter_rally", &"tidal_clash":
			var rank: int = int(details.get("rank", raw_score))
			var racers: int = maxi(1, int(details.get("racers", GameManager.ai_count + 1)))
			if rank > 0 and rank <= racers:
				total += int(round((float(racers - rank + 1) / float(racers)) * 1000.0))
		&"fruit_collection":
			var target: int = maxi(1, int(details.get("target", 8)))
			if raw_score < target:
				total += int(round(clampf(float(raw_score) / float(target), 0.0, 1.0) * 700.0))
			elif raw_score < 12:
				total += 800 + clampi(raw_score - target, 0, 3) * 25
			elif raw_score < 16:
				total += 900 + clampi(raw_score - 12, 0, 3) * 25
			else:
				total += 1000
		&"push_out":
			var racers: int = maxi(1, int(details.get("racers", GameManager.ai_count + 1)))
			var placement: int = clampi(int(details.get("placement", racers)), 1, racers)
			if placement == 1:
				total += 1100
			elif placement == 2:
				total += 850
			elif placement == 3:
				total += 700
			else:
				var placement_ratio: float = float(racers - placement + 1) / float(racers)
				total += int(round(placement_ratio * 600.0))
		_:
			total += clampi(raw_score, 0, 1000)
	return total

func get_round_display_name(mode_id: StringName) -> String:
	match mode_id:
		&"grand_prix": return "WILD WORLD GRAND PRIX"
		&"fruit_collection": return "FRUIT FRENZY"
		&"logspire_leap": return "LOGSPIRE LEAP"
		&"push_out": return "WILD RUMBLE"
		&"neon_harbor_race": return "NEON HARBOR"
		&"tidal_clash": return "TIDAL CLASH"
		_: return String(mode_id).replace("_", " ").to_upper()

func get_round_tagline(mode_id: StringName) -> String:
	match mode_id:
		&"grand_prix": return "RACE · BOOST · OVERTAKE"
		&"fruit_collection": return "GRAB · FIGHT · BANK"
		&"logspire_leap": return "RUN · JUMP · SURVIVE"
		&"push_out": return "BASH · BREAK · RING OUT"
		&"neon_harbor_race": return "DASH · DODGE · FINISH"
		&"tidal_clash": return "SWIM · CLASH · ESCAPE"
		_: return "GET READY"

func get_round_summary_lines(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty():
		return lines
	var mode_id: StringName = StringName(entry.get("mode_id", &"unknown"))
	var raw_score: int = int(entry.get("score", 0))
	var details_value: Variant = entry.get("details", {})
	var details: Dictionary = details_value as Dictionary if typeof(details_value) == TYPE_DICTIONARY else {}
	match mode_id:
		&"grand_prix", &"neon_harbor_race", &"tidal_clash":
			var rank: int = int(details.get("rank", raw_score))
			var racers: int = maxi(1, int(details.get("racers", GameManager.ai_count + 1)))
			lines.append("FINISH  #%d / %d" % [rank, racers])
			if details.has("overtakes"):
				lines.append("OVERTAKES  %d" % int(details.get("overtakes", 0)))
		&"fruit_collection":
			lines.append("BANKED SCORE  %d / %d" % [raw_score, maxi(1, int(details.get("target", 8)))])
			if details.has("golden_fruit") or details.has("golden_fruits"):
				lines.append("GOLDEN FRUIT  %d" % int(details.get("golden_fruits", details.get("golden_fruit", 0))))
			if details.has("steals"):
				lines.append("STEALS  %d" % int(details.get("steals", 0)))
			elif details.has("spills"):
				lines.append("SPILLS  %d" % int(details.get("spills", 0)))
		&"logspire_leap":
			if details.has("rank"):
				lines.append("FINISH  #%d / %d" % [int(details.get("rank", raw_score)), maxi(1, int(details.get("racers", GameManager.ai_count + 1)))])
			else:
				lines.append("ROUND SCORE  %d" % raw_score)
			if details.has("falls"):
				lines.append("FALLS  %d" % int(details.get("falls", 0)))
			if details.has("recoveries"):
				lines.append("RECOVERIES  %d" % int(details.get("recoveries", 0)))
			if details.has("route"):
				lines.append("ROUTE  %s" % String(details.get("route", "SAFE")).to_upper())
		&"push_out":
			var racers: int = maxi(1, int(details.get("racers", GameManager.ai_count + 1)))
			lines.append("PLACEMENT  #%d / %d" % [clampi(int(details.get("placement", racers)), 1, racers), racers])
			if details.has("kos"):
				lines.append("KO  %d" % int(details.get("kos", 0)))
			if details.has("ring_outs"):
				lines.append("RING OUTS  %d" % int(details.get("ring_outs", 0)))
		_:
			lines.append("ROUND SCORE  %d" % raw_score)
	return lines

func get_highlights_for_entry(entry: Dictionary, max_count: int = 2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if entry.is_empty() or max_count <= 0:
		return result
	var value: Variant = entry.get("highlights", [])
	var candidates: Array = value if value is Array else []
	var sorted: Array[Dictionary] = []
	for item: Variant in candidates:
		if item is Dictionary:
			sorted.append((item as Dictionary).duplicate(true))
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ai: int = int(a.get("importance", 0))
		var bi: int = int(b.get("importance", 0))
		if ai == bi:
			return float(a.get("timestamp", 0.0)) > float(b.get("timestamp", 0.0))
		return ai > bi
	)
	for item: Dictionary in sorted:
		result.append(item)
		print("WILD HIGHLIGHT SELECTED type=%s importance=%d round=%d racer=%s" % [
			String(item.get("type", &"wild_moment")), int(item.get("importance", 0)),
			int(item.get("round", GameManager.current_round_index + 1)), String(item.get("racer", "PLAYER")),
		])
		if result.size() >= max_count:
			break
	return result

func get_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in round_results:
		var mode_id: String = String(entry.get("mode_id", &"unknown"))
		var success: bool = bool(entry.get("success", false))
		var score: int = int(entry.get("score", 0))
		lines.append("%s  %s  score=%d" % [mode_id, "CLEAR" if success else "MISS", score])
	return lines
