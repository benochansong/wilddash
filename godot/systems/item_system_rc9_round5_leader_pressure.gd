extends "res://systems/item_system_rc9_round1_impact.gd"

## Round 5 leader-pressure item layer.
## Adds real, player/AI-usable anti-leader items only while WILD CURRENT is active.
## Outside Round 5 every roll/use path delegates to the existing RC9 ItemSystem.

const RIVER_TORPEDO_SCRIPT: Script = preload("res://items/river_torpedo.gd")
const STORM_BOMB_SCRIPT: Script = preload("res://items/storm_bomb.gd")

const RIVER_TORPEDO: StringName = &"river_torpedo"
const STORM_BOMB: StringName = &"storm_bomb"
const CURRENT_ANCHOR: StringName = &"current_anchor"
const TIDAL_BARRAGE: StringName = &"tidal_barrage"

const ROUND5_LEADER_ITEM_IDS: Array[StringName] = [
	RIVER_TORPEDO,
	STORM_BOMB,
	CURRENT_ANCHOR,
	TIDAL_BARRAGE,
]

const TORPEDO_FRONT_CHASE_WEIGHT: float = 14.0
const STORM_FRONT_CHASE_WEIGHT: float = 11.0
const ANCHOR_FRONT_CHASE_WEIGHT: float = 9.0
const BARRAGE_FRONT_CHASE_WEIGHT: float = 7.0
const TORPEDO_MID_WEIGHT: float = 20.0
const STORM_MID_WEIGHT: float = 16.0
const ANCHOR_MID_WEIGHT: float = 14.0
const BARRAGE_MID_WEIGHT: float = 12.0
const TORPEDO_BACK_WEIGHT: float = 28.0
const STORM_BACK_WEIGHT: float = 22.0
const ANCHOR_BACK_WEIGHT: float = 20.0
const BARRAGE_BACK_WEIGHT: float = 17.0

const ANCHOR_DURATION: float = 1.15
const ANCHOR_SLOW: float = 0.50
const ANCHOR_KNOCKBACK: float = 3.6
const BARRAGE_DURATION: float = 0.78
const BARRAGE_BASE_SLOW: float = 0.58
const BARRAGE_BASE_KNOCKBACK: float = 6.4

func _ready() -> void:
	super._ready()
	_register_round5_leader_items()
	print("R5 LEADER PRESSURE ITEMS READY items=4 torpedo=true storm=true anchor=true barrage=true shield_counter=true round5_only=true")

func is_valid_item(item_id: StringName) -> bool:
	return ROUND5_LEADER_ITEM_IDS.has(item_id) or super.is_valid_item(item_id)

func is_new_item(item_id: StringName) -> bool:
	return ROUND5_LEADER_ITEM_IDS.has(item_id) or super.is_new_item(item_id)

func get_item_count() -> int:
	return super.get_item_count() + ROUND5_LEADER_ITEM_IDS.size()

func get_all_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id: StringName in super.get_all_item_ids():
		result.append(item_id)
	for item_id: StringName in ROUND5_LEADER_ITEM_IDS:
		result.append(item_id)
	return result

func get_definition(item_id: StringName) -> WildDashItemDefinition:
	if ROUND5_LEADER_ITEM_IDS.has(item_id) and not _definitions.has(item_id):
		_register_round5_leader_items()
	return super.get_definition(item_id)

func roll_item_for_rank(rank: int, total: int, history: Array = []) -> StringName:
	if not _round5_pressure_active():
		return super.roll_item_for_rank(rank, total, history)
	var safe_total := maxi(1, total)
	var safe_rank := clampi(rank, 1, safe_total)
	var normalized := float(safe_rank - 1) / float(maxi(1, safe_total - 1))
	var band: StringName = &"mid"
	if normalized <= 0.30:
		band = &"front"
	elif normalized >= 0.70:
		band = &"back"
	var gap := get_round5_leader_gap_for_rank(safe_rank)
	var picked := _weighted_pick_round5(band, history, safe_rank, safe_total, gap)
	if ROUND5_LEADER_ITEM_IDS.has(picked):
		print("r5_leader_item_roll rank=%d/%d item=%s leader_gap=%.1f gap_weight=%.2f" % [
			safe_rank, safe_total, String(picked), gap, _leader_gap_multiplier(gap),
		])
	return picked

func use_held_item(character: Node) -> bool:
	if character == null or not character.has_method("get_held_item"):
		return false
	var item_id := StringName(character.call("get_held_item"))
	if not ROUND5_LEADER_ITEM_IDS.has(item_id):
		return super.use_held_item(character)
	if not _round5_pressure_active():
		return false
	var used := false
	match item_id:
		RIVER_TORPEDO:
			used = _use_river_torpedo(character)
		STORM_BOMB:
			used = _use_storm_bomb(character)
		CURRENT_ANCHOR:
			used = _use_current_anchor(character)
		TIDAL_BARRAGE:
			used = _use_tidal_barrage(character)
	if not used:
		return false
	_complete_round5_special_use(character, item_id)
	return true

func get_status_text(character: Node) -> String:
	if character != null and character.has_method("get_held_item"):
		var held := StringName(character.call("get_held_item"))
		match held:
			RIVER_TORPEDO:
				return "RIVER TORPEDO READY · TARGETS #1 · Q / B"
			STORM_BOMB:
				return "STORM BOMB READY · TARGETS #1 · Q / B"
			CURRENT_ANCHOR:
				return "CURRENT ANCHOR READY · TARGETS #1 · Q / B"
			TIDAL_BARRAGE:
				return "TIDAL BARRAGE READY · TARGETS TOP 3 · Q / B"
	return super.get_status_text(character)

func is_round5_leader_pressure_item(item_id: StringName) -> bool:
	return ROUND5_LEADER_ITEM_IDS.has(item_id)

func get_round5_leader_target(source: Node = null) -> WildDashCharacterController:
	if not _round5_pressure_active():
		return null
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or racer.finished or racer == source:
			continue
		if RaceManager.get_rank(racer) == 1:
			return racer
	return null

func get_round5_leader_gap_for_rank(rank: int) -> float:
	if not _round5_pressure_active() or rank <= 1:
		return 0.0
	var leader := get_round5_leader_target(null)
	if leader == null:
		return 0.0
	var leader_progress := RaceManager.get_track_progress(leader)
	var candidate_progress := leader_progress
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer != null and not racer.finished and RaceManager.get_rank(racer) == rank:
			candidate_progress = RaceManager.get_track_progress(racer)
			break
	return maxf(0.0, leader_progress - candidate_progress)

func _weighted_pick_round5(band: StringName, history: Array, rank: int, total: int, leader_gap: float) -> StringName:
	var ids := get_all_item_ids()
	var weighted: Dictionary = {}
	var weight_total := 0.0
	for item_id: StringName in ids:
		var weight := 0.0
		if ROUND5_LEADER_ITEM_IDS.has(item_id):
			weight = _leader_item_weight(item_id, rank, total, leader_gap)
		elif item_id == WILD_TURBO:
			weight = get_wild_turbo_weight_for_rank(rank, total)
		else:
			var definition := get_definition(item_id)
			weight = definition.weight_for_band(band) if definition != null else 1.0
		weight *= _history_multiplier(item_id, history)
		weighted[item_id] = weight
		weight_total += weight
	if weight_total <= 0.0:
		return DASH_BERRY
	var roll := _rng.randf_range(0.0, weight_total)
	var cursor := 0.0
	for item_id: StringName in ids:
		cursor += float(weighted.get(item_id, 0.0))
		if roll <= cursor:
			return item_id
	return ids[-1]

func _leader_item_weight(item_id: StringName, rank: int, total: int, leader_gap: float) -> float:
	if rank <= 1:
		return 0.0
	var back_start := maxi(4, ceili(float(total) * 0.58))
	var weight := 0.0
	if rank <= 3:
		match item_id:
			RIVER_TORPEDO: weight = TORPEDO_FRONT_CHASE_WEIGHT
			STORM_BOMB: weight = STORM_FRONT_CHASE_WEIGHT
			CURRENT_ANCHOR: weight = ANCHOR_FRONT_CHASE_WEIGHT
			TIDAL_BARRAGE: weight = BARRAGE_FRONT_CHASE_WEIGHT
	elif rank >= back_start:
		match item_id:
			RIVER_TORPEDO: weight = TORPEDO_BACK_WEIGHT
			STORM_BOMB: weight = STORM_BACK_WEIGHT
			CURRENT_ANCHOR: weight = ANCHOR_BACK_WEIGHT
			TIDAL_BARRAGE: weight = BARRAGE_BACK_WEIGHT
	else:
		match item_id:
			RIVER_TORPEDO: weight = TORPEDO_MID_WEIGHT
			STORM_BOMB: weight = STORM_MID_WEIGHT
			CURRENT_ANCHOR: weight = ANCHOR_MID_WEIGHT
			TIDAL_BARRAGE: weight = BARRAGE_MID_WEIGHT
	return weight * _leader_gap_multiplier(leader_gap)

func _leader_gap_multiplier(leader_gap: float) -> float:
	if leader_gap >= 80.0:
		return 1.90
	if leader_gap >= 45.0:
		return 1.55
	if leader_gap >= 22.0:
		return 1.25
	return 1.0

func _register_round5_leader_items() -> void:
	if not _definitions.has(RIVER_TORPEDO):
		_register_definition(RIVER_TORPEDO, "RIVER TORPEDO", &"attack", "RT", "LEADER SEEKER", 0.0, 18.0, 28.0, 0.0, 52.0, 7.2)
	if not _definitions.has(STORM_BOMB):
		_register_definition(STORM_BOMB, "STORM BOMB", &"attack", "SB", "LEADER STORM", 0.0, 15.0, 22.0, 1.25, 0.48, 6.0)
	if not _definitions.has(CURRENT_ANCHOR):
		_register_definition(CURRENT_ANCHOR, "CURRENT ANCHOR", &"attack", "CA", "LEADER ANCHOR", 0.0, 13.0, 20.0, ANCHOR_DURATION, ANCHOR_SLOW, ANCHOR_KNOCKBACK)
	if not _definitions.has(TIDAL_BARRAGE):
		_register_definition(TIDAL_BARRAGE, "TIDAL BARRAGE", &"attack", "TB", "TOP 3 BARRAGE", 0.0, 11.0, 17.0, BARRAGE_DURATION, BARRAGE_BASE_SLOW, BARRAGE_BASE_KNOCKBACK)

func _use_river_torpedo(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var source := character as WildDashCharacterController
	var target := get_round5_leader_target(source)
	if target == null:
		return false
	var world := source.get_parent()
	if world == null:
		return false
	var torpedo: WildDashRiverTorpedo = RIVER_TORPEDO_SCRIPT.new() as WildDashRiverTorpedo
	if torpedo == null:
		return false
	world.add_child(torpedo)
	torpedo.configure(source, target)
	var forward := -source.global_transform.basis.z.normalized()
	torpedo.global_position = source.global_position + forward * 2.2 + Vector3.UP * 0.35
	print("r5_leader_target_acquired item=river_torpedo source=%s target=%s target_rank=1 gap=%.1f" % [
		_label(source), _label(target), maxf(0.0, RaceManager.get_track_progress(target) - RaceManager.get_track_progress(source)),
	])
	return true

func _use_storm_bomb(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var source := character as WildDashCharacterController
	var target := get_round5_leader_target(source)
	if target == null:
		return false
	var world := source.get_parent()
	if world == null:
		return false
	var bomb: WildDashStormBomb = STORM_BOMB_SCRIPT.new() as WildDashStormBomb
	if bomb == null:
		return false
	world.add_child(bomb)
	bomb.configure(source, target)
	print("r5_leader_target_acquired item=storm_bomb source=%s target=%s target_rank=1 warning=1.25" % [_label(source), _label(target)])
	return true

func _use_current_anchor(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var source := character as WildDashCharacterController
	var target := get_round5_leader_target(source)
	if target == null:
		return false
	var resolved := apply_attack(target, source, &"current_anchor", ANCHOR_DURATION, ANCHOR_SLOW, ANCHOR_KNOCKBACK)
	if resolved:
		_play_target_hit_feedback(target)
		AudioManager.play_sfx_id("splash", 1.0)
		print("r5_current_anchor_resolve source=%s target=%s slow=%.2f duration=%.2f knockback=%.1f shield_counter=true" % [
			_label(source), _label(target), ANCHOR_SLOW, ANCHOR_DURATION, ANCHOR_KNOCKBACK,
		])
	return resolved

func _use_tidal_barrage(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var source := character as WildDashCharacterController
	if RaceManager.get_rank(source) <= 1:
		return false
	var hits := 0
	for target_rank in range(1, 4):
		var target: WildDashCharacterController = null
		for value: Variant in RaceManager.racers:
			var candidate := value as WildDashCharacterController
			if candidate != null and candidate != source and not candidate.finished and RaceManager.get_rank(candidate) == target_rank:
				target = candidate
				break
		if target == null:
			continue
		var strength_scale := 1.0 if target_rank == 1 else (0.78 if target_rank == 2 else 0.62)
		var slow := 1.0 - (1.0 - BARRAGE_BASE_SLOW) * strength_scale
		var knockback := BARRAGE_BASE_KNOCKBACK * strength_scale
		if apply_attack(target, source, &"tidal_barrage", BARRAGE_DURATION * maxf(0.65, strength_scale), slow, knockback):
			hits += 1
			_play_target_hit_feedback(target)
	AudioManager.play_sfx_id("splash", 1.0)
	print("r5_tidal_barrage_resolve source=%s hits=%d targets=top3 leader_power=%.1f shield_counter=true" % [
		_label(source), hits, BARRAGE_BASE_KNOCKBACK,
	])
	return hits > 0

func _complete_round5_special_use(character: Node, item_id: StringName) -> void:
	character.call("set_held_item", &"")
	_last_used_item[character.get_instance_id()] = item_id
	_usage_counts[item_id] = int(_usage_counts.get(item_id, 0)) + 1
	item_used.emit(character, item_id)
	AudioManager.play_sfx_id("item", 1.0)
	print("r5_leader_item_use racer=%s item=%s rank=%d round5_only=true hidden_rubber_band=false" % [
		_label(character), String(item_id), RaceManager.get_rank(character as Node3D),
	])

func _play_target_hit_feedback(target: WildDashCharacterController) -> void:
	if target == null:
		return
	var visual := target.get_visual()
	if visual != null:
		visual.play_action(&"Hit", 0.28)

func _round5_pressure_active() -> bool:
	return GameManager.round_active and RaceManager.active and GameManager.get_current_round_id() == &"wild_current"
