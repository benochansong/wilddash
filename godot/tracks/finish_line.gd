extends Area3D

const CROSSING_MARGIN := 0.25

var _candidates: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	for racer_id in _candidates.keys():
		var racer: Node3D = _candidates.get(racer_id)
		if racer == null or not is_instance_valid(racer):
			_candidates.erase(racer_id)
			continue
		if RaceManager.finish_order.has(racer):
			_candidates.erase(racer_id)
			continue
		if not RaceManager.can_finish(racer):
			continue
		if _has_crossed_finish_plane(racer):
			RaceManager.record_finish(racer)
			_candidates.erase(racer_id)

func _on_body_entered(body: Node3D) -> void:
	if not body is WildDashCharacterController:
		return
	_candidates[body.get_instance_id()] = body
	if not RaceManager.can_finish(body):
		print("FINISH VALIDATION BLOCK racer=%s checkpoints=%d/%d" % [
			RaceManager.get_racer_label(body),
			RaceManager.get_checkpoint_progress(body),
			RaceManager.get_checkpoint_count(),
		])

func _on_body_exited(body: Node3D) -> void:
	if body != null:
		_candidates.erase(body.get_instance_id())

func _has_crossed_finish_plane(body: Node3D) -> bool:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return false
	forward = forward.normalized()
	var delta := body.global_position - global_position
	delta.y = 0.0
	return delta.dot(forward) >= CROSSING_MARGIN
