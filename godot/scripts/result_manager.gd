extends Node

signal round_result_recorded(mode_id: StringName, success: bool, score: int)

var round_results: Array[Dictionary] = []

func reset_campaign() -> void:
	round_results.clear()

func record_round_result(mode_id: StringName, success: bool, score: int, details: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"mode_id": mode_id,
		"success": success,
		"score": score,
		"details": details.duplicate(true),
	}
	round_results.append(entry)
	round_result_recorded.emit(mode_id, success, score)

func get_success_count() -> int:
	var count := 0
	for entry: Dictionary in round_results:
		if bool(entry.get("success", false)):
			count += 1
	return count

func get_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in round_results:
		var mode_id: String = String(entry.get("mode_id", &"unknown"))
		var success: bool = bool(entry.get("success", false))
		var score: int = int(entry.get("score", 0))
		lines.append("%s  %s  score=%d" % [mode_id, "CLEAR" if success else "MISS", score])
	return lines
