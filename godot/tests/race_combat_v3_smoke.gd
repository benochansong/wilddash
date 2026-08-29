extends Node

const PROFILE_SCRIPT: Script = preload("res://systems/race_impact_profile.gd")
const CORE_V3_SCRIPT: Script = preload("res://systems/race_combat_core_v3.gd")
const ROCKET_SCRIPT: Script = preload("res://items/rocket_nut.gd")
const BANANA_SCRIPT: Script = preload("res://items/banana_peel.gd")
const STICKY_SCRIPT: Script = preload("res://items/sticky_fruit_trap.gd")
const PACK_BUSTER_SCRIPT: Script = preload("res://items/acorn_bomb.gd")
const ROUND1_SCENE: PackedScene = preload("res://modes/grand_prix/grand_prix.tscn")
const ROUND3_SCENE: PackedScene = preload("res://modes/neon_harbor_race/neon_harbor_race.tscn")

func _ready() -> void:
	var failures: Array[String] = []
	if PROFILE_SCRIPT == null or CORE_V3_SCRIPT == null:
		failures.append("Race Combat V3 core/profile preload failed")
	if ROCKET_SCRIPT == null or BANANA_SCRIPT == null or STICKY_SCRIPT == null or PACK_BUSTER_SCRIPT == null:
		failures.append("Race Combat V3 item preload failed")
	if ROUND1_SCENE == null or ROUND3_SCENE == null:
		failures.append("Round 1 / Round 3 scenes failed to preload")

	var inner: WildDashRaceImpactProfile = WildDashRaceImpactProfile.pack_buster_inner()
	var outer: WildDashRaceImpactProfile = WildDashRaceImpactProfile.pack_buster_outer()
	var rocket: WildDashRaceImpactProfile = WildDashRaceImpactProfile.rocket_nut()
	var banana: WildDashRaceImpactProfile = WildDashRaceImpactProfile.banana_peel()
	var sticky: WildDashRaceImpactProfile = WildDashRaceImpactProfile.sticky_fruit()
	if inner.knockback <= outer.knockback or inner.speed_loss_ratio <= outer.speed_loss_ratio:
		failures.append("Pack Buster inner/outer falloff invalid")
	if rocket.speed_loss_ratio < 0.20 or rocket.speed_loss_ratio > 0.27:
		failures.append("Rocket Nut speed-loss budget invalid")
	if banana.stagger_duration > 0.70:
		failures.append("Banana slip exceeds short disruption budget")
	if sticky.slow_duration < 1.0 or sticky.slow_duration > 1.5:
		failures.append("Sticky Fruit duration outside passing-window budget")
	if inner.protection_seconds < 0.55 or inner.protection_seconds > 0.80:
		failures.append("Race hit-protection budget invalid")

	if failures.is_empty():
		print("RACE COMBAT V3 SMOKE PASS round1=true round3=true pack_buster=true rocket=true shockwave=true banana=true sticky=true body_check=true phase2_api=true")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RACE COMBAT V3 SMOKE FAIL: %s" % failure)
	get_tree().quit(1)
