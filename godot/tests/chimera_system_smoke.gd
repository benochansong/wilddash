extends Node

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
var _failed := false

func _ready() -> void:
	await get_tree().process_frame
	var loadout := WildDashChimeraLoadout.new()
	loadout.head_id = &"rabbit"
	loadout.body_id = &"elephant"
	loadout.tail_id = &"cat"
	loadout.palette_id = &"ocean"
	loadout.pattern_id = &"spots"
	loadout.normalize()

	var serialized := loadout.to_dictionary()
	var restored := WildDashChimeraLoadout.from_dictionary(serialized)
	_assert(restored.head_id == &"rabbit", "head round-trip")
	_assert(restored.body_id == &"elephant", "body round-trip")
	_assert(restored.tail_id == &"cat", "tail round-trip")

	var racer := RACER_SCENE.instantiate() as WildDashCharacterController
	_assert(racer != null, "racer scene")
	if racer == null:
		get_tree().quit(1)
		return
	racer.is_player = false
	racer.movement_mode = WildDashCharacterController.MovementMode.ARENA
	add_child(racer)
	racer.configure_chimera(restored)

	_assert(racer.is_chimera(), "chimera mode")
	_assert(is_equal_approx(racer.max_speed, 13.1), "body chassis movement source")
	_assert(racer.get_skill_id() == &"spring_leap", "head active skill id")
	_assert(racer.get_skill_name() == "SPRING LEAP", "head active skill name")
	print("CHIMERA HEAD SKILL PASS skill=SPRING LEAP")

	_assert(racer.get_passive_name() == "HEAVY FRAME", "body passive source")
	racer.apply_knockback(Vector3.RIGHT, 10.0)
	_assert(racer.get_knockback_velocity().length() < 9.2, "elephant body passive resistance")
	print("CHIMERA BODY PASSIVE PASS passive=HEAVY FRAME knockback=%.2f" % racer.get_knockback_velocity().length())
	racer.reset_motion(Vector3.ZERO)

	_assert(racer.get_utility_name() == "REFLEX TAIL", "tail utility source")
	_assert(racer.get_active_handling_scale() > 1.0, "cat tail handling utility")
	print("CHIMERA TAIL BONUS PASS utility=REFLEX TAIL handling=%.3f" % racer.get_active_handling_scale())

	var collision := racer.get_node("CollisionShape3D") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D if collision != null else null
	_assert(capsule != null and is_equal_approx(capsule.radius, 0.80), "body collision source")
	var visual := racer.get_visual() as WildDashChimeraVisual
	_assert(visual != null, "chimera visual installed")
	if visual != null:
		_assert(visual.find_child("HeadSlot", true, false) != null, "head visual slot")
		_assert(visual.find_child("BodySlot", true, false) != null, "body visual slot")
		_assert(visual.find_child("TailSlot", true, false) != null, "tail visual slot")
	_assert(racer.try_use_skill(), "head skill activation")
	_assert(is_equal_approx(racer.skill_cooldown_remaining, 8.0), "head cooldown")

	var defaults := SaveManager.default_data()
	_assert(int(defaults.version) == 2, "save version 2")
	_assert(typeof(defaults.chimera) == TYPE_DICTIONARY, "chimera save payload")
	GameManager.configure_chimera(serialized, true)
	_assert(GameManager.chimera_enabled, "game manager chimera selection")
	_assert(GameManager.get_chimera_loadout().body_id == &"elephant", "game manager loadout")
	GameManager.disable_chimera()

	if _failed:
		get_tree().quit(1)
		return
	print("CHIMERA PROFILE head=%s body=%s tail=%s passive=%s utility=%s skill=%s" % [
		restored.head_id, restored.body_id, restored.tail_id,
		racer.get_passive_name(), racer.get_utility_name(), racer.get_skill_name(),
	])
	print("CHIMERA SYSTEM PASS slots=3 palettes=%d patterns=%d save_version=2" % [
		WildDashChimeraSystem.PALETTES.size(), WildDashChimeraSystem.PATTERNS.size(),
	])
	get_tree().quit(0)

func _assert(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("CHIMERA ASSERT FAILED: %s" % label)
