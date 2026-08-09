import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

test("desktop build contains the offline game shell", async () => {
  await Promise.all([
    access(new URL("../dist/index.html", import.meta.url)),
    access(new URL("../dist/app-icon.png", import.meta.url)),
    access(new URL("../electron/main.cjs", import.meta.url)),
  ]);

  const html = await readFile(new URL("../dist/index.html", import.meta.url), "utf8");
  assert.match(html, /WILD DASH 50/);
  assert.match(html, /\.\/assets\//);
  assert.doesNotMatch(html, /https?:\/\//);
});
