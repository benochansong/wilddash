class_name WildDashCharacterMotionPolish
extends Node

## Graphics Phase 3 additive animation polish.
## Only VisualSlot and PremiumCharacterArt transforms are animated. CharacterBody
## transform, velocity, collision and gameplay animation state remain authoritative.

var _racer: WildDashCharacterController
var _visual_slot: Node3D
var _premium_art: Node3D
var _slot_base_position := Vector3.ZERO
var _slot_base_rotation := Vector3.ZERO
var _slot_base_scale := Vector3.ONE
var _art_base_position := Vector3.ZERO
var _art_base_rotation := Vector3.ZERO
var _art_base_scale := Vector3.ONE
var _last_grounded := true
var _landing_pulse := 0.0
var _takeoff_pulse := 0.0
var _time := 0.0
var _tick := 0

func _ready() -> void:
	_racer = get_parent() as WildDashCharacterController
	if _racer == null or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_visual_slot = _racer.get_node_or_null("VisualSlot") as Node3D
	_premium_art = _racer.get_node_or_null("PremiumCharacterArt") as Node3D
	if _visual_slot != null:
		_slot_base_position = _visual_slot.position
		_slot_base_rotation = _visual_slot.rotation
		_slot_base_scale = _visual_slot.scale
	if _premium_art != null:
		_art_base_position = _premium_art.position
		_art_base_rotation = _premium_art.rotation
		_art_base_scale = _premium_art.scale
	_last_grounded = _racer.is_on_floor()
	print("GRAPHICS PHASE 3 CHARACTER MOTION READY racer=%s species=%s visual_only=true" % [_racer.name, String(_racer.animal_id)])

func _process(delta: float) -> void:
	if _racer == null or _visual_slot == null:
		return
	_tick += 1
	var lod := _racer.get_performance_lod()
	if lod >= 2 and _tick % 3 != 0:
		return
	_time += delta
	var grounded := _racer.is_on_floor()
	if _last_grounded and not grounded:
		_takeoff_pulse = 1.0
	elif not _last_grounded and grounded:
		_landing_pulse = 1.0
	_last_grounded = grounded
	_takeoff_pulse = maxf(0.0, _takeoff_pulse - delta * 6.8)
	_landing_pulse = maxf(0.0, _landing_pulse - delta * 7.2)
	_apply_pose(grounded)

func _apply_pose(grounded: bool) -> void:
	var speed_ratio := clampf(Vector2(_racer.velocity.x, _racer.velocity.z).length() / maxf(1.0, _racer.max_speed), 0.0, 1.35)
	var profile := _species_motion_profile()
	var run_amount := speed_ratio if grounded and not _racer.finished else 0.0
	var bounce := absf(sin(_time * float(profile["cycle"]))) * float(profile["bounce"]) * run_amount
	var lean := -float(profile["lean"]) * clampf(speed_ratio, 0.0, 1.0)
	var position_offset := Vector3(0.0, bounce, 0.0)
	var rotation_offset := Vector3(lean, 0.0, 0.0)
	var scale_offset := Vector3.ONE

	if not grounded:
		# A small readable stretch emphasizes jump arc without changing jump height.
		scale_offset = Vector3(0.97, 1.045, 0.97)
		rotation_offset.x -= 0.035
	if _takeoff_pulse > 0.0:
		var e := sin(_takeoff_pulse * PI)
		scale_offset *= Vector3(0.95 + e * 0.01, 1.0 + e * 0.10, 0.95 + e * 0.01)
	if _landing_pulse > 0.0:
		var e := sin(_landing_pulse * PI)
		scale_offset *= Vector3(1.0 + e * float(profile["squash_x"]), 1.0 - e * float(profile["squash_y"]), 1.0 + e * float(profile["squash_x"]))
		position_offset.y -= e * 0.045

	var visual := _racer.get_visual()
	if visual != null and visual.get_current_state() == &"Hit":
		rotation_offset.x += 0.06
		scale_offset *= Vector3(1.04, 0.96, 1.04)
	if _racer.finished:
		var victory := absf(sin(_time * 4.8))
		position_offset.y += victory * 0.10
		rotation_offset.y += sin(_time * 2.7) * 0.10

	_visual_slot.position = _slot_base_position + position_offset
	_visual_slot.rotation.x = _slot_base_rotation.x + rotation_offset.x
	_visual_slot.rotation.y = _slot_base_rotation.y + rotation_offset.y
	_visual_slot.scale = _slot_base_scale * scale_offset
	if _premium_art != null:
		_premium_art.position = _art_base_position + position_offset
		_premium_art.rotation.x = _art_base_rotation.x + rotation_offset.x
		_premium_art.rotation.y = _art_base_rotation.y + rotation_offset.y
		_premium_art.scale = _art_base_scale * scale_offset

func _species_motion_profile() -> Dictionary:
	match _racer.animal_id:
		&"rabbit": return {"cycle": 12.0, "bounce": 0.075, "lean": 0.085, "squash_x": 0.085, "squash_y": 0.13}
		&"monkey": return {"cycle": 11.0, "bounce": 0.068, "lean": 0.070, "squash_x": 0.080, "squash_y": 0.11}
		&"fox", &"cat", &"deer": return {"cycle": 11.5, "bounce": 0.058, "lean": 0.080, "squash_x": 0.070, "squash_y": 0.10}
		&"elephant": return {"cycle": 7.2, "bounce": 0.035, "lean": 0.045, "squash_x": 0.095, "squash_y": 0.08}
		&"bear", &"boar": return {"cycle": 8.0, "bounce": 0.043, "lean": 0.052, "squash_x": 0.090, "squash_y": 0.09}
		&"crocodile": return {"cycle": 8.6, "bounce": 0.028, "lean": 0.038, "squash_x": 0.065, "squash_y": 0.06}
		&"wolf": return {"cycle": 10.0, "bounce": 0.052, "lean": 0.074, "squash_x": 0.070, "squash_y": 0.10}
		_: return {"cycle": 9.6, "bounce": 0.050, "lean": 0.065, "squash_x": 0.072, "squash_y": 0.10}
