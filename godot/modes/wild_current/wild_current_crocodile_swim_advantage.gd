class_name WildCurrentCrocodileSwimAdvantage
extends Node

## Round 5-only aquatic specialization for Crocodile.
## The base character remains deliberately slower on land; this layer makes the
## Water Bruiser fantasy materially true in WILD CURRENT without touching R1-R4.

const CROCODILE_MAX_SWIM_SPEED: float = 14.2
const CROCODILE_CRUISE_SWIM_SPEED: float = 10.2
const CROCODILE_MOMENTUM_RESPONSE_SCALE: float = 0.92
const CROCODILE_LATERAL_CURRENT_SCALE: float = 0.90
const CROCODILE_DIVE_RECHARGE_SCALE: float = 0.88

var _applied: Dictionary = {}
var _elapsed: float = 0.0

func _ready() -> void:
	print("r5_crocodile_swim_advantage_ready round5_only=true max=%.1f cruise=%.1f" % [
		CROCODILE_MAX_SWIM_SPEED,
		CROCODILE_CRUISE_SWIM_SPEED,
	])

func _process(delta: float) -> void:
	_elapsed += delta
	_apply_to_round5_swimmers()
	# Swimmers are created during race bootstrap. After the opening window there
	# is no need to scan every frame, but keeping this node alive is harmless.
	if _elapsed > 4.0:
		set_process(false)

func _apply_to_round5_swimmers() -> void:
	var race_root := get_parent()
	if race_root == null:
		return
	for child in race_root.get_children():
		var driver := child as WildCurrentSwimmerPhase2
		if driver == null or driver.racer == null:
			continue
		var racer := driver.racer as WildDashCharacterController
		if racer == null or racer.animal_id != &"crocodile":
			continue
		var key := driver.get_instance_id()
		if _applied.has(key):
			continue

		driver.max_swim_speed = maxf(driver.max_swim_speed, CROCODILE_MAX_SWIM_SPEED)
		driver.cruise_swim_speed = maxf(driver.cruise_swim_speed, CROCODILE_CRUISE_SWIM_SPEED)
		driver.set("_momentum_scale", CROCODILE_MOMENTUM_RESPONSE_SCALE)
		driver.set("_lateral_current_scale", CROCODILE_LATERAL_CURRENT_SCALE)
		driver.set("_dive_recharge_scale", CROCODILE_DIVE_RECHARGE_SCALE)
		_applied[key] = true

		print("r5_crocodile_water_advantage racer=%s max=%.1f cruise=%.1f propulsion=%.2f lateral_current=%.2f dive_recharge=%.2f" % [
			RaceManager.get_racer_label(racer),
			driver.max_swim_speed,
			driver.cruise_swim_speed,
			1.0 / CROCODILE_MOMENTUM_RESPONSE_SCALE,
			CROCODILE_LATERAL_CURRENT_SCALE,
			CROCODILE_DIVE_RECHARGE_SCALE,
		])
