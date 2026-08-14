class_name WildDashGrandPrixV2LightObstacle
extends Area3D

## Lightweight Terrain Adventure obstacle.
## High-Power racers break through it, while lower-Power racers are slowed.
## Agility reduces the impact penalty so light racers can still take technical lines.

var obstacle_id: StringName = &"light_obstacle"
var impact_strength: float = 4.0
var base_speed_retention: float = 0.58
var breakable: bool = true
var _consumed: bool = false

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

	var collision := CollisionShape3D.new()
	collision.name = "GameplayTrigger"
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	add_child(collision)

	var visual := MeshInstance3D.new()
	visual.name = "ObstacleVisual"
	if shape_kind == &"rock":
		var rock := SphereMesh.new()
		rock.radius = 0.5
		rock.height = 1.0
		rock.radial_segments = 7
		rock.rings = 4
		visual.mesh = rock
		visual.scale = size
	else:
		var block := BoxMesh.new()
		block.size = size
		visual.mesh = block
	visual.material_override = material
	add_child(visual)

func _on_body_entered(body: Node3D) -> void:
	if _consumed or not body is WildDashCharacterController:
		return
	var racer: WildDashCharacterController = body as WildDashCharacterController
	var power: float = WildDashRaceTerrainProfile.get_power(racer.animal_id)
	var agility: float = WildDashRaceTerrainProfile.get_agility(racer.animal_id)

	if breakable and WildDashRaceTerrainProfile.can_break_light_obstacle(racer.animal_id):
		_consumed = true
		print("GRAND PRIX V2 OBSTACLE BREAK id=%s racer=%s animal=%s power=%.1f" % [
			String(obstacle_id), racer.name, String(racer.animal_id), power,
		])
		call_deferred("queue_free")
		return

	var agility_ratio: float = clampf(agility / 10.0, 0.0, 1.0)
	var retention_bonus: float = lerpf(0.0, 0.24, agility_ratio)
	var final_retention: float = clampf(base_speed_retention + retention_bonus, 0.35, 0.92)
	racer.current_speed *= final_retention

	var backward: Vector3 = racer.global_transform.basis.z
	backward.y = 0.0
	if backward.length_squared() > 0.001:
		backward = backward.normalized()
		var impact_scale: float = lerpf(1.0, 0.42, agility_ratio)
		racer.apply_knockback(backward, impact_strength * impact_scale)

	print("GRAND PRIX V2 OBSTACLE HIT id=%s racer=%s animal=%s power=%.1f agility=%.1f retention=%.2f" % [
		String(obstacle_id), racer.name, String(racer.animal_id), power, agility, final_retention,
	])
