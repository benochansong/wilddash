extends "res://scenes/result.gd"

## RC9 result rules aligned with the active campaign contracts.
## Round 2 uses an explicit 8-point bank target and performance grades.
## Round 4 Titan Crown reports placement/finalist/champion instead of the retired
## `rivals_remaining` Push Out summary.

func _calculate_campaign_score() -> int:
	var total: int = 0
	for entry: Dictionary in ResultManager.round_results:
		var success: bool = bool(entry.get("success", false))
		if success:
			total += 1000
		var mode_id: StringName = StringName(entry.get("mode_id", &"unknown"))
		var raw_score: int = int(entry.get("score", 0))
		var details_value: Variant = entry.get("details", {})
		var details: Dictionary = details_value as Dictionary if typeof(details_value) == TYPE_DICTIONARY else {}
		match mode_id:
			&"grand_prix", &"neon_harbor_race", &"snowpeak_winter_rally":
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

func _format_round_result(entry: Dictionary) -> String:
	var mode_id: StringName = StringName(entry.get("mode_id", &"unknown"))
	var success: bool = bool(entry.get("success", false))
	var raw_score: int = int(entry.get("score", 0))
	var details_value: Variant = entry.get("details", {})
	var details: Dictionary = details_value as Dictionary if typeof(details_value) == TYPE_DICTIONARY else {}
	var status: String = "CLEAR" if success else "MISS"
	match mode_id:
		&"fruit_collection":
			var target: int = maxi(1, int(details.get("target", 8)))
			var grade: String = String(details.get("performance_grade", "CLEAR" if success else "MISS")).to_upper()
			var champion: bool = bool(details.get("harvest_champion", false))
			var champion_text: String = " · HARVEST CHAMPION" if champion else ""
			return "FRUIT COLLECTION   ·   %d / %d PTS   ·   %s%s   ·   %s" % [raw_score, target, grade, champion_text, status]
		&"push_out":
			var racers: int = maxi(1, int(details.get("racers", GameManager.ai_count + 1)))
			var placement: int = clampi(int(details.get("placement", racers)), 1, racers)
			var champion: bool = bool(details.get("titan_champion", placement == 1))
			var finalist: bool = bool(details.get("finalist", placement <= 3))
			var accolade: String = "TITAN CHAMPION" if champion else ("FINALIST" if finalist else "ELIMINATED")
			return "WILD RUMBLE   ·   #%d / %d   ·   %s   ·   %s" % [placement, racers, accolade, status]
	return super._format_round_result(entry)
