extends "res://modes/push_out/wild_rumble_round4_result_balance.gd"

## Round 4 Wild Moments adapter. Permanent elimination, scoring and crown logic
## remain unchanged; this layer records player ring-outs and the Titan finish.

const RING_OUT_STREAK_SECONDS: float = 6.0

var _wm_last_ring_out_time: float = -999.0
var _wm_ring_out_streak: int = 0
var _wm_final_three_recorded: bool = false
var _wm_champion_recorded: bool = false

func _ready() -> void:
	await super()
	print("WILD MOMENTS R4 READY ring_out=true streak=true final_three=true champion=true")

func _ring_out(victim: WildDashCharacterController) -> void:
	if victim == null or mode_finished or not _is_combatant_active(victim):
		return
	var victim_id: int = victim.get_instance_id()
	var attacker: WildDashCharacterController = _last_attacker.get(victim_id, null) as WildDashCharacterController
	var credited: bool = attacker != null and is_instance_valid(attacker) and attacker != victim
	credited = credited and float(_last_hit_age.get(victim_id, ATTACK_CREDIT_WINDOW + 1.0)) <= ATTACK_CREDIT_WINDOW
	var alive_after: int = maxi(0, _round4_alive_count() - 1)

	if credited and attacker == player:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _wm_last_ring_out_time <= RING_OUT_STREAK_SECONDS:
			_wm_ring_out_streak += 1
		else:
			_wm_ring_out_streak = 1
		_wm_last_ring_out_time = now
		var importance: int = ResultManager.HIGHLIGHT_EPIC if _wm_ring_out_streak >= 2 else ResultManager.HIGHLIGHT_COOL
		var title: String = "DOUBLE RING OUT!" if _wm_ring_out_streak >= 2 else "RING OUT!"
		ResultManager.record_highlight_event(&"push_out", {
			"type": &"ring_out",
			"racer": RaceManager.get_racer_label(player),
			"target": RaceManager.get_racer_label(victim),
			"importance": importance,
			"zone": "TITAN ARENA",
			"title": title,
			"description": "%s SENT OUT · %d RACERS LEFT" % [victim.get_display_name().to_upper(), alive_after],
			"metadata": {"streak": _wm_ring_out_streak, "alive_after": alive_after},
		})

	if alive_after == 3 and victim != player and _is_combatant_active(player) and not _wm_final_three_recorded:
		_wm_final_three_recorded = true
		ResultManager.record_highlight_event(&"push_out", {
			"type": &"final_three",
			"racer": RaceManager.get_racer_label(player),
			"target": "FINAL THREE",
			"importance": ResultManager.HIGHLIGHT_EPIC,
			"zone": "TITAN ARENA",
			"title": "FINAL THREE!",
			"description": "PLAYER SURVIVED INTO THE FINAL THREE",
			"metadata": {"alive_after": alive_after},
		})

	super(victim)

func _finish_last_survivor() -> void:
	if not mode_finished and player != null and _is_combatant_active(player) and not _wm_champion_recorded:
		_wm_champion_recorded = true
		ResultManager.record_highlight_event(&"push_out", {
			"type": &"titan_champion",
			"racer": RaceManager.get_racer_label(player),
			"target": "TITAN CROWN",
			"importance": ResultManager.HIGHLIGHT_LEGENDARY,
			"zone": "TITAN ARENA",
			"title": "TITAN CHAMPION!",
			"description": "LAST RACER STANDING · CROWN SECURED",
			"metadata": {"placement": 1},
		})
	super()
