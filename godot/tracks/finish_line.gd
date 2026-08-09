extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is WildDashCharacterController:
		if RaceManager.can_finish(body):
			RaceManager.record_finish(body)
		else:
			print("FINISH VALIDATION BLOCK racer=%s checkpoints=%d/%d" % [
				RaceManager.get_racer_label(body),
				RaceManager.get_checkpoint_progress(body),
				RaceManager.get_checkpoint_count(),
			])
