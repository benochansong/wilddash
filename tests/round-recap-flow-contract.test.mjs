import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");
const resultManager = readFileSync("godot/scripts/result_manager.gd", "utf8");
const recapScene = readFileSync("godot/scenes/round_recap.tscn", "utf8");
const recap = readFileSync("godot/scenes/round_recap.gd", "utf8");
const finalResult = readFileSync("godot/scenes/result_rc9_balance.gd", "utf8");

test("campaign order remains R1 through R5 and adds an explicit ROUND_RECAP state", () => {
  assert.match(gameManager, /ROUND_RECAP,/);
  assert.match(gameManager, /const ROUND_RECAP_SCENE := "res:\/\/scenes\/round_recap\.tscn"/);
  const order = ["grand_prix", "fruit_collection", "logspire_leap", "push_out", "neon_harbor_race"];
  let last = -1;
  for (const id of order) {
    const index = gameManager.indexOf(`&"${id}"`);
    assert.ok(index > last, `${id} should remain after the previous campaign round`);
    last = index;
  }
});

test("R1 to R4 route through recap before incrementing the campaign index", () => {
  assert.match(gameManager, /if current_round_index \+ 1 < ROUND_SCENES\.size\(\):[\s\S]*set_state\(GameState\.ROUND_RECAP\)[\s\S]*change_scene_to_file\(ROUND_RECAP_SCENE\)/);
  assert.match(gameManager, /func advance_from_round_recap\(\) -> void:[\s\S]*current_round_index \+= 1[\s\S]*set_state\(GameState\.ROUND_BREAK\)[\s\S]*call_deferred\("_load_current_round"\)/);
  assert.match(gameManager, /Failed to load Round Recap:[\s\S]*_advance_round_without_recap\(\)/);
  assert.match(gameManager, /func get_next_round_id\(\) -> StringName:/);
});

test("R5 still bypasses recap and reaches the existing final result", () => {
  assert.match(gameManager, /if current_round_index \+ 1 < ROUND_SCENES\.size\(\):[\s\S]*return\n\t_finish_campaign_to_result\(\)/);
  assert.match(gameManager, /const RESULT_SCENE := "res:\/\/scenes\/result\.tscn"/);
  assert.match(gameManager, /change_scene_to_file\(RESULT_SCENE\)/);
});

test("recap timing is short, skippable and headless-safe", () => {
  assert.match(recapScene, /round_recap\.gd/);
  assert.match(recap, /RECAP_TOTAL_SECONDS: float = 9\.0/);
  assert.match(recap, /ROUND_COMPLETE_END: float = 1\.2/);
  assert.match(recap, /ROUND_RESULT_END: float = 3\.5/);
  assert.match(recap, /WILD_MOMENTS_END: float = 7\.0/);
  assert.match(recap, /SKIP_UNLOCK_SECONDS: float = 1\.5/);
  assert.match(recap, /KEY_SPACE/);
  assert.match(recap, /KEY_ENTER/);
  assert.match(recap, /DisplayServer\.get_name\(\) == "headless"/);
  assert.match(recap, /ROUND RECAP HEADLESS/);
  assert.match(recap, /GameManager\.advance_from_round_recap\(\)/);
});

test("recap presents result, score count-up, campaign total, Wild Moments slot and next round preview", () => {
  assert.match(recap, /ROUND SCORE  \+%d PTS/);
  assert.match(recap, /CAMPAIGN TOTAL/);
  assert.match(recap, /★ WILD MOMENTS ★/);
  assert.match(recap, /SOLID RUN!/);
  assert.match(recap, /NEXT ROUND/);
  assert.match(recap, /GET READY/);
  assert.match(recap, /_summary_with_top_three/);
  assert.match(recap, /configure_animal\(GameManager\.selected_animal\)/);
  assert.match(recap, /configure_chimera\(GameManager\.get_chimera_loadout\(\)\)/);
});

test("ResultManager prepares round summaries and highlight data without changing saved round result shape", () => {
  assert.match(resultManager, /"mode_id": mode_id/);
  assert.match(resultManager, /"success": success/);
  assert.match(resultManager, /"score": score/);
  assert.match(resultManager, /"details": details\.duplicate\(true\)/);
  assert.match(resultManager, /"highlights": highlights/);
  assert.match(resultManager, /func record_highlight_event/);
  assert.match(resultManager, /func get_round_summary_lines/);
  assert.match(resultManager, /func get_campaign_total_score/);
  assert.match(resultManager, /func get_round_points/);
});

test("running recap total and final result share one RC9 score authority", () => {
  assert.match(finalResult, /return ResultManager\.get_campaign_total_score\(\)/);
  assert.match(recap, /ResultManager\.get_campaign_total_score\(\)/);
});
