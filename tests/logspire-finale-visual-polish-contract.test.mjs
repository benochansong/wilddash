import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const visualBase = readFileSync("godot/modes/logspire_leap/logspire_finale_visual_polish.gd", "utf8");
const visualV2 = readFileSync("godot/modes/logspire_leap/logspire_finale_visual_polish_v2_camera_readability.gd", "utf8");
const gameplayBase = readFileSync("godot/modes/logspire_leap/logspire_platform_gameplay.gd", "utf8");
const gameplayV2 = readFileSync("godot/modes/logspire_leap/logspire_platform_gameplay_v2_finale_flat_boards.gd", "utf8");
const finish = readFileSync("godot/modes/logspire_leap/logspire_finish_authority.gd", "utf8");

test("production Round 3 keeps water/recovery authority while wiring Finale visual and flat-board adapters", () => {
  assert.match(scene, /logspire_phase3_director_v5_route_clearance\.gd/);
  assert.match(scene, /logspire_water_recovery_v15_vine_only\.gd/);
  assert.match(scene, /logspire_water_submerge_watchdog\.gd/);
  assert.match(scene, /logspire_platform_gameplay_v2_finale_flat_boards\.gd/);
  assert.match(scene, /logspire_finale_visual_polish_v2_camera_readability\.gd/);
  assert.match(scene, /\[node name="SkyFinaleVisualPolish" type="Node" parent="\."\]/);
});

test("base Finale visual helper still exposes river bank, waterfall, void and mist builders", () => {
  assert.match(visualBase, /func _build_finale_visual_river_banks\(\) -> void:/);
  assert.match(visualBase, /func _build_finale_visual_waterfalls\(\) -> void:/);
  assert.match(visualBase, /func _build_finale_underwater_occluders\(\) -> void:/);
  assert.match(visualBase, /func _build_finale_mist_cards\(\) -> void:/);
  assert.match(visualBase, /SkyFinaleVisualPolish/);
});

test("Finale dressing binds to the real CanopyRiver Z6 visual bounds with authored fallback", () => {
  assert.match(visualBase, /FINALE_WATER_SURFACE_PATH := NodePath\("CanopyRiver_Z6"\)/);
  assert.match(visualBase, /FINALE_WATER_FALLBACK_CENTER := Vector3\(0\.0, 48\.25, -720\.0\)/);
  assert.match(visualBase, /FINALE_WATER_FALLBACK_SIZE := Vector2\(100\.0, 190\.0\)/);
  assert.match(visualBase, /var mesh := surface\.mesh as BoxMesh/);
  assert.match(visualBase, /_river_size = Vector2\(mesh\.size\.x, mesh\.size\.z\)/);
});

test("visual dressing remains collision-free and cannot take gameplay authority", () => {
  const combinedVisual = `${visualBase}\n${visualV2}`;
  assert.doesNotMatch(combinedVisual, /StaticBody3D/);
  assert.doesNotMatch(combinedVisual, /Area3D/);
  assert.doesNotMatch(combinedVisual, /CollisionShape3D/);
  assert.doesNotMatch(combinedVisual, /reset_motion/);
  assert.doesNotMatch(combinedVisual, /record_finish/);
  assert.doesNotMatch(combinedVisual, /record_checkpoint/);
  assert.doesNotMatch(combinedVisual, /should_handle_racer/);
  assert.match(visualBase, /set_meta\(&"visual_only", true\)/);
  assert.match(visualBase, /set_meta\(&"gameplay_collision", false\)/);
});

test("camera-facing water-sheet edge is masked and visible river is narrowed around the safe route", () => {
  assert.match(visualV2, /VISIBLE_RIVER_WIDTH: float = 28\.0/);
  assert.match(visualV2, /CanopyRiverShelfLeft/);
  assert.match(visualV2, /CanopyRiverShelf/);
  assert.match(visualV2, /CanopyRiverFrontBarkLip/);
  assert.match(visualV2, /CanopyRiverFrontSpillfall/);
  assert.match(visualV2, /outer_water_covered=true/);
  assert.match(visualV2, /front_sheet_edge_masked=true/);
  assert.match(visualV2, /collision_free=true/);
});

test("water edges and under-water void retain explicit visual masking", () => {
  assert.match(visualBase, /RiverBankLeft/);
  assert.match(visualBase, /RiverBankRight/);
  assert.match(visualBase, /RiverEntryBank_/);
  assert.match(visualBase, /FinaleWaterfallMain/);
  assert.match(visualBase, /UnderRiverBarkShelf/);
  assert.match(visualBase, /HangingRoot_/);
  assert.match(visualBase, /WaterfallBaseMist/);
  assert.match(visualBase, /UnderCanopyRiverMist/);
});

test("legacy Phase2 still owns earlier cylinders but production Finale replaces all three Z6 swing cylinders with box boards", () => {
  assert.match(gameplayBase, /_build_swing_log\(&"Z6_03"/);
  assert.match(gameplayBase, /_build_swing_log\(&"Z6_05"/);
  assert.match(gameplayBase, /_build_swing_log\(&"Z6_07"/);
  assert.match(gameplayV2, /FINALE_SWING_IDS: Array\[StringName\] = \[&"Z6_03", &"Z6_05", &"Z6_07"\]/);
  assert.match(gameplayV2, /_make_box_body\(/);
  assert.match(gameplayV2, /_make_box_contact_area\(/);
  assert.match(gameplayV2, /RetiredCylinder_/);
  assert.match(gameplayV2, /cylinder=false shape=box/);
  assert.doesNotMatch(gameplayV2, /CylinderMesh\.new\(\)/);
  assert.doesNotMatch(gameplayV2, /CylinderShape3D\.new\(\)/);
});

test("flat Finale boards preserve the existing scripted swing timing instead of changing unrelated gameplay", () => {
  assert.match(gameplayV2, /Z6_03", 2\.8, 4\.6/);
  assert.match(gameplayV2, /Z6_05", -3\.2, 4\.2/);
  assert.match(gameplayV2, /Z6_07", 3\.6, 3\.9/);
  assert.match(gameplayV2, /"kind": &"swing"/);
  assert.match(gameplayV2, /"amplitude": amplitude/);
  assert.match(gameplayV2, /"period": maxf\(2\.5, period\)/);
});

test("Round 3 finish authority remains Crown Nest and visual polish does not alter campaign flow", () => {
  assert.match(scene, /logspire_finish_authority\.gd/);
  assert.match(scene, /\[node name="CrownNestFinish" type="Node" parent="\."\]/);
  assert.match(finish, /const FINISH_PLATFORM_ID: StringName = &"CROWN_NEST"/);
  assert.match(finish, /RaceManager\.record_finish\(racer\)/);
  assert.doesNotMatch(visualV2, /RaceManager/);
  assert.doesNotMatch(visualV2, /GameManager/);
});
