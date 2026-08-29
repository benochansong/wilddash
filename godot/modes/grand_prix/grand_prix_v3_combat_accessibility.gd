class_name WildDashGrandPrixV3CombatAccessibility
extends Node

## V3.1 combat discoverability pass.
## The race already has F/Y contact combat and Q/B item combat, but Round 1 did
## not guarantee an offensive item and the F/Y hint was easy to miss. Give the
## player one starter Rocket Nut and keep the canonical controls visible without
## adding another combat simulation or per-frame physics cost.

const STARTER_ATTACK_ITEM: StringName = &"rocket_nut"
const TUTORIAL_SECONDS := 8.0

var _tutorial_label: Label

func _ready() -> void:
	process_priority = 120
	call_deferred("_initialize_combat_access")

func _initialize_combat_access() -> void:
	for _frame: int in range(8):
		await get_tree().physics_frame

	var player := _find_player()
	if player == null:
		push_warning("Grand Prix V3.1 combat access: player unavailable")
		return

	var granted := false
	if player.get_held_item() == &"":
		granted = ItemSystem.grant_item(player, STARTER_ATTACK_ITEM)

	var hud := _find_hud()
	if hud != null:
		hud.set_message("W/↑ BOOST · A/D STEER · SPACE JUMP · E/X SKILL · F/Y BODY CHECK · Q/B ITEM ATTACK")

	_install_tutorial_label(player, granted)
	print("GRAND PRIX V3.1 COMBAT ACCESS READY starter_item=%s granted=%s body_check=F/Y item_attack=Q/B" % [
		String(STARTER_ATTACK_ITEM), str(granted),
	])

func _find_player() -> WildDashCharacterController:
	for racer: Node3D in RaceManager.racers:
		if racer is WildDashCharacterController and (racer as WildDashCharacterController).is_player:
			return racer as WildDashCharacterController
	return null

func _find_hud() -> WildDashModeHUD:
	var parent := get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is WildDashModeHUD:
			return child as WildDashModeHUD
	return null

func _install_tutorial_label(player: WildDashCharacterController, starter_granted: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_tutorial_label = Label.new()
	_tutorial_label.name = "V31CombatTutorial"
	_tutorial_label.position = Vector2(500.0, 185.0)
	_tutorial_label.size = Vector2(600.0, 92.0)
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.z_index = 1200
	_tutorial_label.add_theme_font_size_override("font_size", 22)
	_tutorial_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_tutorial_label.add_theme_constant_override("shadow_offset_x", 2)
	_tutorial_label.add_theme_constant_override("shadow_offset_y", 2)
	var item_line := "Q / B  ROCKET NUT" if starter_granted or player.get_held_item() == STARTER_ATTACK_ITEM else "Q / B  ATTACK ITEM"
	_tutorial_label.text = "ATTACK READY\nF / Y  BODY CHECK    ·    %s" % item_line
	get_parent().add_child(_tutorial_label)
	_fade_tutorial_after_delay()

func _fade_tutorial_after_delay() -> void:
	await get_tree().create_timer(TUTORIAL_SECONDS).timeout
	if _tutorial_label != null and is_instance_valid(_tutorial_label):
		_tutorial_label.queue_free()
