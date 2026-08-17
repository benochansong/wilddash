extends "res://modes/grand_prix/grand_prix_v5_item_chaos.gd"

## Round 1 V6 — shared item fairness relay.
## A front runner may consume the visible box, but a trailing racer who reaches
## the same station shortly afterwards can still receive one catch-up item.
## This is mode-local so other rounds keep the shared ItemBox behavior.

const FAIR_RESPAWN_DEFAULT: float = 2.25
const FAIR_RESPAWN_15: float = 1.95
const FAIR_RESPAWN_18: float = 1.65
const FAIR_RELAY_WINDOW_MSEC: int = 2600
const FAIR_STATION_LOCK_MSEC: int = 6000
const FAIR_RELAY_RADIUS: float = 2.60
const FAIR_RELAY_VERTICAL: float = 3.00
const FAIR_GLOBAL_LOCK_MSEC: int = 1100
const FAIR_ITEM_LOCK_META: StringName = &"wilddash_item_box_pickup_until_msec"
const ROUND1_PICKUP_RADIUS_SCALE: float = 0.50
const ROUND1_PICKUP_VERTICAL_SCALE: float = 0.72
const ROUND1_PICKUP_COLLISION_RADIUS: float = 1.35

var _fair_box_inactive_since: Dictionary = {}
var _fair_box_was_active: Dictionary = {}
var _fair_station_claim_until: Dictionary = {}
var _fair_relay_grants: int = 0

func _ready() -> void:
	await super()
	var respawn: float = FAIR_RESPAWN_DEFAULT
	if RaceManager.racers.size() >= 18:
		respawn = FAIR_RESPAWN_18
	elif RaceManager.racers.size() >= 15:
		respawn = FAIR_RESPAWN_15
	for box: WildDashItemBox in _item_boxes:
		if box == null or not is_instance_valid(box):
			continue
		box.respawn_seconds = respawn
		box.configure_pickup_profile(
			ROUND1_PICKUP_RADIUS_SCALE,
			ROUND1_PICKUP_VERTICAL_SCALE,
			FAIR_GLOBAL_LOCK_MSEC,
			false,
			ROUND1_PICKUP_COLLISION_RADIUS
		)
		_fair_box_was_active[box.get_instance_id()] = box.is_active()
	print("ROUND1 FAIR ITEM READY boxes=%d respawn=%.2fs relay_window=%.2fs relay_radius=%.2fm pickup_scale=%.2f one_item_at_a_time=true leader_excluded=true trailing_shared=true" % [
		_item_boxes.size(), respawn, float(FAIR_RELAY_WINDOW_MSEC) / 1000.0, FAIR_RELAY_RADIUS, ROUND1_PICKUP_RADIUS_SCALE,
	])

func _process(delta: float) -> void:
	super._process(delta)
	_round1_item_fairness_relay()

func _round1_item_fairness_relay() -> void:
	if not RaceManager.active or _item_boxes.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	_cleanup_fair_station_locks(now)

	for box: WildDashItemBox in _item_boxes:
		if box == null or not is_instance_valid(box):
			continue
		var box_id: int = box.get_instance_id()
		if box.is_active():
			_fair_box_was_active[box_id] = true
			_fair_box_inactive_since.erase(box_id)
			continue

		if bool(_fair_box_was_active.get(box_id, true)):
			_fair_box_was_active[box_id] = false
			_fair_box_inactive_since[box_id] = now
		if not _fair_box_inactive_since.has(box_id):
			continue
		var inactive_since: int = int(_fair_box_inactive_since[box_id])
		var inactive_age: int = now - inactive_since
		if inactive_age < 0 or inactive_age > FAIR_RELAY_WINDOW_MSEC:
			continue
		_grant_fair_relay_near_box(box, now, inactive_age)

func _grant_fair_relay_near_box(box: WildDashItemBox, now: int, inactive_age: int) -> void:
	var station: String = _fair_station_key(box)
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var rank: int = RaceManager.get_rank(racer)
		if rank <= 1:
			continue
		if racer.get_held_item() != &"":
			continue
		if now < int(racer.get_meta(FAIR_ITEM_LOCK_META, 0)):
			continue
		var claim_key: String = "%d:%s" % [racer.get_instance_id(), station]
		if now < int(_fair_station_claim_until.get(claim_key, 0)):
			continue
		var probe: Vector3 = racer.global_position + Vector3.UP * 0.8
		if not _fair_relay_hit(box.global_position, probe):
			continue
		if not ItemSystem.grant_weighted_item(racer):
			continue

		racer.set_meta(FAIR_ITEM_LOCK_META, now + FAIR_GLOBAL_LOCK_MSEC)
		_fair_station_claim_until[claim_key] = now + FAIR_STATION_LOCK_MSEC
		_fair_relay_grants += 1
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null:
			audio.call("play_sfx_id", "item", 0.78)
		if racer.is_player and hud != null:
			hud.set_message("CATCH-UP ITEM! · %s" % ItemSystem.get_display_name(racer.get_held_item()))
		print("ROUND1 FAIR ITEM RELAY racer=%s rank=%d station=%s item=%s inactive_ms=%d grants=%d" % [
			RaceManager.get_racer_label(racer),
			rank,
			station,
			ItemSystem.get_display_name(racer.get_held_item()),
			inactive_age,
			_fair_relay_grants,
		])

func _fair_relay_hit(point: Vector3, probe: Vector3) -> bool:
	if absf(point.y - probe.y) > FAIR_RELAY_VERTICAL:
		return false
	return Vector2(point.x, point.z).distance_to(Vector2(probe.x, probe.z)) <= FAIR_RELAY_RADIUS

func _fair_station_key(box: WildDashItemBox) -> String:
	var text: String = String(box.name)
	var lane_pos: int = text.find("_L")
	if lane_pos > 0:
		return text.substr(0, lane_pos)
	return text

func _cleanup_fair_station_locks(now: int) -> void:
	if _fair_station_claim_until.size() < 96:
		return
	for key: Variant in _fair_station_claim_until.keys():
		if now >= int(_fair_station_claim_until[key]):
			_fair_station_claim_until.erase(key)
