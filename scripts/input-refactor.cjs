const fs = require("node:fs");

function read(path) {
  return fs.readFileSync(path, "utf8");
}

function write(path, text) {
  fs.writeFileSync(path, text);
}

function replaceRequired(text, from, to, label) {
  if (!text.includes(from)) throw new Error(`Missing expected block: ${label}`);
  return text.replace(from, to);
}

function assertCentralized(path, text) {
  if (text.includes('window.addEventListener("keydown"')) throw new Error(`${path} still registers keydown directly`);
  if (text.includes("keys.current")) throw new Error(`${path} still reads local key state`);
}

let page = read("app/page.tsx");
page = replaceRequired(page, 'import { Race3D } from "./Race3D";\n', 'import { Race3D } from "./Race3D";\nimport { inputManager } from "../game/input/InputManager";\n', "page import");
page = replaceRequired(page, '  const keys = useRef<Record<string, boolean>>({});\n', "", "page key ref");
page = replaceRequired(
  page,
  `  useEffect(() => {\n    const down = (e: KeyboardEvent) => {\n      keys.current[e.key.toLowerCase()] = true;\n      if ([" ", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(e.key.toLowerCase())) e.preventDefault();\n      if (e.key === " ") doJump();\n      if (e.key.toLowerCase() === "e") activateSkill();\n      if (e.key.toLowerCase() === "q") activateItem();\n    };\n    const up = (e: KeyboardEvent) => { keys.current[e.key.toLowerCase()] = false; };\n    window.addEventListener("keydown", down); window.addEventListener("keyup", up);\n    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };\n  }, [doJump, activateItem, activateSkill]);`,
  `  useEffect(() => {\n    if (screen !== "race" || ENABLE_3D_RACE) return;\n    return inputManager.activate("legacy-race", { onJump: doJump, onSkill: activateSkill, onItem: activateItem });\n  }, [screen, doJump, activateItem, activateSkill]);`,
  "page keyboard effect",
);
page = page
  .replaceAll('keys.current["d"] || keys.current["arrowright"]', 'inputManager.isPressed("right")')
  .replaceAll('keys.current["a"] || keys.current["arrowleft"]', 'inputManager.isPressed("left")')
  .replaceAll('keys.current["s"] || keys.current["arrowdown"]', 'inputManager.isPressed("down")')
  .replaceAll('keys.current["w"] || keys.current["arrowup"]', 'inputManager.isPressed("up")')
  .replaceAll('onPointerDown={()=>keys.current["w"]=true}', 'onPointerDown={()=>inputManager.setExternalAction("legacy-race-touch","up",true)}')
  .replaceAll('onPointerUp={()=>keys.current["w"]=false}', 'onPointerUp={()=>inputManager.setExternalAction("legacy-race-touch","up",false)}')
  .replaceAll('onPointerCancel={()=>keys.current["w"]=false}', 'onPointerCancel={()=>inputManager.setExternalAction("legacy-race-touch","up",false)}')
  .replaceAll('onPointerDown={()=>keys.current["s"]=true}', 'onPointerDown={()=>inputManager.setExternalAction("legacy-race-touch","down",true)}')
  .replaceAll('onPointerUp={()=>keys.current["s"]=false}', 'onPointerUp={()=>inputManager.setExternalAction("legacy-race-touch","down",false)}')
  .replaceAll('onPointerCancel={()=>keys.current["s"]=false}', 'onPointerCancel={()=>inputManager.setExternalAction("legacy-race-touch","down",false)}')
  .replaceAll('onPointerDown={()=>keys.current["d"]=true}', 'onPointerDown={()=>inputManager.setExternalAction("legacy-race-touch","right",true)}')
  .replaceAll('onPointerUp={()=>keys.current["d"]=false}', 'onPointerUp={()=>inputManager.setExternalAction("legacy-race-touch","right",false)}')
  .replaceAll('onPointerCancel={()=>keys.current["d"]=false}', 'onPointerCancel={()=>inputManager.setExternalAction("legacy-race-touch","right",false)}');
assertCentralized("app/page.tsx", page);
write("app/page.tsx", page);

let race = read("app/Race3D.tsx");
race = replaceRequired(race, 'import { useCallback, useEffect, useRef, useState } from "react";\n', 'import { useCallback, useEffect, useRef, useState } from "react";\nimport { inputManager, type InputAction } from "../game/input/InputManager";\n', "Race3D import");
race = replaceRequired(race, '  const keys=useRef<Record<string,boolean>>({});\n', "", "Race3D key ref");
race = replaceRequired(
  race,
  `  useEffect(()=>{\n    const down=(e:KeyboardEvent)=>{keys.current[e.key.toLowerCase()]=true;if(e.key===" "){e.preventDefault();jump()}if(e.key.toLowerCase()==="e")activateSkill();if(e.key.toLowerCase()==="q")activateItem()};\n    const up=(e:KeyboardEvent)=>{keys.current[e.key.toLowerCase()]=false};window.addEventListener("keydown",down);window.addEventListener("keyup",up);return()=>{window.removeEventListener("keydown",down);window.removeEventListener("keyup",up)};\n  },[jump,activateItem,activateSkill]);`,
  `  useEffect(()=>inputManager.activate("race3d",{onJump:jump,onSkill:activateSkill,onItem:activateItem}),[jump,activateItem,activateSkill]);`,
  "Race3D keyboard effect",
);
race = race
  .replaceAll('keys.current["d"]||keys.current["arrowright"]', 'inputManager.isPressed("right")')
  .replaceAll('keys.current["a"]||keys.current["arrowleft"]', 'inputManager.isPressed("left")')
  .replaceAll('keys.current["w"]||keys.current["arrowup"]', 'inputManager.isPressed("up")')
  .replaceAll('keys.current["s"]||keys.current["arrowdown"]', 'inputManager.isPressed("down")')
  .replace('  const press=(key:string,value:boolean)=>{keys.current[key]=value};', '  const press=(action:InputAction,value:boolean)=>inputManager.setExternalAction("race3d-touch",action,value);')
  .replaceAll('press("a",', 'press("left",')
  .replaceAll('press("d",', 'press("right",')
  .replaceAll('press("w",', 'press("up",')
  .replaceAll('press("s",', 'press("down",')
  .replaceAll('onClick={jump}', 'onClick={()=>inputManager.trigger("jump")}')
  .replaceAll('onClick={activateSkill}', 'onClick={()=>inputManager.trigger("skill")}')
  .replaceAll('onClick={activateItem}', 'onClick={()=>inputManager.trigger("item")}');
assertCentralized("app/Race3D.tsx", race);
write("app/Race3D.tsx", race);

let arena = read("app/ArenaRound.tsx");
arena = replaceRequired(arena, 'import { useCallback, useEffect, useRef, useState } from "react";\n', 'import { useCallback, useEffect, useRef, useState } from "react";\nimport { inputManager, type InputAction } from "../game/input/InputManager";\n', "Arena import");
arena = replaceRequired(arena, '  const keys = useRef<Record<string, boolean>>({});\n', "", "Arena key ref");
arena = replaceRequired(
  arena,
  `  useEffect(() => {\n    const down = (e: KeyboardEvent) => { keys.current[e.key.toLowerCase()] = true; if (e.key.toLowerCase() === "e" || e.key === " ") shove(); };\n    const up = (e: KeyboardEvent) => { keys.current[e.key.toLowerCase()] = false; };\n    window.addEventListener("keydown", down); window.addEventListener("keyup", up);\n    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };\n  }, [shove]);`,
  '  useEffect(() => inputManager.activate(`arena:${mode}`, { onJump: shove, onSkill: shove }), [mode, shove]);',
  "Arena keyboard effect",
);
arena = arena
  .replaceAll('keys.current["d"] || keys.current["arrowright"]', 'inputManager.isPressed("right")')
  .replaceAll('keys.current["a"] || keys.current["arrowleft"]', 'inputManager.isPressed("left")')
  .replaceAll('keys.current["s"] || keys.current["arrowdown"]', 'inputManager.isPressed("down")')
  .replaceAll('keys.current["w"] || keys.current["arrowup"]', 'inputManager.isPressed("up")')
  .replace('  const press=(key:string,value:boolean)=>{keys.current[key]=value};', '  const press=(action:InputAction,value:boolean)=>inputManager.setExternalAction("arena-touch",action,value);')
  .replaceAll('press("w",', 'press("up",')
  .replaceAll('press("a",', 'press("left",')
  .replaceAll('press("s",', 'press("down",')
  .replaceAll('press("d",', 'press("right",')
  .replace('onPointerDown={shove}', 'onPointerDown={()=>inputManager.trigger("skill")}');
assertCentralized("app/ArenaRound.tsx", arena);
write("app/ArenaRound.tsx", arena);

const tutorial = read("app/Tutorial.tsx");
if (tutorial.includes('window.addEventListener("keydown"')) throw new Error("Tutorial still registers keyboard input directly");

const tsconfig = JSON.parse(read("tsconfig.json"));
for (const entry of ["game/**/*.ts", "game/**/*.tsx"]) {
  if (!tsconfig.include.includes(entry)) tsconfig.include.push(entry);
}
write("tsconfig.json", `${JSON.stringify(tsconfig, null, 2)}\n`);

const pkg = JSON.parse(read("package.json"));
pkg.scripts.lint = "eslint app src game electron";
pkg.scripts.test = "npm run build && node --test tests/*.test.mjs";
write("package.json", `${JSON.stringify(pkg, null, 2)}\n`);
