extends "res://modes/grand_prix/grand_prix_v6_item_fairness.gd"

## Round 1 Wild Moments adapter. Gameplay remains owned by V6; this layer only
## observes rank changes and records a few high-value race-story events.

const OVERTAKE_WINDOW_SECONDS: float = 4.0

var _wm_last_rank: int = -1
var _wm_window_rank: int = -1
var _wm_window_started: float = 0.0
var _wm_overtakes: int = 0
var _wm_recorded: Dictionary = {}

func _ready() -> void:
	await super()
	if player != null:
		_wm_last_rank = RaceManager.get_rank(player)
		_wm_window_rank = _wm_last_rank
		_wm_window_started = RaceManager.get_elapsed_seconds()
	print("WILD MOMENTS R1 READY overtake_window=%.1fs" % OVERTAKE_WINDOW_SECONDS)

func _process(delta: float) -> void:
	super._process(delta)
	if player == null or mode_finished or not RaceManager.active:
		return
	var rank: int = RaceManager.get_rank(player)
	if rank <= 0:
		return
	var elapsed: float = RaceManager.get_elapsed_seconds()
	if _wm_last_rank <= 0:
		_wm_last_rank = rank
	if _wm_window_rank <= 0 or elapsed - _wm_window_started > OVERTAKE_WINDOW_SECONDS:
		_wm_window_rank = rank
		_wm_window_started = elapsed

	if rank < _wm_last_rank:
		var gained: int = _wm_last_rank - rank
		_wm_overtakes += gained
		if rank == 1 and _wm_last_rank > 1 and not bool(_wm_recorded.get("lead_retake", false)):
			_wm_recorded["lead_retake"] = true
			_record_r1_highlight(
				&"lead_retake",
				ResultManager.HIGHLIGHT_LEGENDARY,
				"BACK IN FRONT!",
				"1ST PLACE RECLAIMED",
				{"rank_before": _wm_last_rank, "rank_after": rank}
			)
		var window_gain: int = _wm_window_rank - rank
		if window_gain >= 3 and not bool(_wm_recorded.get("overtake_combo", false)):
			_wm_recorded["overtake_combo"] = true
			_record_r1_highlight(
				&"overtake_combo",
				ResultManager.HIGHLIGHT_EPIC,
				"EPIC OVERTAKE",
				"%d RACERS PASSED IN %.1f SEC" % [window_gain, maxf(0.1, elapsed - _wm_window_started)],
				{"positions_gained": window_gain, "rank_after": rank}
			)
		var progress: float = RaceManager.get_progress_percent(player)
		if progress >= 90.0 and gained >= 2 and not bool(_wm_recorded.get("final_charge", false)):
			_wm_recorded["final_charge"] = true
			_record_r1_highlight(
				&"final_charge",
				ResultManager.HIGHLIGHT_EPIC,
				"FINAL CHARGE!",
				"%d PLACES GAINED NEAR THE FINISH" % gained,
				{"progress": progress, "positions_gained": gained}
			)
	_wm_last_rank = rank

func _record_r1_highlight(
	type_id: StringName,
	importance: int,
	title: String,
	description: String,
	metadata: Dictionary
) -> void:
	ResultManager.record_highlight_event(&"grand_prix", {
		"type": type_id,
		"racer": RaceManager.get_racer_label(player),
		"target": "FIELD",
		"timestamp": RaceManager.get_elapsed_seconds(),
		"importance": importance,
		"zone": "RACE",
		"title": title,
		"description": description,
		"metadata": metadata,
	})
