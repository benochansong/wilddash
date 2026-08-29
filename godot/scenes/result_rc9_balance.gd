extends "res://scenes/result.gd"

## RC9 result rules aligned with the active campaign contracts.
## Round Recap and Final Result now share ResultManager's campaign scoring so
## the running total shown between rounds exactly matches the final scoreboard.

func _calculate_campaign_score() -> int:
	return ResultManager.get_campaign_total_score()

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
		&"tidal_clash":
			return "TIDAL CLASH   ·   #%d / %d   ·   100%% WATER BATTLE RACE   ·   %s" % [
				int(details.get("rank", raw_score)), int(details.get("racers", GameManager.ai_count + 1)), status,
			]
	return super._format_round_result(entry)
