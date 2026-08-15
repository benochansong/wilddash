class_name WildDashLongBombItemSupport
extends RefCounted

const BOMB_SCRIPT: Script = preload("res://items/acorn_bomb.gd")
const TARGET_DISTANCE: float = 84.0
const BACK_THIRD_START: float = 0.66
const BACK_HALF_START: float = 0.50
const BACK_THIRD_INJECT_CHANCE: float = 0.24
const BACK_HALF_INJECT_CHANCE: float = 0.12

static func maybe_inject_catchup_bomb(
	racer: WildDashCharacterController,
	granted_item: StringName,
	rng: RandomNumberGenerator
) -> bool:
	if racer == null or rng == null or racer.finished:
		return false
	var total: int = maxi(1, RaceManager.racers.size())
	var rank: int = RaceManager.get_rank(racer)
	var back_ratio: float = float(clampi(rank, 1, total) - 1) / float(maxi(1, total - 1))

	# If a trailing racer already rolled the Acorn Bomb, protect that comeback
	# roll from being replaced by the expansion layer.
	if granted_item == ItemSystem.ACORN_BOMB and back_ratio >= BACK_HALF_START:
		print("LONG BOMB PRESERVE racer=%s rank=%d/%d back_ratio=%.2f" % [
			RaceManager.get_racer_label(racer), rank, total, back_ratio,
		])
		return true

	# Yellow boxes occasionally convert another roll into the long bomb for the
	# back half of the field. Front runners never receive this extra conversion.
	var chance: float = 0.0
	if back_ratio >= BACK_THIRD_START:
		chance = BACK_THIRD_INJECT_CHANCE
	elif back_ratio >= BACK_HALF_START:
		chance = BACK_HALF_INJECT_CHANCE
	if chance <= 0.0 or rng.randf() > chance:
		return false
	if racer.get_held_item() != granted_item:
		return false
	racer.set_held_item(ItemSystem.ACORN_BOMB)
	print("LONG BOMB CATCHUP ROLL racer=%s rank=%d/%d base=%s chance=%.2f" % [
		RaceManager.get_racer_label(racer), rank, total, ItemSystem.get_display_name(granted_item), chance,
	])
	return true

static func use_long_bomb(character: WildDashCharacterController) -> bool:
	if character == null or character.finished or character.get_held_item() != ItemSystem.ACORN_BOMB:
		return false
	var world: Node = character.get_parent()
	if world == null:
		return false
	var target: Node3D = ItemSystem.find_target_ahead(character, TARGET_DISTANCE)
	var bomb: WildDashAcornBomb = BOMB_SCRIPT.new() as WildDashAcornBomb
	if bomb == null:
		return false
	bomb.name = "AcornLongBomb_%d" % Time.get_ticks_msec()
	world.add_child(bomb)
	var forward: Vector3 = -character.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	bomb.global_position = character.global_position + forward * 1.8 + Vector3.UP * 1.25
	bomb.configure(character, target)
	character.set_held_item(&"")
	character.set_meta(&"wilddash_last_expanded_item", ItemSystem.ACORN_BOMB)
	ItemSystem.item_used.emit(character, ItemSystem.ACORN_BOMB)
	AudioManager.play_sfx_id("item", 1.0)
	var target_label: String = "STRAIGHT ARC"
	if target is WildDashCharacterController:
		target_label = RaceManager.get_racer_label(target)
	print("LONG BOMB THROW racer=%s target=%s range=%.0f" % [
		RaceManager.get_racer_label(character), target_label, TARGET_DISTANCE,
	])
	return true
