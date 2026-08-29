extends "res://modes/fruit_collection/fruit_frenzy_v17_fart_dizzy.gd"

## Round 2 Wild Moments adapter. It observes existing Golden Fruit, spill, steal
## and late-bank outcomes without changing scoring, carry limits or combat.

var _wm_recorded_counts: Dictionary = {}

func _ready() -> void:
	await super()
	print("WILD MOMENTS R2 READY golden=true spill=true steal=true last_bank=true")

func _try_pickup_golden_fruit(racer: WildDashCharacterController) -> void:
	var was_active: bool = _golden_active
	var carry_before: int = _get_carry(racer)
	super(racer)
	if racer == null or not racer.is_player:
		return
	if was_active and not _golden_active and _get_carry(racer) >= carry_before + 3:
		_record_r2_highlight(
			&"golden_fruit",
			ResultManager.HIGHLIGHT_LEGENDARY,
			"GOLDEN FRUIT!",
			"RARE FRUIT CLAIMED · +3 CARRY",
			{"carry_after": _get_carry(racer)}
		)

func _try_pickup_spill_fruit(racer: WildDashCharacterController) -> void:
	var carry_before: int = _get_carry(racer)
	super(racer)
	if racer == null or not racer.is_player:
		return
	var stolen: int = _get_carry(racer) - carry_before
	if stolen <= 0:
		return
	var count: int = int(_wm_recorded_counts.get("steal", 0)) + 1
	_wm_recorded_counts["steal"] = count
	if count <= 2:
		_record_r2_highlight(
			&"fruit_steal",
			ResultManager.HIGHLIGHT_COOL,
			"FRUIT STEAL!",
			"STOLEN FRUIT RECOVERED · +%d" % stolen,
			{"stolen": stolen, "steal_count": count}
		)

func _spill_racer(racer: WildDashCharacterController, amount: int, reason: String) -> void:
	var carry_before: int = _get_carry(racer)
	super(racer, amount, reason)
	if racer == null:
		return
	var spilled: int = carry_before - _get_carry(racer)
	if spilled < 2:
		return
	if reason == "PLAYER BODY CHECK" and not racer.is_player:
		_record_r2_highlight(
			&"big_spill",
			ResultManager.HIGHLIGHT_EPIC,
			"BIG SPILL!",
			"%d FRUITS KNOCKED LOOSE" % spilled,
			{"spilled": spilled, "victim": RaceManager.get_racer_label(racer)}
		)
	elif racer.is_player and not bool(_wm_recorded_counts.get("player_spill", false)):
		_wm_recorded_counts["player_spill"] = true
		_record_r2_highlight(
			&"wild_spill",
			ResultManager.HIGHLIGHT_COOL,
			"FRUIT EXPLOSION!",
			"%d FRUITS SPILLED · GET THEM BACK" % spilled,
			{"spilled": spilled}
		)

func _bank_racer(racer: WildDashCharacterController) -> void:
	var carry_before: int = _get_carry(racer)
	var bank_before: int = _get_banked(racer)
	var late: bool = racer != null and racer.is_player and carry_before > 0 and time_remaining <= 7.0
	super(racer)
	if not late or racer == null:
		return
	var gained: int = _get_banked(racer) - bank_before
	if gained > 0 and not bool(_wm_recorded_counts.get("last_bank", false)):
		_wm_recorded_counts["last_bank"] = true
		_record_r2_highlight(
			&"last_second_bank",
			ResultManager.HIGHLIGHT_EPIC,
			"LAST SECOND BANK!",
			"+%d PTS WITH %.1f SEC LEFT" % [gained, maxf(0.0, time_remaining)],
			{"banked": gained, "time_left": time_remaining}
		)

func _record_r2_highlight(
	type_id: StringName,
	importance: int,
	title: String,
	description: String,
	metadata: Dictionary
) -> void:
	ResultManager.record_highlight_event(&"fruit_collection", {
		"type": type_id,
		"racer": RaceManager.get_racer_label(player) if player != null else "PLAYER",
		"target": "FRUIT FIELD",
		"importance": importance,
		"zone": "HARVEST HEIST",
		"title": title,
		"description": description,
		"metadata": metadata,
	})
