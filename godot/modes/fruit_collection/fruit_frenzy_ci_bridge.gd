extends Node

## Compatibility telemetry for the existing five-round Godot campaign smoke.
## It prints the legacy marker only after a real AI has actually acquired
## carried fruit in Harvest Heist.

var _logged_ai_pickup := false

func _physics_process(_delta: float) -> void:
	if _logged_ai_pickup or not GameManager.round_active:
		return
	var mode := get_parent()
	if mode == null:
		return
	var ai_list: Array = mode.get("ai_racers")
	var carried: Dictionary = mode.get("carried_by_id")
	for candidate in ai_list:
		if not candidate is WildDashCharacterController:
			continue
		var racer := candidate as WildDashCharacterController
		var carry: int = int(carried.get(racer.get_instance_id(), 0))
		if carry <= 0:
			continue
		_logged_ai_pickup = true
		print("FRUIT AI PICKUP racer=%s carry=%d mode=harvest_heist" % [racer.name, carry])
		return
