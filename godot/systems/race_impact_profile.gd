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
	p.impact_strength = 1.35
	p.knockback = 5.85
	p.speed_loss_ratio = 0.32
	p.slow_multiplier = 0.74
	p.slow_duration = 0.82
	p.stagger_duration = 0.62
	p.yaw_instability = 0.20
	p.air_pop = 2.0
	p.camera_strength = 0.22
	p.hitstop_seconds = 0.065
	p.protection_seconds = 0.78
	p.impact_label = &"HEAVY"
	return p

static func pack_buster_outer() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.0
	p.knockback = 4.35
	p.speed_loss_ratio = 0.20
	p.slow_multiplier = 0.82
	p.slow_duration = 0.62
	p.stagger_duration = 0.38
	p.yaw_instability = 0.12
	p.camera_strength = 0.14
	p.hitstop_seconds = 0.045
	p.protection_seconds = 0.70
	p.impact_label = &"STRONG"
	return p

static func rocket_nut() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.0
	p.knockback = 3.65
	p.speed_loss_ratio = 0.24
	p.slow_multiplier = 0.78
	p.slow_duration = 0.52
	p.stagger_duration = 0.44
	p.yaw_instability = 0.22
	p.camera_strength = 0.13
	p.hitstop_seconds = 0.045
	p.protection_seconds = 0.68
	p.impact_label = &"DIRECT"
	return p

static func shockwave() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 1.05
	p.knockback = 5.25
	p.speed_loss_ratio = 0.18
	p.slow_multiplier = 0.84
	p.slow_duration = 0.50
	p.stagger_duration = 0.32
	p.yaw_instability = 0.10
	p.camera_strength = 0.10
	p.protection_seconds = 0.62
	p.impact_label = &"BLAST"
	return p

static func banana_peel() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 0.85
	p.knockback = 1.15
	p.speed_loss_ratio = 0.27
	p.slow_multiplier = 0.78
	p.slow_duration = 0.62
	p.stagger_duration = 0.50
	p.yaw_instability = 0.72
	p.camera_strength = 0.08
	p.protection_seconds = 0.65
	p.impact_label = &"SLIP"
	return p

static func sticky_fruit() -> WildDashRaceImpactProfile:
	var p: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	p.impact_strength = 0.78
	p.knockback = 1.10
	p.speed_loss_ratio = 0.19
	p.slow_multiplier = 0.80
	p.slow_duration = 1.30
	p.stagger_duration = 0.24
	p.yaw_instability = 0.16
	p.acceleration_multiplier = 0.76
	p.handling_multiplier = 0.89
	p.camera_strength = 0.06
	p.protection_seconds = 0.60
	p.impact_label = &"STICKY"
	return p
