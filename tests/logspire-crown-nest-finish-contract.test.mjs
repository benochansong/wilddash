import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const finish = readFileSync("godot/modes/logspire_leap/logspire_finish_authority.gd", "utf8");
const world = readFileSync("godot/modes/logspire_leap/logspire_world.gd", "utf8");

test("Round 3 production wires Crown Nest platform finish authority", () => {
  assert.match(scene, /logspire_finish_authority\.gd/);
  assert.match(scene, /\[node name="CrownNestFinish" type="Node" parent="\."\]/);
  assert.match(world, /_finish_platform_id = &"CROWN_NEST"/);
});

test("Crown Nest finish only repairs the single final missing checkpoint", () => {
  assert.match(finish, /if progress != checkpoint_count - 1:\n\t\treturn/);
  assert.match(finish, /RaceManager\.record_checkpoint\(racer, checkpoint_count - 1\)/);
  assert.match(finish, /first_five_required=true/);
});

test("standing inside the destination platform can finish without crossing beyond its route center", () => {
  assert.match(finish, /FINISH_RADIUS: float = 11\.5/);
  assert.match(finish, /FINISH_VERTICAL_TOLERANCE: float = 4\.5/);
  assert.match(finish, /RaceManager\.can_finish\(racer\)/);
  assert.match(finish, /RaceManager\.record_finish\(racer\)/);
  assert.match(finish, /crossing_plane_required=false/);
});
