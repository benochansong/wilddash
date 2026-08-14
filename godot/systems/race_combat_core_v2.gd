class_name WildDashRaceCombatCoreV2
extends Node

## Central race-combat command layer.
## InputManager resolves F/Y into Tap/Hold + Left/Neutral/Right. This node binds
## that gesture to the active animal's shared combat profile and emits one stable
## command shape for species-specific combat controllers and future networking.

signal combat_command_ready(racer: WildDashCharacterController, command: Dictionary)

const HOLD_ATTACK_POWER_MULTIPLIER: float = 1.35
const HOLD_RANGE_MULTIPLIER: float = 1.15
const HOLD_COOLDOWN_MULTIPLIER: float = 1.30
const HOLD_LAUNCH_MULTIPLIER: float = 1.25
const DIRECTIONAL_RANGE_MULTIPLIER: float = 1.06

var _racer: WildDashCharacterController
var _last_command: Dictionary = {}
var _command_count: int = 0

func _ready() -> void:
	process_priority = 70
	if not InputManager.race_combat_action_resolved.is_connected(_on_race_combat_action_resolved):
		InputManager.race_combat_action_resolved.connect(_on_race_combat_action_resolved)
	call_deferred("_resolve_player")

func _exit_tree() -> void:
	if InputManager.race_combat_action_resolved.is_connected(_on_race_combat_action_resolved):
		InputManager.race_combat_action_resolved.disconnect(_on_race_combat_action_resolved)

func get_last_command() -> Dictionary:
	return _last_command.duplicate(true)

func get_player_profile() -> Dictionary:
	_resolve_player()
	if _racer == null:
		return WildDashRaceCombatProfile.DEFAULT_PROFILE.duplicate(true)
	return WildDashRaceCombatProfile.get_profile(_racer.animal_id)

func get_player_profile_text() -> String:
	_resolve_player()
	if _racer == null:
		return "COMBAT V2 · NO RACER"
	var p: Dictionary = WildDashRaceCombatProfile.get_profile(_racer.animal_id)
	return "ATK %.1f · DEF %.1f · STB %.1f · RNG %.1fm · CD %.2fs · LCH %.1f" % [
		float(p["attack_power"]),
		float(p["defense"]),
		float(p["stability"]),
		float(p["range"]),
		float(p["cooldown"]),
		float(p["launch"]),
	]

static func build_tuned_command(action: Dictionary, animal_id: StringName) -> Dictionary:
	var profile: Dictionary = WildDashRaceCombatProfile.get_profile(animal_id)
	var kind: StringName = StringName(action.get("kind", &"tap"))
	var direction: int = int(action.get("direction", 0))
	var power_multiplier: float = 1.0
	var range_multiplier: float = 1.0
	var cooldown_multiplier: float = 1.0
	var launch_multiplier: float = 1.0

	if kind == &"hold":
		power_multiplier = HOLD_ATTACK_POWER_MULTIPLIER
		range_multiplier = HOLD_RANGE_MULTIPLIER
		cooldown_multiplier = HOLD_COOLDOWN_MULTIPLIER
		launch_multiplier = HOLD_LAUNCH_MULTIPLIER
	if direction != 0:
		range_multiplier *= DIRECTIONAL_RANGE_MULTIPLIER

	var command: Dictionary = action.duplicate(true)
	command["animal_id"] = animal_id
	command["attack_power"] = float(profile["attack_power"]) * power_multiplier
	command["defense"] = float(profile["defense"])
	command["stability"] = float(profile["stability"])
	command["cooldown"] = float(profile["cooldown"]) * cooldown_multiplier
	command["range"] = float(profile["range"]) * range_multiplier
	command["launch"] = float(profile["launch"]) * launch_multiplier
	command["power_multiplier"] = power_multiplier
	command["range_multiplier"] = range_multiplier
	command["cooldown_multiplier"] = cooldown_multiplier
	command["launch_multiplier"] = launch_multiplier
	return command

static func command_label(command: Dictionary) -> String:
	var kind: String = String(command.get("kind", &"tap")).to_upper()
	var direction: String = String(command.get("direction_name", &"neutral")).to_upper()
	return "%s %s" % [kind, direction]

func _on_race_combat_action_resolved(action: Dictionary) -> void:
	_resolve_player()
	if _racer == null or _racer.finished or not RaceManager.active:
		return
	_command_count += 1
	_last_command = build_tuned_command(action, _racer.animal_id)
	_last_command["command_count"] = _command_count
	combat_command_ready.emit(_racer, _last_command.duplicate(true))
	print("RC9 COMBAT V2 command=%s animal=%s atk=%.1f def=%.1f stb=%.1f range=%.2f cooldown=%.2f launch=%.1f held=%.2f" % [
		command_label(_last_command),
		String(_racer.animal_id),
		float(_last_command["attack_power"]),
		float(_last_command["defense"]),
		float(_last_command["stability"]),
		float(_last_command["range"]),
		float(_last_command["cooldown"]),
		float(_last_command["launch"]),
		float(_last_command.get("held_seconds", 0.0)),
	])

func _resolve_player() -> void:
	if _racer != null and is_instance_valid(_racer):
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	_racer = parent.get_node_or_null("Player") as WildDashCharacterController
