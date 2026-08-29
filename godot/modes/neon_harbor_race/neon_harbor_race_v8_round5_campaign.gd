extends "res://modes/neon_harbor_race/neon_harbor_race_v7_party_items.gd"

## Round 5 campaign presentation adapter.
## The proven V7 Wild Tide gameplay stack remains unchanged; this thin layer only
## updates finale-facing HUD/log presentation after the campaign reorder.

func _ready() -> void:
	super._ready()
	if hud != null:
		hud.configure(
			"ROUND 5 — WILD TIDE: JUNGLE HARBOR",
			"FINAL RACE · 수륙 레이스 · Titan 경고 회피 · Canopy / Deep Water Route · Q/B Item"
		)
	if GameManager.campaign_running and GameManager.get_current_round_id() == &"neon_harbor_race":
		print("CAMPAIGN ROUND 5 NEON HARBOR presentation=finale wild_tide_v7_preserved=true")
	else:
		print("WILD TIDE ROUND 5 PRESENTATION direct_scene=true wild_tide_v7_preserved=true")
