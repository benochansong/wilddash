extends "res://modes/logspire_leap/logspire_world_v2_deep_water.gd"

## Final-zone recovery no longer uses a giant solid deck.
##
## Recovery_Z6 used to create a 90x180m StaticBody at y=47. That slab overlaps
## the late Titan spiral and was proven by the production JumpCollisionAudit to
## block Z5_SPIRAL_05..09 with `Collision<-Recovery_Z6_Deck`.
##
## Keep the broad Area3D trigger so checkpoint/fall recovery semantics remain
## available, but remove only the obsolete physical/visible Z6 deck. Earlier
## zones retain their existing recovery decks unchanged.

const FINAL_RECOVERY_CENTER := Vector3(0.0, 47.0, -720.0)
const FINAL_RECOVERY_SIZE := Vector3(90.0, 0.6, 180.0)

func _build_recovery_decks() -> void:
	_create_recovery_deck("Recovery_Z2", Vector3(0.0, -2.0, -165.0), Vector3(70.0, 0.6, 125.0), _checkpoint_ids[0])
	_create_recovery_deck("Recovery_Z3", Vector3(0.0, 7.5, -290.0), Vector3(80.0, 0.6, 135.0), _checkpoint_ids[1])
	_create_recovery_deck("Recovery_Z4", Vector3(0.0, 14.5, -440.0), Vector3(100.0, 0.6, 190.0), _checkpoint_ids[2])
	_create_recovery_deck("Recovery_Z5", Vector3(0.0, 22.0, -585.0), Vector3(90.0, 0.6, 115.0), _checkpoint_ids[3])
	_create_trigger_only_recovery("Recovery_Z6", FINAL_RECOVERY_CENTER, FINAL_RECOVERY_SIZE, _checkpoint_ids[4])
	print("LOGSPIRE FINAL RECOVERY TRIGGER READY zone=6 solid_deck=false trigger_only=true size=%.0fx%.0f stale_route_collision=false" % [
		FINAL_RECOVERY_SIZE.x,
		FINAL_RECOVERY_SIZE.z,
	])

func _create_trigger_only_recovery(name_text: String, top_position: Vector3, size: Vector3, target_id: StringName) -> void:
	var area := Area3D.new()
	area.name = name_text
	area.position = top_position + Vector3.UP * 1.2
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	area.set_meta(&"logspire_recovery_target", target_id)
	area.add_to_group("logspire_trigger_only_recovery")

	var collision := CollisionShape3D.new()
	collision.name = "Trigger"
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 2.2, size.z)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	_recovery_areas.append(area)
