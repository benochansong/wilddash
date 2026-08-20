class_name WildDashRacerInputState
extends RefCounted

## Small transport-friendly input packet used by local play now and multiplayer later.
## One-shot actions are separated from held axes so the same structure can travel
## over ENet without exposing InputMap details to gameplay/network code.

var steer := 0.0
var throttle := 0.0
var jump_pressed := false
var skill_pressed := false
var item_pressed := false
var bump_pressed := false
var sequence := 0

func to_dictionary() -> Dictionary:
	return {
		"steer": clampf(steer, -1.0, 1.0),
		"throttle": clampf(throttle, -1.0, 1.0),
		"jump_pressed": jump_pressed,
		"skill_pressed": skill_pressed,
		"item_pressed": item_pressed,
		"bump_pressed": bump_pressed,
		"sequence": sequence,
	}

static func from_dictionary(data: Dictionary) -> WildDashRacerInputState:
	var state := WildDashRacerInputState.new()
	state.steer = clampf(float(data.get("steer", 0.0)), -1.0, 1.0)
	state.throttle = clampf(float(data.get("throttle", 0.0)), -1.0, 1.0)
	state.jump_pressed = bool(data.get("jump_pressed", false))
	state.skill_pressed = bool(data.get("skill_pressed", false))
	state.item_pressed = bool(data.get("item_pressed", false))
	state.bump_pressed = bool(data.get("bump_pressed", false))
	state.sequence = maxi(0, int(data.get("sequence", 0)))
	return state
