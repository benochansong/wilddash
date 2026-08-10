extends Node

# Physical Shortcut A/B remain open to every player/character. For AI, Rabbit is
# the specialist that deliberately takes the risky line. Other AI stay on the
# safe main route until per-archetype shortcut steering is independently proven.
# This avoids forcing a Dog/Elephant/Cat into a narrow shortcut just because a
# deterministic seed selected it.
func _ready() -> void:
	call_deferred("_apply_ai_route_policy")

func _apply_ai_route_policy() -> void:
	var mode := get_parent()
	if mode == null:
		return
	var safe_route := RaceManager.get_route_points()
	if safe_route.size() < 2:
		return
	var redirected := 0
	for driver_variant in mode.ai_drivers:
		var driver := driver_variant as WildDashAIController
		if driver == null:
			continue
		var racer := driver.get_racer()
		if racer == null or racer.animal_id == &"rabbit":
			continue
		driver.set_race_route(safe_route)
		redirected += 1
	print("AI SHORTCUT SAFETY PASS rabbit_specialist=true physical_open_to_all=true redirected=%d" % redirected)
