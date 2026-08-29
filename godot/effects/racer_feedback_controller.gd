class_name WildDashRacerFeedbackController
extends Node3D

## Graphics Phase 3 visual feedback layer for every racer.
## This node reads gameplay state but never writes movement, collision, AI, jump,
## recovery or balance values. Short effects are recycled from a fixed pool.

const PLAYER_STRENGTH := 1.0
const NEAR_RIVAL_STRENGTH := 0.68
const FAR_RIVAL_STRENGTH := 0.28
const NEAR_DISTANCE := 19.0
const FX_POOL_SIZE := 10
const SURFACE_SAMPLE_INTERVAL := 0.16
const RANK_SAMPLE_INTERVAL := 0.24

const SURFACE_GRASS: StringName = &"grass"
const SURFACE_DIRT: StringName = &"dirt"
const SURFACE_WOOD: StringName = &"wood"
const SURFACE_SAND: StringName = &"sand"
const SURFACE_WATER: StringName = &"water"
const SURFACE_METAL: StringName = &"metal"

var _racer: WildDashCharacterController
var _premium_art: WildDashPremiumCharacterArt
var _last_grounded := true
var _last_vertical_speed := 0.0
var _last_boosted := false
var _last_visual_state: StringName = &""
var _step_clock := 0.0
var _surface_clock := 0.0
var _rank_clock := 0.0
var _swim_signal_timeout := 0.0
var _was_swimming := false
var _surface: StringName = SURFACE_DIRT
var _last_rank := 0
var _fx_cursor := 0
var _fx_slots: Array[Dictionary] = []
var _boost_trails: Array[MeshInstance3D] = []
var _glow: MeshInstance3D
var _glow_material: StandardMaterial3D

func _ready() -> void:
	_racer = get_parent() as WildDashCharacterController
	if _racer == null or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_build_pool()
	_build_boost_visuals()
	_premium_art = _racer.get_node_or_null("PremiumCharacterArt") as WildDashPremiumCharacterArt
	if not _racer.held_item_changed.is_connected(_on_held_item_changed):
		_racer.held_item_changed.connect(_on_held_item_changed)
	if not _racer.finished_race.is_connected(_on_finished):
		_racer.finished_race.connect(_on_finished)
	_last_grounded = _racer.is_on_floor()
	_last_rank = RaceManager.get_rank(_racer) if _racer.movement_mode == WildDashCharacterController.MovementMode.RACE else 0
	print("GRAPHICS PHASE 3 RACER FEEDBACK READY racer=%s player=%s pooled_fx=%d lod=1.00/0.68/0.28 gameplay_changed=false" % [_racer.name, str(_racer.is_player), FX_POOL_SIZE])

func _process(delta: float) -> void:
	if _racer == null or not is_instance_valid(_racer):
		return
	var strength := _effect_strength()
	_update_pool(delta)
	_update_surface(delta, strength)
	_update_locomotion_feedback(delta, strength)
	_update_boost(strength)
	_update_hit_feedback(strength)
	_update_swimming(delta, strength)
	_update_rank_feedback(delta)
	_last_vertical_speed = _racer.velocity.y

func notify_body_check(direction: Vector3, power: float, received := false) -> void:
	var strength := _effect_strength()
	if strength <= 0.05:
		return
	var heavy_scale := clampf(power / 8.0, 0.75, 1.45)
	var color := Color("ffbf4d") if not received else Color("ff6b55")
	_emit_pulse(&"impact", Vector3(0.0, 1.0, -0.55), color, strength * heavy_scale)
	_emit_pulse(&"spark", direction.normalized() * 0.35 + Vector3.UP * 1.0, Color("fff2b5"), strength * heavy_scale)
	if _premium_art != null:
		_premium_art.notify_visual_action(&"Hit" if received else &"Skill")
	if _racer.is_player:
		_request_camera_impulse(direction, 0.16 * heavy_scale)

func notify_boost() -> void:
	_start_boost_feedback(_effect_strength())

func notify_swimming(water_y: float, crocodile := false) -> void:
	_swim_signal_timeout = 0.22
	if not _was_swimming:
		_was_swimming = true
		_surface = SURFACE_WATER
		_emit_pulse(&"ring", Vector3(0.0, water_y - _racer.global_position.y + 0.10, 0.0), Color("7bdfff"), _effect_strength() * 1.15)
		_emit_pulse(&"splash", Vector3(0.0, 0.45, 0.0), Color("d7f7ff"), _effect_strength())
		if _racer.is_player:
			_play_sfx("splash", 0.74)
	var speed_ratio := Vector2(_racer.velocity.x, _racer.velocity.z).length() / maxf(1.0, _racer.max_speed)
	_step_clock += 0.045 * maxf(0.3, speed_ratio)
	if _step_clock >= (0.32 if crocodile else 0.46):
		_step_clock = 0.0
		_emit_pulse(&"wake", Vector3(0.0, 0.18, 0.65), Color("80e7ff"), _effect_strength() * (1.35 if crocodile else 0.75))

func notify_recovery(kind: StringName = &"root") -> void:
	var color := Color("b7da75")
	if kind == &"ladder":
		color = Color("ffd36a")
	elif kind == &"vine":
		color = Color("74e69b")
	_emit_pulse(&"recovery", Vector3(0.0, 0.55, 0.0), color, _effect_strength())
	if _racer.is_player:
		_play_sfx("recovery", 0.62)

func notify_item_pickup(golden := false) -> void:
	_emit_pulse(&"item", Vector3(0.0, 1.15, 0.0), Color("ffd94e") if golden else Color("66eaff"), _effect_strength() * (1.25 if golden else 0.90))
	if _premium_art != null:
		_premium_art.set_expression(WildDashPremiumCharacterArt.EXPRESSION_HAPPY, 0.55)
	if _racer.is_player:
		_play_sfx("item_gold" if golden else "item", 0.78)
		var hud := _find_hud()
		if hud != null and hud.has_method("play_item_pop"):
			hud.call("play_item_pop", golden)

func _update_locomotion_feedback(delta: float, strength: float) -> void:
	var grounded := _racer.is_on_floor()
	if _last_grounded and not grounded:
		_emit_pulse(&"takeoff", Vector3(0.0, 0.12, 0.24), _surface_color(_surface), strength * 0.72)
		if _premium_art != null:
			_premium_art.notify_visual_action(&"Jump")
		if _racer.is_player:
			_play_sfx("jump", 0.66)
	elif not _last_grounded and grounded:
		var impact_speed := absf(minf(_last_vertical_speed, 0.0))
		var hard := impact_speed >= 8.2
		var amount := clampf(0.55 + impact_speed / 12.0, 0.55, 1.35)
		_emit_pulse(&"landing", Vector3(0.0, 0.10, 0.0), _surface_color(_surface), strength * amount)
		_emit_pulse(&"ring", Vector3(0.0, 0.07, 0.0), Color(1.0, 0.94, 0.72, 0.9), strength * (0.95 if hard else 0.50))
		if _racer.is_player:
			_play_sfx(_landing_sfx(_surface), 0.78 if hard else 0.48)
			_request_camera_impulse(Vector3.DOWN, 0.14 if hard else 0.055)
	_last_grounded = grounded

	if not grounded or _was_swimming:
		return
	var planar_speed := Vector2(_racer.velocity.x, _racer.velocity.z).length()
	if planar_speed < maxf(2.1, _racer.cruise_speed * 0.34):
		return
	_step_clock += delta * clampf(planar_speed / maxf(1.0, _racer.cruise_speed), 0.55, 1.65)
	var species_step := 0.34
	if _racer.animal_id in [&"elephant", &"bear", &"boar"]:
		species_step = 0.40
	elif _racer.animal_id in [&"rabbit", &"fox", &"cat", &"deer"]:
		species_step = 0.29
	if _step_clock >= species_step:
		_step_clock = 0.0
		_emit_pulse(&"foot", Vector3(0.0, 0.08, 0.30), _surface_color(_surface), strength * 0.38)
		if _racer.is_player:
			_play_sfx("foot_%s" % String(_surface), 0.24)

func _update_boost(strength: float) -> void:
	var boosted := _racer.get_active_speed_scale() > 1.02 or _racer.current_speed > _racer.max_speed * 1.02
	for trail in _boost_trails:
		trail.visible = boosted and strength >= 0.18
		trail.scale.z = 0.65 + strength * 0.85
	if _glow != null:
		_glow.visible = boosted and strength >= 0.18
	if boosted and not _last_boosted:
		_start_boost_feedback(strength)
	_last_boosted = boosted

func _start_boost_feedback(strength: float) -> void:
	_emit_pulse(&"boost", Vector3(0.0, 0.82, 0.30), Color("78ecff"), strength * 1.05)
	if _premium_art != null:
		_premium_art.notify_visual_action(&"Boost")
	if _racer.is_player:
		_play_sfx("boost", 0.86)

func _update_hit_feedback(strength: float) -> void:
	var visual := _racer.get_visual()
	if visual == null:
		return
	var state := visual.get_current_state()
	if state == &"Hit" and _last_visual_state != &"Hit":
		_emit_pulse(&"impact", Vector3(0.0, 1.0, -0.45), Color("ff765c"), strength)
		if _premium_art != null:
			_premium_art.notify_visual_action(&"Hit")
		if _racer.is_player:
			_request_camera_impulse(Vector3(-1.0, 0.15, 0.0), 0.10)
	_last_visual_state = state

func _update_swimming(delta: float, strength: float) -> void:
	if _swim_signal_timeout > 0.0:
		_swim_signal_timeout = maxf(0.0, _swim_signal_timeout - delta)
		return
	if _was_swimming:
		_was_swimming = false
		_emit_pulse(&"recovery", Vector3(0.0, 0.18, 0.0), Color("b9e88a"), strength * 0.72)

func _update_surface(delta: float, strength: float) -> void:
	_surface_clock -= delta
	if _surface_clock > 0.0:
		return
	_surface_clock = SURFACE_SAMPLE_INTERVAL / maxf(0.35, strength)
	if _was_swimming or get_world_3d() == null:
		return
	var query := PhysicsRayQueryParameters3D.new()
	query.from = _racer.global_position + Vector3.UP * 0.30
	query.to = _racer.global_position + Vector3.DOWN * 1.05
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [_racer.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider == null:
		return
	var label := String(collider.get("name")).to_lower()
	_surface = _surface_from_label(label)

func _update_rank_feedback(delta: float) -> void:
	if not _racer.is_player or _racer.movement_mode != WildDashCharacterController.MovementMode.RACE or not RaceManager.active:
		return
	_rank_clock -= delta
	if _rank_clock > 0.0:
		return
	_rank_clock = RANK_SAMPLE_INTERVAL
	var rank := RaceManager.get_rank(_racer)
	if _last_rank > 0 and rank > 0 and rank != _last_rank:
		var hud := _find_hud()
		if hud != null and hud.has_method("show_rank_change"):
			hud.call("show_rank_change", _last_rank, rank)
	_last_rank = rank

func _on_held_item_changed(item_id: StringName) -> void:
	if item_id == &"":
		return
	var name := String(item_id).to_lower()
	notify_item_pickup("gold" in name or "golden" in name)

func _on_finished(rank: int) -> void:
	_emit_pulse(&"finish", Vector3(0.0, 1.15, 0.0), Color("ffe56a"), _effect_strength() * 1.35)
	if _premium_art != null:
		_premium_art.notify_visual_action(&"Finish")
	if _racer.is_player:
		var camera := get_viewport().get_camera_3d()
		if camera != null and camera.has_method("request_finish_pullback"):
			camera.call("request_finish_pullback", 1.6, 3.2)
		var director := get_tree().get_first_node_in_group("wilddash_round_vfx")
		if director != null and director.has_method("notify_player_finish"):
			director.call("notify_player_finish", _racer, rank)

func _effect_strength() -> float:
	if _racer == null:
		return 0.0
	if _racer.is_player:
		return PLAYER_STRENGTH
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return FAR_RIVAL_STRENGTH
	var distance := camera.global_position.distance_to(_racer.global_position)
	if distance <= NEAR_DISTANCE:
		return NEAR_RIVAL_STRENGTH
	return FAR_RIVAL_STRENGTH

func _build_pool() -> void:
	for i in range(FX_POOL_SIZE):
		var root := Node3D.new()
		root.name = "FeedbackPool_%02d" % i
		add_child(root)
		var mesh_node := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.44
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh_node.mesh = mesh
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1, 1, 1, 0)
		mesh_node.material_override = mat
		root.add_child(mesh_node)
		root.visible = false
		_fx_slots.append({"root": root, "mesh": mesh_node, "material": mat, "time": 0.0, "life": 0.24, "strength": 0.0, "kind": &""})

func _build_boost_visuals() -> void:
	var trail_mat := StandardMaterial3D.new()
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.albedo_color = Color(0.34, 0.91, 1.0, 0.48)
	trail_mat.emission_enabled = true
	trail_mat.emission = Color("55dfff") * 1.25
	for x in [-0.24, 0.24]:
		var trail := MeshInstance3D.new()
		trail.name = "BoostFootTrail"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.10, 0.07, 1.15)
		trail.mesh = mesh
		trail.material_override = trail_mat
		trail.position = Vector3(x, 0.18, 0.80)
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.visible = false
		add_child(trail)
		_boost_trails.append(trail)
	_glow_material = StandardMaterial3D.new()
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_material.albedo_color = Color(0.35, 0.88, 1.0, 0.13)
	_glow_material.emission_enabled = true
	_glow_material.emission = Color("55dfff") * 0.72
	_glow = MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.72
	glow_mesh.height = 1.44
	glow_mesh.radial_segments = 10
	glow_mesh.rings = 5
	_glow.mesh = glow_mesh
	_glow.material_override = _glow_material
	_glow.position = Vector3(0, 0.92, 0)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	add_child(_glow)

func _emit_pulse(kind: StringName, local_position: Vector3, color: Color, strength: float) -> void:
	if strength < 0.10 or _fx_slots.is_empty():
		return
	var index := _fx_cursor
	_fx_cursor = (_fx_cursor + 1) % _fx_slots.size()
	var slot: Dictionary = _fx_slots[index]
	var root: Node3D = slot["root"]
	var mat: StandardMaterial3D = slot["material"]
	root.position = local_position
	root.scale = Vector3.ONE * maxf(0.15, strength)
	root.visible = true
	mat.albedo_color = Color(color.r, color.g, color.b, clampf(color.a * 0.72, 0.12, 0.82))
	if kind in [&"boost", &"item", &"finish", &"spark"]:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b) * 1.15
	else:
		mat.emission_enabled = false
	slot["time"] = 0.0
	slot["life"] = 0.30 if kind in [&"finish", &"boost"] else 0.22
	slot["strength"] = strength
	slot["kind"] = kind
	_fx_slots[index] = slot
	var director := get_tree().get_first_node_in_group("wilddash_round_vfx")
	if director != null and director.has_method("accent_action"):
		director.call("accent_action", kind, _racer.global_position + local_position, strength)

func _update_pool(delta: float) -> void:
	for i in range(_fx_slots.size()):
		var slot: Dictionary = _fx_slots[i]
		var root: Node3D = slot["root"]
		if not root.visible:
			continue
		var time := float(slot["time"]) + delta
		var life := float(slot["life"])
		var t := clampf(time / maxf(0.01, life), 0.0, 1.0)
		var strength := float(slot["strength"])
		var kind: StringName = slot["kind"]
		if kind in [&"ring", &"landing", &"impact", &"wake", &"finish"]:
			root.scale = Vector3(1.0 + t * 2.2, 0.35 + t * 0.55, 1.0 + t * 2.2) * strength
		else:
			root.scale = Vector3.ONE * strength * (0.65 + t * 1.10)
		var mat: StandardMaterial3D = slot["material"]
		var c := mat.albedo_color
		c.a = (1.0 - t) * 0.62
		mat.albedo_color = c
		if t >= 1.0:
			root.visible = false
		slot["time"] = time
		_fx_slots[i] = slot

func _surface_from_label(label: String) -> StringName:
	if "water" in label or "river" in label or "pool" in label:
		return SURFACE_WATER
	if "wood" in label or "log" in label or "tree" in label or "root" in label or "bridge" in label:
		return SURFACE_WOOD
	if "metal" in label or "container" in label or "harbor" in label:
		return SURFACE_METAL
	if "sand" in label or "arena" in label:
		return SURFACE_SAND
	if "grass" in label or "forest" in label or "moss" in label:
		return SURFACE_GRASS
	return SURFACE_DIRT

func _surface_color(surface: StringName) -> Color:
	match surface:
		SURFACE_GRASS: return Color("96c96b")
		SURFACE_WOOD: return Color("c89057")
		SURFACE_SAND: return Color("e3bc73")
		SURFACE_WATER: return Color("6edcff")
		SURFACE_METAL: return Color("a9d7dc")
		_: return Color("c9976c")

func _landing_sfx(surface: StringName) -> String:
	if surface == SURFACE_WOOD:
		return "wood_land"
	if surface == SURFACE_WATER:
		return "splash"
	return "landing"

func _play_sfx(id: String, volume: float) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_sfx_id"):
		audio.call("play_sfx_id", id, volume)

func _request_camera_impulse(direction: Vector3, strength: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("add_game_feel_impulse"):
		camera.call("add_game_feel_impulse", direction, strength)

func _find_hud() -> Node:
	var parent := _racer.get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("ModeHUD")
