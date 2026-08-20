class_name WildDashStickyFruitTrap
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
		_visual.rotation.y += delta * 1.1
		_visual.rotation.z = sin(_life * 3.0) * 0.12
	if _life >= 14.0:
		queue_free()

func _arm_later() -> void:
	await get_tree().create_timer(0.35).timeout
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
	var profile: WildDashRaceImpactProfile = WildDashRaceImpactProfile.sticky_fruit()
	if WildDashRaceCombatCoreV3.apply_race_impact(owner_racer, victim, &"sticky_fruit", profile, global_position):
		AudioManager.play_sfx_id("hit", 0.70)
		print("STICKY FRUIT V3 HIT target=%s duration=%.2f speed=%.2f accel=%.2f handling=%.2f" % [
			RaceManager.get_racer_label(victim), profile.slow_duration, profile.slow_multiplier,
			profile.acceleration_multiplier, profile.handling_multiplier,
		])
		queue_free()

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.72
	mesh.height = 1.05
	mesh_instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.16, 0.42)
	material.roughness = 0.7
	material.emission_enabled = true
	material.emission = Color(0.30, 0.02, 0.16)
	material.emission_energy_multiplier = 0.65
	mesh_instance.material_override = material
	_visual.add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.9
	collision.shape = shape
	add_child(collision)
