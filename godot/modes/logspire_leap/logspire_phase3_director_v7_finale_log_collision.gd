extends "res://modes/logspire_leap/logspire_phase3_director_v6_titan_tree_safe.gd"

## Round 3 Sky Log Finale safety override.
##
## The large rolling cylinder on Z6_01 repeatedly allowed the player visual/body
## to become embedded during real interactive play even after adding a matching
## physical cylinder and a penetration guard. The obstacle is not required for
## progression, and the rest of the finale already contains mushroom, moving
## branch, falling-tree and final-jump gameplay.
##
## Production therefore removes this one rolling-log obstacle completely. We
## intentionally create no mesh, no physics body, no collision shape and no push
## Area3D. The inherited finale update is null-safe, so all other finale systems
## continue to run unchanged.

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	print("LOGSPIRE FINALE ROLLING LOG REMOVED z6_01=true mesh=false collision=false influence=false penetration_risk=false other_finale_gameplay=true")

func _build_finale_rolling_log() -> void:
	_finale_roll_visual = null
	_finale_roll_area = null
	_finale_roll_right = Vector3.RIGHT
