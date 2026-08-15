class_name WildDashLongBombItemSupport
extends RefCounted

const BOMB_SCRIPT: Script = preload("res://items/acorn_bomb.gd")
const TARGET_DISTANCE: float = 120.0
const MAX_RANK_LOOKAHEAD: int = 4
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

	# Preserve an Acorn/Pack Buster roll for trailing racers so the expansion
	# layer cannot replace the comeback item after the yellow box grants it.
	if granted_item == ItemSystem.ACORN_BOMB and back_ratio >= BACK_HALF_START:
		print("LONG BOMB PRESERVE racer=%s rank=%d/%d back_ratio=%.2f" % [
			RaceManager.get_racer_label(racer), rank, total, back_ratio,
		])
		return true

	# Front runners never receive the extra conversion. The existing catch-up
	# probabilities are intentionally retained from Long Bomb V1.
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

	# Rank order is the authority for a catch-up weapon. Camera facing can point
	# sideways in a corner, so the old find_target_ahead() call often failed and
	# degraded into a weak straight throw. V2 locks the racer immediately ahead.
	var target: WildDashCharacterController = find_race_target_ahead_by_rank(
		character,
		MAX_RANK_LOOKAHEAD,
		TARGET_DISTANCE
	)
	var fallback_point: Vector3 = _build_fallback_target_point(character)

	var bomb: WildDashAcornBomb = BOMB_SCRIPT.new() as WildDashAcornBomb
	if bomb == null:
		return false
	bomb.name = "PackBusterBomb_%d" % Time.get_ticks_msec()
	world.add_child(bomb)

	var forward: Vector3 = -character.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	bomb.global_position = character.global_position + forward * 1.8 + Vector3.UP * 1.25
	bomb.configure(character, target, fallback_point)

	character.set_held_item(&"")
	character.set_meta(&"wilddash_last_expanded_item", ItemSystem.ACORN_BOMB)
	ItemSystem.item_used.emit(character, ItemSystem.ACORN_BOMB)
	AudioManager.play_sfx_id("item", 1.0)

	var source_rank: int = RaceManager.get_rank(character)
	var target_rank: int = 0
	var target_label: String = "AHEAD PACK ARC"
	if target != null:
		target_rank = RaceManager.get_rank(target)
		target_label = RaceManager.get_racer_label(target)
	print("PACK BUSTER THROW source=%s rank=%d/%d target=%s target_rank=%d max_range=%.0f" % [
		RaceManager.get_racer_label(character),
		source_rank,
		RaceManager.racers.size(),
		target_label,
		target_rank,
		TARGET_DISTANCE,
	])
	return true

static func find_race_target_ahead_by_rank(
	source: WildDashCharacterController,
	max_rank_offset: int,
	max_distance: float
) -> WildDashCharacterController:
	if source == null:
		return null
	var standings: Array[Node3D] = RaceManager.get_standings()
	var source_index: int = standings.find(source)
	if source_index > 0:
		var lookahead: int = mini(max_rank_offset, source_index)
		for offset: int in range(1, lookahead + 1):
			var index: int = source_index - offset
			var candidate: WildDashCharacterController = standings[index] as WildDashCharacterController
			if candidate == null or candidate.finished or RaceManager.finish_order.has(candidate):
				continue
			var distance: float = source.global_position.distance_to(candidate.global_position)
			if distance <= max_distance:
				return candidate

	# Fallback uses race progress rather than camera direction. This catches cases
	# where cached standings are momentarily tied or the immediate rank is just
	# outside the preferred spatial range.
	var source_progress: float = RaceManager.get_track_progress(source)
	var best: WildDashCharacterController
	var best_progress_gap: float = INF
	var fallback_distance: float = max_distance * 1.30
	for value: Variant in RaceManager.racers:
		var candidate: WildDashCharacterController = value as WildDashCharacterController
		if candidate == null or candidate == source or candidate.finished or RaceManager.finish_order.has(candidate):
			continue
		var progress_gap: float = RaceManager.get_track_progress(candidate) - source_progress
		if progress_gap <= 0.25 or progress_gap >= best_progress_gap:
			continue
		if source.global_position.distance_to(candidate.global_position) > fallback_distance:
			continue
		best_progress_gap = progress_gap
		best = candidate
	return best

static func _build_fallback_target_point(source: WildDashCharacterController) -> Vector3:
	var standings: Array[Node3D] = RaceManager.get_standings()
	var source_index: int = standings.find(source)
	var centroid: Vector3 = Vector3.ZERO
	var count: int = 0
	if source_index > 0:
		var first_index: int = maxi(0, source_index - 3)
		for index: int in range(first_index, source_index):
			var candidate: WildDashCharacterController = standings[index] as WildDashCharacterController
			if candidate == null or candidate.finished:
				continue
			centroid += candidate.global_position
			count += 1
	if count > 0:
		centroid /= float(count)
		var to_pack: Vector3 = centroid - source.global_position
		to_pack.y = 0.0
		if to_pack.length() > TARGET_DISTANCE:
			to_pack = to_pack.normalized() * TARGET_DISTANCE
			centroid = source.global_position + to_pack
		return centroid + Vector3.UP * 0.25

	# Even with no valid rival ahead, commit to a short, visible ballistic toss;
	# never revert to a slow forward-sliding projectile.
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	return source.global_position + forward * 24.0 + Vector3.UP * 0.20
