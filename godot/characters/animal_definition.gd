class_name WildDashAnimalDefinition
extends Resource

## Engine-facing identity and tuning data for one WILD DASH animal.
## Gameplay code consumes this resource instead of hard-coding animal stats.

@export_group("Identity")
@export var animal_id: StringName = &"dog"
@export var display_name := "Dog"
@export var nickname := "멍대시"
@export var role := "Balanced Runner"
@export var accent_color := Color(1.0, 0.54, 0.30)
@export var visual_scene: PackedScene

@export_group("Race Movement")
@export var max_speed := 14.5
@export var cruise_speed := 8.8
@export var acceleration := 24.0
@export var turn_speed := 2.15
@export var jump_velocity := 7.5
@export var gravity := 22.0
@export var ai_race_speed := 10.1

@export_group("Arena Movement")
@export var arena_move_speed := 9.5
@export var arena_acceleration := 28.0
@export var knockback_decay := 16.0
@export var ai_arena_speed := 6.7

@export_group("Collision")
@export var collision_radius := 0.62
@export var collision_height := 1.9
@export var collision_center_y := 0.95

@export_group("Camera")
@export var camera_follow_distance := 9.5
@export var camera_follow_height := 5.2
@export var camera_look_ahead := 4.5
@export var camera_smoothing := 7.0
@export var camera_fov := 70.0

@export_group("Skill")
@export var skill_id: StringName = &"dash"
@export var skill_name := "균형 질주"
@export_multiline var skill_description := "2.5초 동안 속도가 상승합니다."
@export var skill_cooldown := 12.0
@export var skill_duration := 2.5
@export var skill_speed_multiplier := 1.0
@export var skill_turn_multiplier := 1.0
@export var skill_jump_multiplier := 1.0
@export var skill_knockback_multiplier := 1.0

func camera_profile() -> Dictionary:
	return {
		"follow_distance": camera_follow_distance,
		"follow_height": camera_follow_height,
		"look_ahead": camera_look_ahead,
		"smoothing": camera_smoothing,
		"fov": camera_fov,
	}
