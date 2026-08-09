class_name WildDashCheckpoint
extends Area3D

@export var checkpoint_index := 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is WildDashCharacterController:
		RaceManager.record_checkpoint(body, checkpoint_index)
