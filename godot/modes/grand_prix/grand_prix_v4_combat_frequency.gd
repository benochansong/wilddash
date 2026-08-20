extends Node

## Round 1 combat-frequency adapter.
## Keeps the canonical RacingActionController / ItemSystem authoritative, but
## shortens player contact recovery and prevents long empty offensive stretches.

const BODY_CHECK_COOLDOWN_CAP: float = 1.65
const REFILL_INTERVAL: float = 11.5
const MAX_ATTACK_REFILLS: int = 5
const REFILL_ITEMS: Array[StringName] = [
	&"rocket_nut",
	&"shockwave",
	&"wind_boost",
]

var _action_controller: Node
var _player: WildDashCharacterController
var _hud: WildDashModeHUD
var _refill_elapsed: float = 0.0
var _refill_count: int = 0

func _ready() -> void:
	process_priority = 96
	call_deferred("_initialize")

func _initialize() -> void:
	for _frame: int in range(10):
		await get_tree().physics_frame
	_action_controller = get_parent().get_node_or_null("RacingActionController")
	_player = _find_player()
	_hud = _find_hud()
	print("GRAND PRIX COMBAT FREQUENCY EMERGENCY READY body_check_cap=%.2fs refill_interval=%.1fs max_refills=%d varied_attack=true" % [
		BODY_CHECK_COOLDOWN_CAP, REFILL_INTERVAL, MAX_ATTACK_REFILLS,
	])

func _physics_process(delta: float) -> void:
	if not RaceManager.active:
		return
	_cap_body_check_cooldown()
	_update_attack_refill(delta)

func _cap_body_check_cooldown() -> void:
	if _action_controller == null:
		return
	var value: Variant = _action_controller.get("_body_check_cooldown")
	if value == null:
		return
	var cooldown: float = float(value)
	if cooldown > BODY_CHECK_COOLDOWN_CAP:
		_action_controller.set("_body_check_cooldown", BODY_CHECK_COOLDOWN_CAP)

func _update_attack_refill(delta: float) -> void:
	if _player == null or _refill_count >= MAX_ATTACK_REFILLS:
		return
	_refill_elapsed += delta
	if _refill_elapsed < REFILL_INTERVAL:
		return
	if _player.get_held_item() != &"":
		# Do not overwrite a box pickup. Readiness remains banked until the slot is
		# empty, preserving the one-slot party-racing rule.
		return
	var item_id: StringName = REFILL_ITEMS[_refill_count % REFILL_ITEMS.size()]
	if not ItemSystem.grant_item(_player, item_id):
		return
	_refill_elapsed = 0.0
	_refill_count += 1
	AudioManager.play_sfx_id("ui", 0.70)
	if _hud != null:
		_hud.set_message("ATTACK RESTOCK %d/%d · %s READY · Q/B" % [
			_refill_count, MAX_ATTACK_REFILLS, ItemSystem.get_display_name(item_id),
		])
	print("GRAND PRIX ATTACK RESTOCK count=%d/%d item=%s body_check_cap=%.2f" % [
		_refill_count, MAX_ATTACK_REFILLS, String(item_id), BODY_CHECK_COOLDOWN_CAP,
	])

func _find_player() -> WildDashCharacterController:
	for racer: Node3D in RaceManager.racers:
		if racer is WildDashCharacterController and (racer as WildDashCharacterController).is_player:
			return racer as WildDashCharacterController
	return null

func _find_hud() -> WildDashModeHUD:
	for child: Node in get_parent().get_children():
		if child is WildDashModeHUD:
			return child as WildDashModeHUD
	return null
