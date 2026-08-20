class_name WildDashPremiumCharacterArt
extends Node3D

## Graphics Phase 2 visual-only character layer.
## It never changes CharacterBody collision, movement stats, skills or gameplay state.
## The layer adds stronger species silhouettes, sculpted fur accents, a lightweight
## expression rig and procedural secondary motion on top of the existing RC7 art.

const EXPRESSION_NEUTRAL: StringName = &"neutral"
const EXPRESSION_HAPPY: StringName = &"happy"
const EXPRESSION_JUMP: StringName = &"jump"
const EXPRESSION_SURPRISED: StringName = &"surprised"
const EXPRESSION_HIT: StringName = &"hit"
const EXPRESSION_ANGRY: StringName = &"angry"
const EXPRESSION_BOOST: StringName = &"boost"
const EXPRESSION_FALLING: StringName = &"falling"
const EXPRESSION_VICTORY: StringName = &"victory"

const ACTIVE_SPECIES: Array[StringName] = [
	&"dog", &"wolf", &"boar", &"rabbit", &"deer", &"monkey",
	&"elephant", &"bear", &"crocodile", &"cat", &"fox", &"raccoon",
]

var _racer: CharacterBody3D
var _art_root: Node3D
var _face_root: Node3D
var _species: StringName = &""
var _expression: StringName = EXPRESSION_NEUTRAL
var _forced_expression: StringName = &""
var _forced_expression_time: float = 0.0
var _blink_timer: float = 2.4
var _blink_phase: float = 0.0
var _motion_time: float = 0.0

var _lid_l: Node3D
var _lid_r: Node3D
var _brow_l: Node3D
var _brow_r: Node3D
var _mouth_l: Node3D
var _mouth_r: Node3D
var _face_base: Dictionary = {}
var _secondary_nodes: Array[Node3D] = []
var _secondary_base: Dictionary = {}

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_racer = get_parent() as CharacterBody3D
	if _racer == null:
		set_process(false)
		return
	_rebuild_if_needed(true)

func _process(delta: float) -> void:
	if _racer == null or not is_instance_valid(_racer):
		return
	_rebuild_if_needed(false)
	_motion_time += delta
	_update_expression_state(delta)
	_update_blink(delta)
	_update_face_pose(delta)
	_update_secondary_motion(delta)

func set_expression(expression_id: StringName, duration: float = 0.55) -> void:
	if not expression_id in [
		EXPRESSION_NEUTRAL, EXPRESSION_HAPPY, EXPRESSION_JUMP,
		EXPRESSION_SURPRISED, EXPRESSION_HIT, EXPRESSION_ANGRY,
		EXPRESSION_BOOST, EXPRESSION_FALLING, EXPRESSION_VICTORY,
	]:
		return
	_forced_expression = expression_id
	_forced_expression_time = maxf(0.0, duration)
	_expression = expression_id

func notify_visual_action(action_id: StringName) -> void:
	match action_id:
		&"Jump": set_expression(EXPRESSION_JUMP, 0.42)
		&"Hit", &"Bump": set_expression(EXPRESSION_HIT, 0.48)
		&"Finish", &"Win": set_expression(EXPRESSION_VICTORY, 1.6)
		&"Skill": set_expression(EXPRESSION_ANGRY, 0.58)
		&"Boost": set_expression(EXPRESSION_BOOST, 0.75)
		_: pass

func _rebuild_if_needed(force: bool) -> void:
	var next_species := StringName(_racer.get("animal_id"))
	if next_species == &"" or not ACTIVE_SPECIES.has(next_species):
		next_species = &"dog"
	if not force and next_species == _species and _art_root != null:
		return
	_species = next_species
	if _art_root != null and is_instance_valid(_art_root):
		_art_root.queue_free()
	_secondary_nodes.clear()
	_secondary_base.clear()
	_face_base.clear()
	_art_root = Node3D.new()
	_art_root.name = "GraphicsPhase2PremiumArt"
	add_child(_art_root)
	_build_species_identity()
	_build_expression_rig()
	print("GRAPHICS PHASE 2 CHARACTER READY species=%s silhouette=premium face_states=9 blink=true fur_tufts=true secondary_motion=procedural collision_changed=false stats_changed=false" % String(_species))

func _build_species_identity() -> void:
	var accent := _accent_color()
	var fur := _fur_color()
	var light := fur.lightened(0.28)
	var dark := fur.darkened(0.42)
	match _species:
		&"rabbit":
			_add_capsule("HeroEarL", Vector3(-0.22, 1.86, -0.56), Vector3(0.14, 0.56, 0.13), fur, Vector3(0.04, 0.0, -0.08), &"ear")
			_add_capsule("HeroEarR", Vector3(0.22, 1.86, -0.56), Vector3(0.14, 0.56, 0.13), fur, Vector3(0.04, 0.0, 0.08), &"ear")
			_add_ellipsoid("SpringFootL", Vector3(-0.30, 0.16, 0.42), Vector3(0.20, 0.10, 0.31), light)
			_add_ellipsoid("SpringFootR", Vector3(0.30, 0.16, 0.42), Vector3(0.20, 0.10, 0.31), light)
			_add_fur_cluster(Vector3(0.0, 1.26, -0.80), Vector3(0.18, 0.18, 0.12), light, &"head_tuft")
			_add_fur_cluster(Vector3(0.0, 0.86, -0.45), Vector3(0.22, 0.21, 0.13), light, &"chest_tuft")
		&"elephant":
			_add_ellipsoid("HeroEarL", Vector3(-0.66, 1.43, -0.62), Vector3(0.18, 0.43, 0.36), fur, &"ear")
			_add_ellipsoid("HeroEarR", Vector3(0.66, 1.43, -0.62), Vector3(0.18, 0.43, 0.36), fur, &"ear")
			_add_ellipsoid("HeavyShoulderL", Vector3(-0.48, 1.04, -0.05), Vector3(0.25, 0.34, 0.28), fur)
			_add_ellipsoid("HeavyShoulderR", Vector3(0.48, 1.04, -0.05), Vector3(0.25, 0.34, 0.28), fur)
			for x in [-0.46, 0.46]:
				_add_ellipsoid("HeroFoot", Vector3(x, 0.18, -0.38), Vector3(0.25, 0.13, 0.25), light, &"belly")
			_add_capsule("TrunkSculpt", Vector3(0.0, 0.98, -1.34), Vector3(0.13, 0.45, 0.13), fur, Vector3(0.18, 0.0, 0.0), &"head_tuft")
		&"bear":
			_add_ellipsoid("HeroShoulderL", Vector3(-0.48, 1.03, -0.02), Vector3(0.30, 0.36, 0.30), fur)
			_add_ellipsoid("HeroShoulderR", Vector3(0.48, 1.03, -0.02), Vector3(0.30, 0.36, 0.30), fur)
			_add_ellipsoid("HeroPawL", Vector3(-0.38, 0.22, -0.48), Vector3(0.22, 0.14, 0.25), dark)
			_add_ellipsoid("HeroPawR", Vector3(0.38, 0.22, -0.48), Vector3(0.22, 0.14, 0.25), dark)
			_add_fur_cluster(Vector3(0.0, 0.93, -0.53), Vector3(0.30, 0.26, 0.15), light, &"chest_tuft")
		&"crocodile":
			for i in range(6):
				_add_cone("DorsalScute", Vector3(0.0, 1.26 - float(i) * 0.05, -0.15 + float(i) * 0.42), Vector3(0.14, 0.22, 0.14), dark, Vector3.ZERO, &"tail")
			_add_capsule("PowerTailA", Vector3(0.0, 0.66, 1.42), Vector3(0.34, 0.70, 0.34), fur, Vector3(PI * 0.5, 0.0, 0.0), &"tail")
			_add_cone("PowerTailTip", Vector3(0.0, 0.61, 2.35), Vector3(0.28, 0.72, 0.28), fur, Vector3(-PI * 0.5, 0.0, 0.0), &"tail")
			_add_box("JawAccent", Vector3(0.0, 0.77, -1.56), Vector3(0.74, 0.16, 0.50), light)
		&"monkey":
			_add_capsule("LongArmL", Vector3(-0.43, 0.86, -0.24), Vector3(0.13, 0.58, 0.13), fur, Vector3(0.16, 0.0, -0.12), &"ear")
			_add_capsule("LongArmR", Vector3(0.43, 0.86, -0.24), Vector3(0.13, 0.58, 0.13), fur, Vector3(0.16, 0.0, 0.12), &"ear")
			_add_ellipsoid("ExpressiveHandL", Vector3(-0.48, 0.34, -0.35), Vector3(0.17, 0.13, 0.16), light)
			_add_ellipsoid("ExpressiveHandR", Vector3(0.48, 0.34, -0.35), Vector3(0.17, 0.13, 0.16), light)
			_add_fur_cluster(Vector3(0.0, 1.34, -0.75), Vector3(0.20, 0.17, 0.11), dark, &"head_tuft")
		&"fox":
			_add_capsule("HeroTail", Vector3(0.22, 1.10, 1.28), Vector3(0.28, 0.82, 0.30), fur, Vector3(PI * 0.42, 0.0, -0.18), &"tail")
			_add_ellipsoid("TailCreamTip", Vector3(0.34, 1.42, 1.76), Vector3(0.28, 0.31, 0.28), light, &"tail")
			_add_fur_cluster(Vector3(-0.30, 1.14, -0.89), Vector3(0.17, 0.18, 0.12), light, &"head_tuft")
			_add_fur_cluster(Vector3(0.30, 1.14, -0.89), Vector3(0.17, 0.18, 0.12), light, &"head_tuft")
			_add_fur_cluster(Vector3(0.0, 0.87, -0.49), Vector3(0.24, 0.24, 0.14), light, &"chest_tuft")
		&"deer":
			for side in [-1.0, 1.0]:
				_add_capsule("AntlerStem", Vector3(side * 0.28, 1.78, -0.56), Vector3(0.055, 0.38, 0.055), dark, Vector3(-0.12, 0.0, side * 0.22), &"ear")
				_add_capsule("AntlerBranch", Vector3(side * 0.38, 1.95, -0.57), Vector3(0.045, 0.22, 0.045), dark, Vector3(0.18, 0.0, side * 0.62), &"ear")
			_add_fur_cluster(Vector3(0.0, 0.91, -0.48), Vector3(0.23, 0.25, 0.14), light, &"chest_tuft")
		&"wolf":
			_add_fur_cluster(Vector3(0.0, 0.98, -0.46), Vector3(0.32, 0.30, 0.17), light, &"chest_tuft")
			_add_fur_cluster(Vector3(-0.31, 1.19, -0.82), Vector3(0.15, 0.18, 0.11), light, &"head_tuft")
			_add_fur_cluster(Vector3(0.31, 1.19, -0.82), Vector3(0.15, 0.18, 0.11), light, &"head_tuft")
			_add_capsule("PackTail", Vector3(0.12, 1.08, 1.26), Vector3(0.22, 0.64, 0.23), dark, Vector3(PI * 0.40, 0.0, -0.10), &"tail")
		&"boar":
			for x in [-0.23, 0.23]:
				_add_cone("HeroTusk", Vector3(x, 0.92, -1.10), Vector3(0.065, 0.20, 0.065), light, Vector3(PI, 0.0, 0.0))
			for i in range(4):
				_add_cone("BackMohawk", Vector3(0.0, 1.42, -0.44 + float(i) * 0.24), Vector3(0.10, 0.22, 0.10), dark, Vector3.ZERO, &"head_tuft")
			_add_ellipsoid("PowerShoulderL", Vector3(-0.43, 0.97, -0.07), Vector3(0.24, 0.31, 0.27), fur)
			_add_ellipsoid("PowerShoulderR", Vector3(0.43, 0.97, -0.07), Vector3(0.24, 0.31, 0.27), fur)
		&"raccoon":
			_add_ellipsoid("MaskL", Vector3(-0.20, 1.22, -0.94), Vector3(0.19, 0.10, 0.035), dark)
			_add_ellipsoid("MaskR", Vector3(0.20, 1.22, -0.94), Vector3(0.19, 0.10, 0.035), dark)
			_add_capsule("BanditTail", Vector3(0.16, 1.08, 1.24), Vector3(0.24, 0.68, 0.24), fur, Vector3(PI * 0.42, 0.0, -0.10), &"tail")
			for i in range(3):
				_add_torus("TailRing", Vector3(0.14, 1.06 + float(i) * 0.12, 1.18 + float(i) * 0.18), Vector3(0.18, 0.05, 0.18), dark, &"tail")
			_add_fur_cluster(Vector3(-0.29, 1.13, -0.88), Vector3(0.15, 0.16, 0.10), light, &"head_tuft")
			_add_fur_cluster(Vector3(0.29, 1.13, -0.88), Vector3(0.15, 0.16, 0.10), light, &"head_tuft")
		&"cat":
			_add_capsule("ElegantTail", Vector3(0.24, 1.22, 1.27), Vector3(0.16, 0.72, 0.17), fur, Vector3(PI * 0.42, 0.0, -0.16), &"tail")
			_add_fur_cluster(Vector3(-0.27, 1.12, -0.86), Vector3(0.13, 0.16, 0.09), light, &"head_tuft")
			_add_fur_cluster(Vector3(0.27, 1.12, -0.86), Vector3(0.13, 0.16, 0.09), light, &"head_tuft")
			_add_fur_cluster(Vector3(0.0, 0.80, -0.43), Vector3(0.20, 0.20, 0.11), light, &"chest_tuft")
		_:
			_add_fur_cluster(Vector3(0.0, 1.28, -0.94), Vector3(0.18, 0.17, 0.11), light, &"head_tuft")
			_add_fur_cluster(Vector3(0.0, 0.90, -0.47), Vector3(0.23, 0.23, 0.13), light, &"chest_tuft")
			_add_capsule("MascotTail", Vector3(0.16, 1.14, 1.20), Vector3(0.19, 0.60, 0.20), fur, Vector3(PI * 0.42, 0.0, -0.12), &"tail")
	_add_ellipsoid("RaceAccent", Vector3(0.0, 1.02, -0.58), Vector3(0.10, 0.08, 0.035), accent)

func _build_expression_rig() -> void:
	_face_root = Node3D.new()
	_face_root.name = "ExpressionRig"
	_art_root.add_child(_face_root)
	var anchor := _face_anchor()
	var face_skin := _fur_color().lightened(0.10)
	var ink := _material(Color(0.08, 0.07, 0.09), 0.78)
	var lid_material := _material(face_skin, 0.82)
	_lid_l = _add_face_box("LidL", anchor + Vector3(-0.18, 0.08, -0.055), Vector3(0.18, 0.025, 0.035), lid_material)
	_lid_r = _add_face_box("LidR", anchor + Vector3(0.18, 0.08, -0.055), Vector3(0.18, 0.025, 0.035), lid_material)
	_brow_l = _add_face_box("BrowL", anchor + Vector3(-0.18, 0.19, -0.07), Vector3(0.17, 0.035, 0.035), ink)
	_brow_r = _add_face_box("BrowR", anchor + Vector3(0.18, 0.19, -0.07), Vector3(0.17, 0.035, 0.035), ink)
	_mouth_l = _add_face_box("MouthL", anchor + Vector3(-0.065, -0.17, -0.075), Vector3(0.14, 0.025, 0.025), ink)
	_mouth_r = _add_face_box("MouthR", anchor + Vector3(0.065, -0.17, -0.075), Vector3(0.14, 0.025, 0.025), ink)
	for node in [_lid_l, _lid_r, _brow_l, _brow_r, _mouth_l, _mouth_r]:
		_face_base[node.get_instance_id()] = node.transform
	_lid_l.scale.y = 0.08
	_lid_r.scale.y = 0.08

func _update_expression_state(delta: float) -> void:
	if _forced_expression_time > 0.0:
		_forced_expression_time = maxf(0.0, _forced_expression_time - delta)
		_expression = _forced_expression
		return
	_forced_expression = &""
	var finished: bool = bool(_racer.get("finished"))
	if finished:
		_expression = EXPRESSION_VICTORY
		return
	if _racer.has_method("get_knockback_velocity"):
		var knockback_value: Variant = _racer.call("get_knockback_velocity")
		if knockback_value is Vector3 and (knockback_value as Vector3).length() > 3.4:
			_expression = EXPRESSION_HIT
			return
	if not _racer.is_on_floor():
		_expression = EXPRESSION_FALLING if _racer.velocity.y < -1.7 else EXPRESSION_JUMP
		return
	var current_speed: float = float(_racer.get("current_speed"))
	var max_speed: float = maxf(1.0, float(_racer.get("max_speed")))
	_expression = EXPRESSION_BOOST if current_speed > max_speed * 0.98 else EXPRESSION_NEUTRAL

func _update_blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0 and _blink_phase <= 0.0:
		_blink_phase = 0.16
		_blink_timer = 2.4 + float((_racer.get_instance_id() + int(_motion_time * 10.0)) % 19) * 0.09
	if _blink_phase > 0.0:
		_blink_phase = maxf(0.0, _blink_phase - delta)

func _update_face_pose(delta: float) -> void:
	if _brow_l == null:
		return
	var response := clampf(delta * 14.0, 0.0, 1.0)
	var brow_angle: float = 0.0
	var brow_y: float = 0.0
	var mouth_angle: float = 0.0
	var mouth_y: float = 0.0
	match _expression:
		EXPRESSION_HAPPY, EXPRESSION_VICTORY:
			brow_y = 0.035
			mouth_angle = 0.28
		EXPRESSION_JUMP:
			brow_y = 0.055
			mouth_y = -0.015
		EXPRESSION_SURPRISED, EXPRESSION_FALLING:
			brow_y = 0.075
			mouth_angle = -0.08
			mouth_y = -0.035
		EXPRESSION_HIT:
			brow_angle = 0.30
			mouth_angle = -0.32
		EXPRESSION_ANGRY:
			brow_angle = -0.34
			mouth_angle = -0.20
		EXPRESSION_BOOST:
			brow_angle = -0.20
			mouth_angle = 0.18
		_: pass
	_apply_face_transform(_brow_l, Vector3(0.0, brow_y, 0.0), Vector3(0.0, 0.0, brow_angle), response)
	_apply_face_transform(_brow_r, Vector3(0.0, brow_y, 0.0), Vector3(0.0, 0.0, -brow_angle), response)
	_apply_face_transform(_mouth_l, Vector3(0.0, mouth_y, 0.0), Vector3(0.0, 0.0, -mouth_angle), response)
	_apply_face_transform(_mouth_r, Vector3(0.0, mouth_y, 0.0), Vector3(0.0, 0.0, mouth_angle), response)
	var closed: bool = _blink_phase > 0.0
	var lid_scale: float = 1.0 if closed else 0.08
	_lid_l.scale.y = lerpf(_lid_l.scale.y, lid_scale, response)
	_lid_r.scale.y = lerpf(_lid_r.scale.y, lid_scale, response)

func _apply_face_transform(node: Node3D, offset: Vector3, rotation_offset: Vector3, response: float) -> void:
	var base_value: Variant = _face_base.get(node.get_instance_id(), node.transform)
	var base: Transform3D = base_value if base_value is Transform3D else node.transform
	var target_position := base.origin + offset
	node.position = node.position.lerp(target_position, response)
	var target_rotation := base.basis.get_euler() + rotation_offset
	node.rotation = node.rotation.lerp(target_rotation, response)

func _update_secondary_motion(delta: float) -> void:
	if _secondary_nodes.is_empty():
		return
	var speed: float = clampf(float(_racer.get("current_speed")) / maxf(1.0, float(_racer.get("max_speed"))), 0.0, 1.4)
	var airborne: float = 1.0 if not _racer.is_on_floor() else 0.0
	for node: Node3D in _secondary_nodes:
		if node == null or not is_instance_valid(node):
			continue
		var base_value: Variant = _secondary_base.get(node.get_instance_id(), node.transform)
		if not (base_value is Transform3D):
			continue
		var base: Transform3D = base_value
		var role: StringName = StringName(node.get_meta("secondary_role", &""))
		var target_rotation := base.basis.get_euler()
		var target_position := base.origin
		var wave := sin(_motion_time * (7.0 + speed * 3.0) + float(node.get_instance_id() % 13) * 0.31)
		match role:
			&"ear":
				target_rotation.x += wave * (0.035 + speed * 0.075) - airborne * 0.045
			&"tail":
				target_rotation.z += wave * (0.045 + speed * 0.10)
			&"head_tuft":
				target_rotation.x += wave * (0.025 + speed * 0.055)
			&"chest_tuft":
				target_position.y += wave * (0.008 + speed * 0.018)
			&"belly":
				target_position.y += absf(wave) * speed * 0.012
			_: continue
		var response := clampf(delta * 10.0, 0.0, 1.0)
		node.position = node.position.lerp(target_position, response)
		node.rotation = node.rotation.lerp(target_rotation, response)

func _face_anchor() -> Vector3:
	match _species:
		&"elephant": return Vector3(0.0, 1.45, -1.24)
		&"crocodile": return Vector3(0.0, 0.98, -1.47)
		&"rabbit": return Vector3(0.0, 1.18, -0.88)
		&"monkey": return Vector3(0.0, 1.20, -0.88)
		&"boar": return Vector3(0.0, 1.18, -1.00)
		&"bear": return Vector3(0.0, 1.28, -0.93)
		&"deer": return Vector3(0.0, 1.28, -0.91)
		_: return Vector3(0.0, 1.22, -0.92)

func _accent_color() -> Color:
	var definition := WildDashAnimalCatalog.get_definition(_species)
	if definition != null:
		return definition.accent_color
	return Color(0.18, 0.78, 0.78)

func _fur_color() -> Color:
	match _species:
		&"rabbit": return Color(0.92, 0.72, 0.82)
		&"elephant": return Color(0.44, 0.50, 0.70)
		&"bear": return Color(0.43, 0.28, 0.19)
		&"crocodile": return Color(0.34, 0.49, 0.23)
		&"monkey": return Color(0.43, 0.28, 0.18)
		&"fox": return Color(0.88, 0.38, 0.13)
		&"deer": return Color(0.55, 0.36, 0.19)
		&"wolf": return Color(0.35, 0.39, 0.43)
		&"boar": return Color(0.43, 0.27, 0.25)
		&"raccoon": return Color(0.42, 0.45, 0.48)
		&"cat": return Color(0.43, 0.29, 0.62)
		_: return Color(0.76, 0.36, 0.14)

func _material(color: Color, roughness: float = 0.78) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	return material

func _add_ellipsoid(node_name: String, position: Vector3, scale_value: Vector3, color_or_material: Variant, role: StringName = &"") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 7
	mesh.material = color_or_material if color_or_material is Material else _material(color_or_material)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.scale = scale_value * 2.0
	_art_root.add_child(node)
	_register_secondary(node, role)
	return node

func _add_capsule(node_name: String, position: Vector3, scale_value: Vector3, color: Color, rotation_value: Vector3 = Vector3.ZERO, role: StringName = &"") -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 4
	mesh.material = _material(color)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.rotation = rotation_value
	node.scale = scale_value * 2.0
	_art_root.add_child(node)
	_register_secondary(node, role)
	return node

func _add_cone(node_name: String, position: Vector3, scale_value: Vector3, color: Color, rotation_value: Vector3 = Vector3.ZERO, role: StringName = &"") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.material = _material(color)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.rotation = rotation_value
	node.scale = scale_value * 2.0
	_art_root.add_child(node)
	_register_secondary(node, role)
	return node

func _add_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	_art_root.add_child(node)
	return node

func _add_torus(node_name: String, position: Vector3, scale_value: Vector3, color: Color, role: StringName = &"") -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.37
	mesh.outer_radius = 0.50
	mesh.rings = 10
	mesh.ring_segments = 7
	mesh.material = _material(color)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.scale = scale_value
	node.rotation.x = PI * 0.5
	_art_root.add_child(node)
	_register_secondary(node, role)
	return node

func _add_fur_cluster(position: Vector3, scale_value: Vector3, color: Color, role: StringName) -> void:
	for i in range(3):
		var spread := float(i - 1) * scale_value.x * 0.62
		var node := _add_cone(
			"SculptedFurTuft",
			position + Vector3(spread, float(i % 2) * scale_value.y * 0.12, 0.0),
			Vector3(scale_value.x * 0.46, scale_value.y, scale_value.z * 0.62),
			color,
			Vector3(PI, 0.0, float(i - 1) * 0.18),
			role
		)
		node.visibility_range_end = 34.0

func _add_face_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	_face_root.add_child(node)
	return node

func _register_secondary(node: Node3D, role: StringName) -> void:
	if role == &"":
		return
	node.set_meta("secondary_role", role)
	_secondary_nodes.append(node)
	_secondary_base[node.get_instance_id()] = node.transform
