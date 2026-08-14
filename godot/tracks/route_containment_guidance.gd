extends Node3D

## RETIRED IN GRAND PRIX V2.9.
##
## This legacy RC5/RC7 helper used to append long metal beams, upper/lower
## guardrails, posts and warning reflectors to the 29-segment Grand Prix track.
## Round 1 now uses natural terrain boundaries and invisible safety collision,
## so this visual-only containment layer must never render.
##
## The file remains as a compatibility stub because older scenes/branches may
## still reference its resource path. Keeping the stub prevents missing-resource
## errors while guaranteeing zero visible rail geometry.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false
	print("GRAND PRIX V2.9 LEGACY ROUTE CONTAINMENT DISABLED visual_rails=0 collision_impact=none")

func _build_route_containment() -> void:
	# Compatibility no-op. Do not restore visual beams/posts here.
	return
