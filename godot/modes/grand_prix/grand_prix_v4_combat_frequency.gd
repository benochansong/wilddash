extends Node

## Round 1 combat-frequency adapter.
## Keeps the canonical RacingActionController and item systems intact, but makes
## combat opportunities less sparse in Grand Prix only: F/Y recovers sooner and
## an empty offensive item slot can be replenished a limited number of times.

const BODY_CHECK_COOLDOWN_CAP := 2.15
const REFILL_INTERVAL := 14.0
const MAX_ATTACK_REFILLS := 4
const REFILL_ITEM: StringName = &"rocket_nut"

var _action_controller: Node
var _player: WildDashCharacterController
var _hud: WildDashModeHUD
var _refill_elapsed := 0.0
var _refill_count := 0

func _ready() -> void:
	process_priority = 96
	call_deferred("_initialize")

func _initialize() -> void:
	for _frame: int in range(10):
		await get_tree().physics_frame
	_action_controller = get_parent().get_node_or_null("RacingActionController")
	_player = _find_player()
	_hud = _find_hud()
	print("GRAND PRIX V4.1 COMBAT FREQUENCY READY body_check_cap=%.2fs refill_interval=%.1fs max_refills=%d item=%s" % [
		BODY_CHECK_COOLDOWN_CAP, REFILL_INTERVAL, MAX_ATTACK_REFILLS, String(REFILL_ITEM),
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
	var cooldown := float(value)
	if cooldown > BODY_CHECK_COOLDOWN_CAP:
		_action_controller.set("_body_check_cooldown", BODY_CHECK_COOLDOWN_CAP)

func _update_attack_refill(delta: float) -> void:
	if _player == null or _refill_count >= MAX_ATTACK_REFILLS:
		return
	_refill_elapsed += delta
	if _refill_elapsed < REFILL_INTERVAL:
		return
	if _player.get_held_item() != &"":
		# Keep accumulating readiness while the player holds an item; as soon as
		# the slot becomes empty, the next refill is available without overwriting it.
		return
	if not ItemSystem.grant_item(_player, REFILL_ITEM):
		return
	_refill_elapsed = 0.0
	_refill_count += 1
	AudioManager.play_sfx_id("ui", 0.70)
	if _hud != null:
		_hud.set_message("ATTACK RESTOCK %d/%d · ROCKET NUT READY · Q/B" % [_refill_count, MAX_ATTACK_REFILLS])
	print("GRAND PRIX ATTACK RESTOCK count=%d/%d item=%s" % [_refill_count, MAX_ATTACK_REFILLS, String(REFILL_ITEM)])

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
