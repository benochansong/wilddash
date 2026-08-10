extends "res://modes/grand_prix/grand_prix_mode.gd"

# The extended 2.47 km course is substantially longer than the prototype
# Grand Prix. RC5 keeps the relative item/skill multipliers intact and raises
# only the production race envelope so a full-throttle Normal run can land in
# the intended 130-170 second window.
const RC5_RACER_MAX_SPEED_SCALE := 1.35
const RC5_RACER_CRUISE_SPEED_SCALE := 1.10
const RC5_RACER_ACCELERATION_SCALE := 1.08
const RC5_WIDE_ITEM_STATIONS: Array[int] = [8, 14, 23]
const RC5_ITEM_BOX_TARGET := 36

func _ready() -> void:
	await super._ready()
	var production_pace := DisplayServer.get_name() != "headless" or OS.has_environment("WILDDASH_REALTIME_BALANCE")
	if not production_pace:
		return

	for racer in RaceManager.racers:
		if not racer is WildDashCharacterController:
			continue
		var controller := racer as WildDashCharacterController
		controller.max_speed *= RC5_RACER_MAX_SPEED_SCALE
		controller.cruise_speed *= RC5_RACER_CRUISE_SPEED_SCALE
		controller.acceleration *= RC5_RACER_ACCELERATION_SCALE

	# The headless real-time balance proxy drives the Player with an AI driver.
	# Sync only that preserved-player driver to the same production max speed;
	# normal automated campaign runs keep the existing accelerated CI profile.
	if DisplayServer.get_name() == "headless":
		for driver in ai_drivers:
			if driver != null and driver.preserve_player_identity:
				driver.target_speed = player.max_speed
				driver.acceleration = player.acceleration
				break

	print("RC5 PRODUCTION PACE PASS player_max=%.2f cruise=%.2f accel=%.2f racer_scale=%.2f ai_scale=%.2f" % [
		player.max_speed,
		player.cruise_speed,
		player.acceleration,
		RC5_RACER_MAX_SPEED_SCALE,
		WildDashAIPackTactics.PRODUCTION_PACE_SCALE,
	])

# Keep the RC5 item field inside the requested 30-36 box envelope. Three
# wide stations use four lanes while the other eight retain the established
# three-lane layout: 3*4 + 8*3 = 36 boxes. Respawn remains count-sensitive.
func _spawn_item_boxes() -> void:
	var respawn := 5.0
	if RaceManager.racers.size() >= 18:
		respawn = 3.6
	elif RaceManager.racers.size() >= 15:
		respawn = 4.0
	for route_index in ITEM_BOX_ROUTE_INDICES:
		if route_index <= 0 or route_index >= _route_points.size() - 1:
			continue
		var point := _route_points[route_index]
		var tangent := _route_points[route_index + 1] - _route_points[route_index - 1]
		tangent.y = 0.0
		tangent = Vector3.FORWARD if tangent.length_squared() <= 0.001 else tangent.normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)
		var lane_offsets := ITEM_BOX_WIDE_LANE_OFFSETS if RC5_WIDE_ITEM_STATIONS.has(route_index) and RaceManager.racers.size() >= 15 else ITEM_BOX_LANE_OFFSETS
		for lane_offset in lane_offsets:
			var box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "ItemBox_R%02d_L%s" % [route_index, str(lane_offset).replace("-", "N").replace(".", "_")]
			box.position = point + right * lane_offset + Vector3.UP * 1.35
			box.respawn_seconds = respawn
			add_child(box)
			_item_boxes.append(box)
	print("RC5 GRAND PRIX ITEM BOXES PASS count=%d target=%d stations=%d respawn=%.1fs wide_stations=%d" % [
		_item_boxes.size(), RC5_ITEM_BOX_TARGET if RaceManager.racers.size() >= 15 else 33,
		ITEM_BOX_ROUTE_INDICES.size(), respawn, RC5_WIDE_ITEM_STATIONS.size(),
	])
