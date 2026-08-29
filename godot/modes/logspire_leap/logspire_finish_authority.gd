extends Node

## Round 3 Crown Nest finish authority.
## The shared RaceManager uses a crossing plane beyond the final route point.
## Logspire instead ends on a broad destination platform, and Vine Rescue can
## legitimately leave a racer with only the final Z6_START checkpoint pending.
## Entering the interior of CROWN_NEST after completing the first five
## checkpoints therefore grants only that final checkpoint and records finish.

const FINISH_PLATFORM_ID: StringName = &"CROWN_NEST"
const FINISH_RADIUS: float = 11.5
const FINISH_VERTICAL_TOLERANCE: float = 4.5

var _world: Node

func _ready() -> void:
	process_physics_priority = 100
	var root: Node = get_parent()
	if root != null:
		_world = root.get_node_or_null("LogspireWorld")

func _physics_process(_delta: float) -> void:
	if not RaceManager.active or _world == null or not is_instance_valid(_world):
		return
	if not _world.has_method("get_finish_position"):
		return
	var finish_value: Variant = _world.call("get_finish_position")
	if not (finish_value is Vector3):
		return
	var finish_position: Vector3 = finish_value

	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		if not _inside_crown_nest(racer, finish_position):
			continue
		_complete_final_checkpoint_if_needed(racer)
		if not RaceManager.can_finish(racer):
			continue
		var rank: int = RaceManager.record_finish(racer)
		print("LOGSPIRE CROWN NEST FINISH racer=%s rank=%d checkpoints=%d/%d platform_finish=true crossing_plane_required=false" % [
			RaceManager.get_racer_label(racer),
			rank,
			RaceManager.get_checkpoint_progress(racer),
			RaceManager.get_checkpoint_count(),
		])

func _inside_crown_nest(racer: WildDashCharacterController, finish_position: Vector3) -> bool:
	var delta: Vector3 = racer.global_position - finish_position
	if absf(delta.y) > FINISH_VERTICAL_TOLERANCE:
		return false
	delta.y = 0.0
	return delta.length() <= FINISH_RADIUS

func _complete_final_checkpoint_if_needed(racer: WildDashCharacterController) -> void:
	var checkpoint_count: int = RaceManager.get_checkpoint_count()
	if checkpoint_count <= 0:
		return
	var progress: int = RaceManager.get_checkpoint_progress(racer)
	if progress != checkpoint_count - 1:
		return
	if RaceManager.record_checkpoint(racer, checkpoint_count - 1):
		print("LOGSPIRE FINAL CHECKPOINT ASSIST racer=%s checkpoint=%d/%d source=crown_nest first_five_required=true" % [
			RaceManager.get_racer_label(racer), checkpoint_count, checkpoint_count,
		])
