class_name WildDashGrandPrixV2LightObstacle
extends Area3D

## Lightweight Terrain Adventure obstacle.
## Power determines whether racers break through, push through, or should avoid it.
## Agility and Defense reduce the penalty, and a short protection window prevents
## repeated overlap hits from turning a single obstacle into a stun-lock.

const HIT_PROTECTION_MSEC: int = 720

var obstacle_id: StringName = &"light_obstacle"
var impact_strength: float = 4.0
var base_speed_retention: float = 0.58
var breakable: bool = true
var _consumed: bool = false
var _hit_until_by_racer: Dictionary = {}

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)

func configure(
	id: StringName,
	size: Vector3,
	material: Material,
	strength: float = 4.0,
	retention: float = 0.58,
	can_break: bool = true,
	shape_kind: StringName = &"rock"
) -> void:
	obstacle_id = id
	impact_strength = maxf(0.0, strength)
	base_speed_retention = clampf(retention, 0.25, 0.95)
	breakable = can_break

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "GameplayTrigger"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collision.shape = box
	add_child(collision)

	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "ObstacleVisual"
	if shape_kind == &"rock":
		var rock: SphereMesh = SphereMesh.new()
		rock.radius = 0.5
		rock.height = 1.0
		rock.radial_segments = 7
		rock.rings = 4
		visual.mesh = rock
		visual.scale = size
	else:
		var block: BoxMesh = BoxMesh.new()
		block.size = size
		visual.mesh = block
	visual.material_override = material
	add_child(visual)

func _on_body_entered(body: Node3D) -> void:
	if _consumed or not body is WildDashCharacterController:
		return
	var racer: WildDashCharacterController = body as WildDashCharacterController
	var racer_key: int = racer.get_instance_id()
	var now: int = Time.get_ticks_msec()
	if now < int(_hit_until_by_racer.get(racer_key, 0)):
		return
	_hit_until_by_racer[racer_key] = now + HIT_PROTECTION_MSEC

	var power: float = WildDashRaceTerrainProfile.get_power(racer.animal_id)
	var agility: float = WildDashRaceTerrainProfile.get_agility(racer.animal_id)
	var defense: float = WildDashRaceCombatBalance.get_defense_rating(racer.animal_id)

	if breakable and WildDashRaceTerrainProfile.can_break_light_obstacle(racer.animal_id):
		_consumed = true
		racer.current_speed = maxf(racer.current_speed, racer.max_speed * 0.72)
		print("GRAND PRIX V2 OBSTACLE BREAK id=%s racer=%s animal=%s power=%.1f defense=%.1f" % [
			String(obstacle_id), racer.name, String(racer.animal_id), power, defense,
		])
		call_deferred("queue_free")
		return

	var agility_ratio: float = clampf(agility / 10.0, 0.0, 1.0)
	var defense_ratio: float = clampf(defense / 10.0, 0.0, 1.0)
	var power_ratio: float = clampf(power / 10.0, 0.0, 1.0)
	var medium_power_bonus: float = 0.12 if power >= 6.0 else 0.0
	var retention_bonus: float = agility_ratio * 0.16 + defense_ratio * 0.08 + medium_power_bonus
	var final_retention: float = clampf(base_speed_retention + retention_bonus, 0.35, 0.94)
	racer.current_speed *= final_retention

	var backward: Vector3 = racer.global_transform.basis.z
	backward.y = 0.0
	if backward.length_squared() > 0.001:
		backward = backward.normalized()
		var impact_protection: float = clampf(agility_ratio * 0.38 + defense_ratio * 0.34 + power_ratio * 0.14, 0.0, 0.76)
		var final_strength: float = impact_strength * lerpf(1.0, 0.46, impact_protection)
		racer.apply_knockback(backward, final_strength)

	print("GRAND PRIX V2 OBSTACLE HIT id=%s racer=%s animal=%s power=%.1f agility=%.1f defense=%.1f retention=%.2f protection_ms=%d" % [
		String(obstacle_id), racer.name, String(racer.animal_id), power, agility, defense, final_retention, HIT_PROTECTION_MSEC,
	])
