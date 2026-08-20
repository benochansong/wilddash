class_name WildDashRaceImpactProfile
extends RefCounted

## Typed impact data shared by Round 1 / Round 3 / Round 5 race combat.
## Emergency RC9 power pass: impacts should create a visible passing window, not
## HP damage or long arena-style hard stun.

var impact_strength: float = 1.0
var knockback: float = 0.0
var speed_loss_ratio: float = 0.0
var slow_multiplier: float = 1.0
var slow_duration: float = 0.0
var stagger_duration: float = 0.0
var yaw_instability: float = 0.0
var air_pop: float = 0.0
var camera_strength: float = 0.0
var hitstop_seconds: float = 0.0
var protection_seconds: float = 0.68
var acceleration_multiplier: float = 1.0
var handling_multiplier: float = 1.0
var impact_label: StringName = &"NORMAL"

func copy_profile() -> WildDashRaceImpactProfile:
	var result: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	result.impact_strength = impact_strength
	result.knockback = knockback
	result.speed_loss_ratio = speed_loss_ratio
	result.slow_multiplier = slow_multiplier
	result.slow_duration = slow_duration
	result.stagger_duration = stagger_duration
	result.yaw_instability = yaw_instability
	result.air_pop = air_pop
	result.camera_strength = camera_strength
	result.hitstop_seconds = hitstop_seconds
	result.protection_seconds = protection_seconds
	result.acceleration_multiplier = acceleration_multiplier
	result.handling_multiplier = handling_multiplier
	result.impact_label = impact_label
	return result

static func pack_buster_inner() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.56
	p.knockback = 6.95
	p.speed_loss_ratio = 0.40
	p.slow_multiplier = 0.66
	p.slow_duration = 0.90
	p.stagger_duration = 0.72
	p.yaw_instability = 0.25
	p.air_pop = 2.35
	p.camera_strength = 0.28
	p.hitstop_seconds = 0.075
	p.protection_seconds = 0.78
	p.impact_label = &"HEAVY"
	return p

static func pack_buster_outer() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.18
	p.knockback = 5.35
	p.speed_loss_ratio = 0.27
	p.slow_multiplier = 0.75
	p.slow_duration = 0.70
	p.stagger_duration = 0.46
	p.yaw_instability = 0.17
	p.camera_strength = 0.18
	p.hitstop_seconds = 0.052
	p.protection_seconds = 0.72
	p.impact_label = &"STRONG"
	return p

static func rocket_nut() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.22
	p.knockback = 4.95
	p.speed_loss_ratio = 0.28
	p.slow_multiplier = 0.72
	p.slow_duration = 0.62
	p.stagger_duration = 0.56
	p.yaw_instability = 0.28
	p.camera_strength = 0.18
	p.hitstop_seconds = 0.055
	p.protection_seconds = 0.72
	p.impact_label = &"DIRECT"
	return p

static func shockwave() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.25
	p.knockback = 6.00
	p.speed_loss_ratio = 0.27
	p.slow_multiplier = 0.74
	p.slow_duration = 0.62
	p.stagger_duration = 0.42
	p.yaw_instability = 0.14
	p.camera_strength = 0.15
	p.protection_seconds = 0.66
	p.impact_label = &"BLAST"
	return p

static func banana_peel() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.02
	p.knockback = 1.45
	p.speed_loss_ratio = 0.38
	p.slow_multiplier = 0.68
	p.slow_duration = 0.74
	p.stagger_duration = 0.68
	p.yaw_instability = 0.85
	p.camera_strength = 0.11
	p.protection_seconds = 0.70
	p.impact_label = &"SLIP"
	return p

static func sticky_fruit() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 0.96
	p.knockback = 1.45
	p.speed_loss_ratio = 0.25
	p.slow_multiplier = 0.72
	p.slow_duration = 1.55
	p.stagger_duration = 0.30
	p.yaw_instability = 0.20
	p.acceleration_multiplier = 0.66
	p.handling_multiplier = 0.82
	p.camera_strength = 0.08
	p.protection_seconds = 0.66
	p.impact_label = &"STICKY"
	return p
