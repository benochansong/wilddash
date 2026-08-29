class_name WildDashBananaPeel
extends Area3D

var owner_racer: Node
var _armed: bool = false
var _life: float = 0.0
var _visual: Node3D

func _ready() -> void:
	add_to_group("wilddash_item_trap")
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	_build_visual()
	body_entered.connect(_on_body_entered)
	_arm_later()

func _process(delta: float) -> void:
	_life += delta
	if _visual != null:
		_visual.rotation.y += delta * 0.7
	if _life >= 16.0:
		queue_free()

func _arm_later() -> void:
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	_armed = true
	for body: Node3D in get_overlapping_bodies():
		_resolve_hit(body)
		if is_queued_for_deletion():
			return

func _on_body_entered(body: Node) -> void:
	if _armed:
		_resolve_hit(body)

func _resolve_hit(body: Node) -> void:
	if body == null or body == owner_racer or not body is WildDashCharacterController:
		return
	var victim: WildDashCharacterController = body as WildDashCharacterController
	var profile: WildDashRaceImpactProfile = WildDashRaceImpactProfile.banana_peel()
	var impact_origin: Vector3 = global_position
	if WildDashRaceCombatCoreV3.apply_race_impact(owner_racer, victim, &"banana_peel", profile, impact_origin):
		AudioManager.play_sfx_id("hit", 0.78)
		print("BANANA PEEL V3 HIT target=%s slip=%.2fs speed_loss=%.0f%% yaw=%.2f" % [
			RaceManager.get_racer_label(victim), profile.stagger_duration, profile.speed_loss_ratio * 100.0, profile.yaw_instability,
		])
		queue_free()

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.84, 0.08)
	material.roughness = 0.72
	material.emission_enabled = true
	material.emission = Color(0.42, 0.27, 0.01)
	material.emission_energy_multiplier = 0.55
	for i: int in range(3):
		var peel: MeshInstance3D = MeshInstance3D.new()
		var mesh: CapsuleMesh = CapsuleMesh.new()
		mesh.radius = 0.16
		mesh.height = 0.9
		peel.mesh = mesh
		peel.rotation_degrees = Vector3(0, float(i) * 120.0, 58.0)
		peel.position = Vector3(cos(float(i) * TAU / 3.0), 0.08, sin(float(i) * TAU / 3.0)) * 0.28
		peel.material_override = material
		_visual.add_child(peel)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.85
	collision.shape = shape
	add_child(collision)
