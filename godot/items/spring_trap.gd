class_name WildDashSpringTrap
extends Area3D

const LIFE_SECONDS: float = 10.0
const LAUNCH_SCALE: float = 0.92
const ROUND1_LAUNCH_MULTIPLIER: float = 1.06
const ROUND1_RETENTION_PENALTY: float = 0.04

var owner_racer: WildDashCharacterController
var _life: float = LIFE_SECONDS

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 1.00
	shape.height = 0.45
	collision.shape = shape
	add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.90
	mesh.bottom_radius = 1.10
	mesh.height = 0.22
	mesh.radial_segments = 10
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.18, 0.23)
	material.metallic = 0.35
	material.roughness = 0.42
	material.emission_enabled = true
	material.emission = Color(0.28, 0.02, 0.03)
	material.emission_energy_multiplier = 1.1
	visual.material_override = material
	add_child(visual)

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == owner_racer or not body is WildDashCharacterController:
		return
	var racer: WildDashCharacterController = body as WildDashCharacterController
	var round1_scoped: bool = RaceManager.active and GameManager.get_current_round_id() == &"grand_prix" and ItemSystem.has_method("get_round1_chain_scale")
	var chain_scale: float = 1.0
	if round1_scoped:
		chain_scale = clampf(float(ItemSystem.call("get_round1_chain_scale", racer)), 0.25, 1.0)
		var shielded_before: bool = ItemSystem.has_shield(racer)
		var registered: bool = ItemSystem.apply_attack(racer, owner_racer, &"spring_trap", 0.20, 0.96, 0.0)
		if not registered:
			queue_free()
			return
		if shielded_before:
			queue_free()
			return
	elif ItemSystem.has_shield(racer):
		ItemSystem.apply_attack(racer, owner_racer, &"spring_trap", 0.0, 1.0, 0.0)
		queue_free()
		return

	var defense: float = WildDashRaceCombatBalance.get_defense_rating(racer.animal_id)
	var launch_multiplier: float = WildDashRaceCombatBalance.get_trap_launch_multiplier(racer.animal_id)
	var disruption: float = WildDashRaceCombatBalance.get_item_disruption_multiplier(racer.animal_id)
	var launch_velocity: float = racer.jump_velocity * LAUNCH_SCALE * launch_multiplier
	var speed_retention: float = clampf(0.80 + (1.0 - disruption) * 0.20, 0.80, 0.94)
	if round1_scoped:
		launch_velocity *= ROUND1_LAUNCH_MULTIPLIER * chain_scale
		var first_hit_retention: float = maxf(0.76, speed_retention - ROUND1_RETENTION_PENALTY)
		speed_retention = 1.0 - (1.0 - first_hit_retention) * chain_scale
	racer.velocity.y = maxf(racer.velocity.y, launch_velocity)
	racer.current_speed *= speed_retention
	AudioManager.play_sfx_id("hit", 0.72)
	print("SPRING TRAP POWER target=%s defense=%.1f launch=%.2f retention=%.2f chain_protection=%.2f" % [
		RaceManager.get_racer_label(racer), defense, launch_velocity, speed_retention, chain_scale,
	])
	queue_free()
