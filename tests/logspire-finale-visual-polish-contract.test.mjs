import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const visual = readFileSync("godot/modes/logspire_leap/logspire_finale_visual_polish.gd", "utf8");
const finish = readFileSync("godot/modes/logspire_leap/logspire_finish_authority.gd", "utf8");

test("production Round 3 keeps gameplay water and V5 collision authority while wiring Finale visual polish", () => {
  assert.match(scene, /logspire_phase3_director_v5_route_clearance\.gd/);
  assert.match(scene, /logspire_water_recovery_v15_vine_only\.gd/);
  assert.match(scene, /logspire_water_submerge_watchdog\.gd/);
  assert.match(scene, /logspire_finale_visual_polish\.gd/);
  assert.match(scene, /\[node name="SkyFinaleVisualPolish" type="Node" parent="\."\]/);
});

test("Finale visual helper exposes the requested river bank, waterfall, void and mist builders", () => {
  assert.match(visual, /func _build_finale_visual_river_banks\(\) -> void:/);
  assert.match(visual, /func _build_finale_visual_waterfalls\(\) -> void:/);
  assert.match(visual, /func _build_finale_underwater_occluders\(\) -> void:/);
  assert.match(visual, /func _build_finale_mist_cards\(\) -> void:/);
  assert.match(visual, /SkyFinaleVisualPolish/);
});

test("Finale dressing binds to the real CanopyRiver Z6 visual bounds with authored fallback", () => {
  assert.match(visual, /FINALE_WATER_SURFACE_PATH := NodePath\("CanopyRiver_Z6"\)/);
  assert.match(visual, /FINALE_WATER_FALLBACK_CENTER := Vector3\(0\.0, 48\.25, -720\.0\)/);
  assert.match(visual, /FINALE_WATER_FALLBACK_SIZE := Vector2\(100\.0, 190\.0\)/);
  assert.match(visual, /var mesh := surface\.mesh as BoxMesh/);
  assert.match(visual, /_river_size = Vector2\(mesh\.size\.x, mesh\.size\.z\)/);
});

test("added Finale environment dressing is visual-only and cannot take gameplay authority", () => {
  assert.doesNotMatch(visual, /StaticBody3D/);
  assert.doesNotMatch(visual, /Area3D/);
  assert.doesNotMatch(visual, /CollisionShape3D/);
  assert.doesNotMatch(visual, /reset_motion/);
  assert.doesNotMatch(visual, /record_finish/);
  assert.doesNotMatch(visual, /record_checkpoint/);
  assert.doesNotMatch(visual, /should_handle_racer/);
  assert.match(visual, /set_meta\(&"visual_only", true\)/);
  assert.match(visual, /set_meta\(&"gameplay_collision", false\)/);
});

test("water edges and under-water void receive explicit visual masking", () => {
  assert.match(visual, /RiverBankLeft/);
  assert.match(visual, /RiverBankRight/);
  assert.match(visual, /RiverEntryBank_/);
  assert.match(visual, /FinaleWaterfallMain/);
  assert.match(visual, /UnderRiverBarkShelf/);
  assert.match(visual, /HangingRoot_/);
  assert.match(visual, /WaterfallBaseMist/);
  assert.match(visual, /UnderCanopyRiverMist/);
  assert.match(visual, /r3_finale_visual_bank_added/);
  assert.match(visual, /r3_finale_visual_waterfall_added/);
  assert.match(visual, /r3_finale_visual_void_mask_added/);
  assert.match(visual, /r3_finale_visual_mist_added/);
});

test("Finale visual dressing preserves a wide central route corridor and finish sightline", () => {
  assert.match(visual, /FINALE_ROUTE_CLEAR_WIDTH: float = 32\.0/);
  assert.match(visual, /_river_size\.x - FINALE_ROUTE_CLEAR_WIDTH/);
  assert.match(visual, /route_gap=%.1f/);
  assert.match(visual, /finish_sightline=true/);
  assert.match(visual, /route_corridor_clear=true/);
});

test("Round 3 finish authority remains Crown Nest and visual polish does not alter campaign flow", () => {
  assert.match(scene, /logspire_finish_authority\.gd/);
  assert.match(scene, /\[node name="CrownNestFinish" type="Node" parent="\."\]/);
  assert.match(finish, /const FINISH_PLATFORM_ID: StringName = &"CROWN_NEST"/);
  assert.match(finish, /RaceManager\.record_finish\(racer\)/);
  assert.doesNotMatch(visual, /RaceManager/);
  assert.doesNotMatch(visual, /GameManager/);
});
