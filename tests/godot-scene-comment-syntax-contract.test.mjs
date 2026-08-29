import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.isFile() && entry.name.endsWith('.tscn')) out.push(full);
  }
  return out;
}

test('Godot text scenes never use hash-prefixed comment lines', () => {
  const scenes = walk('godot');
  const invalid = [];
  for (const scene of scenes) {
    const lines = fs.readFileSync(scene, 'utf8').split(/\r?\n/);
    lines.forEach((line, index) => {
      if (/^\s*#/.test(line)) invalid.push(`${scene}:${index + 1}: ${line.trim()}`);
    });
  }
  assert.deepEqual(invalid, [], `Godot .tscn comments must use ';', not '#':\n${invalid.join('\n')}`);
});
