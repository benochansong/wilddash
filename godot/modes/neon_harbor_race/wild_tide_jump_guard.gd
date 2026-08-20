class_name WildDashWildTideJumpGuard
extends Node

## Round 3 water locomotion rule.
##
## Normal jump is disabled while a racer is inside a Wild Tide shallow/deep
## water Area. This intentionally works by temporarily setting the canonical
## jump_velocity to zero before racer/AI physics callbacks run, so player SPACE,
## generic AI obstacle hops and combat AI evade hops all resolve as lane-only
## movement in water. Direct vertical impulses from explosions and scripted
## traversal do not use jump_velocity and remain available.

const JUMP_META_DISABLED: StringName = &"wild_tide_jump_disabled"
const JUMP_META_ALLOWED: StringName = &"wild_tide_jump_allowed"
const TERRAIN_META: StringName = &"wild_tide_terrain"

var _base_jump_by_id: Dictionary = {}
var _water_state_by_id: Dictionary = {}

func _ready() -> void:
	# Lower values run first. Lock jump_velocity before CharacterController and
	# AIController evaluate normal jump/obstacle-hop inputs in the same tick.
	process_physics_priority = -200
	print("WILD TIDE JUMP GUARD READY normal_jump_water=false player=true ai=true direct_vertical_impulse_preserved=true")

func _physics_process(_delta: float) -> void:
	if not RaceManager.active:
		_restore_all_cached_jumps()
		return
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		_update_racer_jump_state(racer)

func _exit_tree() -> void:
	_restore_all_cached_jumps()

func _update_racer_jump_state(racer: WildDashCharacterController) -> void:
	var racer_id: int = racer.get_instance_id()
	var water: bool = _is_water_racer(racer)
	var was_water: bool = bool(_water_state_by_id.get(racer_id, false))
	if water:
		if not _base_jump_by_id.has(racer_id):
			_base_jump_by_id[racer_id] = racer.jump_velocity
		racer.jump_velocity = 0.0
		racer.set_meta(JUMP_META_DISABLED, true)
		racer.set_meta(JUMP_META_ALLOWED, false)
		if not was_water:
			var terrain: StringName = _terrain_for(racer)
			print("WILD TIDE TERRAIN animal=%s terrain=%s jump_allowed=false speed_multiplier=%.2f" % [
				String(racer.animal_id), String(terrain).to_upper(),
				float(racer.get_meta(&"wild_tide_speed_multiplier", 1.0)),
			])
			if racer.is_player:
				_show_hud("%s · NORMAL JUMP DISABLED · LANE EVADE ACTIVE" % String(terrain).replace("_", " ").to_upper())
	else:
		_restore_racer_jump(racer)
		if was_water:
			print("WILD TIDE TERRAIN animal=%s terrain=LAND jump_allowed=true" % String(racer.animal_id))
			if racer.is_player:
				_show_hud("LAND ROUTE · NORMAL JUMP RESTORED")
	_water_state_by_id[racer_id] = water

func _restore_racer_jump(racer: WildDashCharacterController) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	if _base_jump_by_id.has(racer_id):
		racer.jump_velocity = float(_base_jump_by_id.get(racer_id, racer.jump_velocity))
		_base_jump_by_id.erase(racer_id)
	if racer.has_meta(JUMP_META_DISABLED):
		racer.remove_meta(JUMP_META_DISABLED)
	if racer.has_meta(JUMP_META_ALLOWED):
		racer.remove_meta(JUMP_META_ALLOWED)

func _restore_all_cached_jumps() -> void:
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer != null and is_instance_valid(racer):
			_restore_racer_jump(racer)
	_base_jump_by_id.clear()
	_water_state_by_id.clear()

func _is_water_racer(racer: WildDashCharacterController) -> bool:
	var terrain: StringName = _terrain_for(racer)
	return terrain == WildDashTerrainAbilitySystem.TERRAIN_SHALLOW_WATER or terrain == WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER or terrain == WildDashTerrainAbilitySystem.TERRAIN_WATER

func _terrain_for(racer: WildDashCharacterController) -> StringName:
	if racer == null or not racer.has_meta(TERRAIN_META):
		return WildDashTerrainAbilitySystem.TERRAIN_LAND
	var value: Variant = racer.get_meta(TERRAIN_META, WildDashTerrainAbilitySystem.TERRAIN_LAND)
	return StringName(String(value))

func _show_hud(text: String) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var hud_value: Variant = parent_node.get("hud")
	var mode_hud: WildDashModeHUD = hud_value as WildDashModeHUD
	if mode_hud != null:
		mode_hud.set_message(text)
