import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const ROOT = 'godot/modes/grand_prix/grand_prix.tscn';
const TEXT_EXTENSIONS = new Set(['.gd', '.tscn', '.tres']);
const RESOURCE_PATTERN = /res:\/\/[A-Za-z0-9_./-]+\.(?:gd|tscn|tres|png|jpg|jpeg|webp|svg|glb|gltf|ogg|wav|mp3)/g;

function localPath(resourcePath) {
  return `godot/${resourcePath.slice('res://'.length)}`;
}

function extension(path) {
  const dot = path.lastIndexOf('.');
  return dot >= 0 ? path.slice(dot) : '';
}

function collectDependencies(startPath) {
  const visited = new Set();
  const missing = [];
  const queue = [startPath];

  while (queue.length > 0) {
    const file = queue.shift();
    if (visited.has(file)) continue;
    visited.add(file);

    if (!fs.existsSync(file)) {
      missing.push(file);
      continue;
    }

    if (!TEXT_EXTENSIONS.has(extension(file))) continue;
    const source = fs.readFileSync(file, 'utf8');
    const refs = source.match(RESOURCE_PATTERN) ?? [];
    for (const ref of refs) {
      const child = localPath(ref);
      if (!fs.existsSync(child)) {
        missing.push(`${child} referenced by ${file}`);
        continue;
      }
      if (!visited.has(child) && TEXT_EXTENSIONS.has(extension(child))) queue.push(child);
    }
  }

  return { visited, missing };
}

test('Round 1 production scene has a complete on-disk resource dependency graph', () => {
  const { visited, missing } = collectDependencies(ROOT);
  assert.deepEqual(missing, [], `missing Round 1 resources:\n${missing.join('\n')}`);
  assert.ok(visited.has('godot/modes/grand_prix/grand_prix_v7_wild_moments.gd'));
  assert.ok(visited.has('godot/modes/grand_prix/grand_prix_mode.gd'));
  assert.ok(visited.has('godot/tracks/grand_prix_track.tscn'));
  assert.ok(visited.has('godot/characters/test_racer.tscn'));
  assert.ok(visited.has('godot/ui/mode_hud.gd'));
  assert.ok(visited.size >= 20, `unexpectedly shallow Round 1 graph: ${visited.size}`);
});
