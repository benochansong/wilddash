const fs = require("node:fs");

function read(path) { return fs.readFileSync(path, "utf8"); }
function write(path, content) { fs.writeFileSync(path, content); }
function replaceRequired(text, from, to, label) {
  if (!text.includes(from)) throw new Error(`Missing expected block: ${label}`);
  return text.replace(from, to);
}

let page = read("app/page.tsx");
page = replaceRequired(
  page,
  'import { audio } from "../game/audio/AudioManager";\n',
  'import { audio } from "../game/audio/AudioManager";\n' +
  'import { ANIMALS, CHIMERA_BODIES as BODIES, CHIMERA_HEADS as HEADS, CHIMERA_TAILS as TAILS, PART_UNLOCKS } from "../game/config/animals";\n' +
  'import { DIFFICULTIES } from "../game/config/difficulty";\n' +
  'import { ITEM_INFO } from "../game/config/items";\n' +
  'import { AI_EMOJIS, BOXES, LANES, OBSTACLES, ROUTES, SWEEPERS, TRACK_LENGTH } from "../game/config/race";\n' +
  'import { saveManager } from "../game/save/SaveManager";\n' +
  'import { createRace } from "../game/systems/raceSystem";\n' +
  'import type { AnimalKey, DifficultyKey, ItemKey, Screen } from "../game/types/game";\n' +
  'import { Chimera } from "../ui/components/Chimera";\n',
  "page module imports",
);

const pageStart = page.indexOf('type Screen =');
const pageEnd = page.indexOf('let hapticsEnabled = true;');
if (pageStart < 0 || pageEnd < 0 || pageEnd <= pageStart) throw new Error("Could not locate page inline configuration block");
page = page.slice(0, pageStart) + page.slice(pageEnd);

page = replaceRequired(
  page,
  '  useEffect(() => {\n    try { const saved = localStorage.getItem("wild-dash-profile"); if (saved) setProfile(JSON.parse(saved)); const savedSettings=localStorage.getItem("wild-dash-settings"); if(savedSettings){const next=JSON.parse(savedSettings);setSettings(next);audio.setMuted(!next.sound);hapticsEnabled=next.haptics;} } catch { /* device-local progress is optional */ }\n  }, []);',
  '  useEffect(() => {\n    const savedProfile = saveManager.loadProfile();\n    if (savedProfile) setProfile(savedProfile);\n    const savedSettings = saveManager.loadSettings();\n    if (savedSettings) {\n      setSettings(savedSettings);\n      audio.setMuted(!savedSettings.sound);\n      hapticsEnabled = savedSettings.haptics;\n    }\n  }, []);',
  "page load save data",
);
page = replaceRequired(
  page,
  '    try { localStorage.setItem("wild-dash-settings",JSON.stringify(next)); } catch { /* optional */ }',
  '    saveManager.saveSettings(next);',
  "page save settings",
);
page = replaceRequired(
  page,
  '      try { localStorage.setItem("wild-dash-profile", JSON.stringify(next)); } catch { /* ignore private mode storage errors */ }',
  '      saveManager.saveProfile(next);',
  "page save profile",
);
page = replaceRequired(
  page,
  '  const beginPlay = () => {\n    try { setScreen(localStorage.getItem("wild-dash-tutorial") ? "pick" : "tutorial"); }\n    catch { setScreen("pick"); }\n  };',
  '  const beginPlay = () => {\n    setScreen(saveManager.hasCompletedTutorial() ? "pick" : "tutorial");\n  };',
  "page tutorial status",
);
if (page.includes("localStorage.")) throw new Error("page.tsx still accesses localStorage directly");
write("app/page.tsx", page);

let tutorial = read("app/Tutorial.tsx");
tutorial = replaceRequired(
  tutorial,
  'import { inputManager, type InputAction } from "../game/input/InputManager";\n',
  'import { inputManager, type InputAction } from "../game/input/InputManager";\nimport { saveManager } from "../game/save/SaveManager";\n',
  "tutorial save import",
);
tutorial = replaceRequired(
  tutorial,
  '        try {\n          localStorage.setItem("wild-dash-tutorial", "done");\n        } catch {\n          /* local storage is optional */\n        }',
  '        saveManager.markTutorialComplete();',
  "tutorial save write",
);
write("app/Tutorial.tsx", tutorial);

let race = read("app/Race3D.tsx");
race = replaceRequired(
  race,
  'import { audio } from "../game/audio/AudioManager";\n',
  'import { audio } from "../game/audio/AudioManager";\n' +
  'import { RACE3D_SKILLS as SKILLS } from "../game/config/animals";\n' +
  'import { RACE3D_ITEM_EMOJIS as ITEMS } from "../game/config/items";\n' +
  'import { RACE3D_BRAKE_SPEED as BRAKE_SPEED, RACE3D_CRUISE_SPEED as CRUISE_SPEED, RACE3D_LENGTH as LENGTH, RACE3D_SECTIONS as SECTIONS, RACE3D_SPRINT_SPEED as SPRINT_SPEED, RACE3D_TRACK_WIDTH as TRACK_WIDTH } from "../game/config/race";\n' +
  'import { seeded } from "../game/systems/aiSystem";\n' +
  'import { obstacleLateral } from "../game/systems/collisionSystem";\n' +
  'import { calculateRank } from "../game/systems/rankingSystem";\n' +
  'import { createRace3DState, sectionFor, trackCenter as center, trackElevation as elevation } from "../game/systems/raceSystem";\n' +
  'import type { AnimalKey, DifficultyKey, ItemKey } from "../game/types/game";\n',
  "Race3D module imports",
);
race = replaceRequired(race, 'type AnimalKey = "dog" | "rabbit" | "elephant" | "cat";\ntype DifficultyKey = "wild" | "chaos" | "nightmare";\ntype ItemKey = "banana" | "shield" | "magnet" | "ink" | null;\n\n', '', "Race3D inline types");
const raceConfigStart = race.indexOf('const LENGTH=24000;');
const raceConfigEndMarker = 'export function Race3D';
const raceConfigEnd = race.indexOf(raceConfigEndMarker);
if (raceConfigStart < 0 || raceConfigEnd < 0 || raceConfigEnd <= raceConfigStart) throw new Error("Could not locate Race3D inline config block");
race = race.slice(0, raceConfigStart) + race.slice(raceConfigEnd);
race = race.replace(
  /  const game=useRef\(\{[\s\S]*?\n  \}\);\n  const feedback=/,
  '  const game=useRef(createRace3DState(seed.current));\n  const feedback=',
);
if (!race.includes('const game=useRef(createRace3DState(seed.current));')) throw new Error("Race3D state factory migration failed");
race = replaceRequired(
  race,
  'const rank=1+g.ai.filter(a=>a.s>g.s).length;',
  'const rank=calculateRank(g.s,g.ai);',
  "Race3D ranking",
);
write("app/Race3D.tsx", race);

const pkg = JSON.parse(read("package.json"));
pkg.scripts.lint = "eslint app src game ui electron";
write("package.json", `${JSON.stringify(pkg, null, 2)}\n`);

const tsconfig = JSON.parse(read("tsconfig.json"));
for (const entry of ["ui/**/*.ts", "ui/**/*.tsx"]) {
  if (!tsconfig.include.includes(entry)) tsconfig.include.push(entry);
}
write("tsconfig.json", `${JSON.stringify(tsconfig, null, 2)}\n`);
