import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const scene = read('godot/modes/wild_current/wild_current.tscn');
const presentation = read('godot/modes/wild_current/wild_current_swim_presentation.gd');
const race2 = read('godot/modes/wild_current/wild_current_race_phase2.gd');

test('production Round 5 wires a direct-swimming presentation layer', () => {
  assert.match(scene, /wild_current_race_phase2\.gd/);
  assert.match(scene, /wild_current_swim_presentation\.gd/);
  assert.match(scene, /DirectSwimPresentation/);
  assert.match(presentation, /rideable_mesh=false/);
  assert.match(presentation, /body_in_water=true/);
});

test('legacy box wake and splash visuals are stripped so racers do not look mounted on boards', () => {
  assert.match(race2, /WakeTrail/);
  assert.match(race2, /SurfaceSplash/);
  assert.match(presentation, /Round5SwimFeedback/);
  assert.match(presentation, /WakeTrail/);
  assert.match(presentation, /SurfaceSplash/);
  assert.match(presentation, /mesh_instance\.mesh = null/);
  assert.match(presentation, /r5_ride_visual_removed/);
  assert.doesNotMatch(presentation, /BoxMesh\.new\(\)/);
  assert.doesNotMatch(presentation, /AnimatableBody3D\.new\(\)/);
  assert.doesNotMatch(presentation, /StaticBody3D\.new\(\)/);
});

test('swim presentation visibly submerges and pitches the animal body', () => {
  assert.match(presentation, /SURFACE_IMMERSION: float = 0\.58/);
  assert.match(presentation, /BASE_SWIM_PITCH: float = -0\.19/);
  assert.match(presentation, /BURST_SWIM_PITCH: float = -0\.27/);
  assert.match(presentation, /DIVE_SWIM_PITCH: float = -0\.34/);
  assert.match(presentation, /slot\.position = base_position \+ Vector3\(0\.0, -immersion \+ bob, 0\.0\)/);
  assert.match(presentation, /MAX_STROKE_ROLL/);
  assert.match(presentation, /MAX_TURN_ROLL/);
});

test('Round 5 overrides airborne Jump-looking locomotion with a stroke-compatible state', () => {
  assert.match(presentation, /visual\.play_state\(&"Run"\)/);
  assert.match(presentation, /existing Run cycle is repurposed as a lightweight/);
});

test('wake splash and dive bubbles are particle-only presentation', () => {
  assert.match(presentation, /GPUParticles3D\.new\(\)/);
  assert.match(presentation, /SwimWakeParticles/);
  assert.match(presentation, /StrokeSplashParticles/);
  assert.match(presentation, /DiveBubbleParticles/);
  assert.match(presentation, /ParticleProcessMaterial\.new\(\)/);
  assert.match(presentation, /QuadMesh\.new\(\)/);
  assert.doesNotMatch(presentation, /raft|boat|surfboard|sled/i);
});
