class_name WildDashRaceImpactProfile
extends RefCounted

## Typed impact data shared by Round 1 / Round 3 race combat.
## Race impacts create short, readable disruption rather than long arena-style stun.

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
	p.impact_strength = 1.48
	p.knockback = 6.45
	p.speed_loss_ratio = 0.36
	p.slow_multiplier = 0.70
	p.slow_duration = 0.84
	p.stagger_duration = 0.66
	p.yaw_instability = 0.22
	p.air_pop = 2.15
	p.camera_strength = 0.25
	p.hitstop_seconds = 0.070
	p.protection_seconds = 0.78
	p.impact_label = &"HEAVY"
	return p

static func pack_buster_outer() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.10
	p.knockback = 4.80
	p.speed_loss_ratio = 0.23
	p.slow_multiplier = 0.79
	p.slow_duration = 0.64
	p.stagger_duration = 0.40
	p.yaw_instability = 0.14
	p.camera_strength = 0.16
	p.hitstop_seconds = 0.048
	p.protection_seconds = 0.72
	p.impact_label = &"STRONG"
	return p

static func rocket_nut() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.10
	p.knockback = 4.00
	p.speed_loss_ratio = 0.27
	p.slow_multiplier = 0.75
	p.slow_duration = 0.54
	p.stagger_duration = 0.46
	p.yaw_instability = 0.24
	p.camera_strength = 0.15
	p.hitstop_seconds = 0.048
	p.protection_seconds = 0.70
	p.impact_label = &"DIRECT"
	return p

static func shockwave() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.16
	p.knockback = 5.75
	p.speed_loss_ratio = 0.20
	p.slow_multiplier = 0.82
	p.slow_duration = 0.52
	p.stagger_duration = 0.34
	p.yaw_instability = 0.11
	p.camera_strength = 0.12
	p.protection_seconds = 0.65
	p.impact_label = &"BLAST"
	return p

static func banana_peel() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 0.94
	p.knockback = 1.25
	p.speed_loss_ratio = 0.30
	p.slow_multiplier = 0.75
	p.slow_duration = 0.64
	p.stagger_duration = 0.52
	p.yaw_instability = 0.78
	p.camera_strength = 0.09
	p.protection_seconds = 0.68
	p.impact_label = &"SLIP"
	return p

static func sticky_fruit() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 0.86
	p.knockback = 1.20
	p.speed_loss_ratio = 0.21
	p.slow_multiplier = 0.78
	p.slow_duration = 1.40
	p.stagger_duration = 0.25
	p.yaw_instability = 0.18
	p.acceleration_multiplier = 0.72
	p.handling_multiplier = 0.86
	p.camera_strength = 0.07
	p.protection_seconds = 0.65
	p.impact_label = &"STICKY"
	return p
