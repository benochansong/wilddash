const fs = require("node:fs");

const path = "app/page.tsx";
let source = fs.readFileSync(path, "utf8");

function replaceOnce(from, to, label) {
  if (!source.includes(from)) throw new Error(`Missing expected source: ${label}`);
  source = source.replace(from, to);
}

replaceOnce(
  'import { createRace } from "../game/systems/raceSystem";',
  'import { createRace } from "../game/systems/raceSystem";\nimport { arenaFlowOutcome, entryScreen, nextRoundAfterBreak, roundClearedAfterRace, screenAfterRace } from "../game/systems/flowSystem";',
  "flow system import",
);

replaceOnce(
  '    setScreen(saveManager.hasCompletedTutorial() ? "pick" : "tutorial");',
  '    setScreen(entryScreen(saveManager.hasCompletedTutorial()));',
  "entry screen",
);

replaceOnce(
`  const handleArenaComplete = useCallback((mode: ArenaMode, success: boolean, score: number) => {
    if (!success) {
      const rank = mode === "fruit" ? 26 : mode === "survival" ? 11 : 2;
      setResult({ rank, time: snapshot.time, bumps: snapshot.bumps }); awardProgress(rank); setScreen("result"); return;
    }
    if (mode === "fruit") { setRoundCleared(2); setScreen("roundBreak"); }
    else if (mode === "survival") { setRoundCleared(3); setScreen("roundBreak"); }
    else { setRoundCleared(4); setResult({rank:1,time:snapshot.time,bumps:snapshot.bumps+score}); awardProgress(1,true); setScreen("result"); }
  }, [awardProgress, snapshot.bumps, snapshot.time]);
  const handleRace3DFinish = useCallback((rank:number,time:number,bumps:number) => {
    setResult({rank,time,bumps});
    if(rank<=25){setRoundCleared(1);setScreen("roundBreak");}
    else{awardProgress(rank);setScreen("result");}
  },[awardProgress]);`,
`  const handleArenaComplete = useCallback((mode: ArenaMode, success: boolean, score: number) => {
    const outcome = arenaFlowOutcome(mode, success);
    if (!success) {
      const rank = outcome.failureRank ?? 50;
      setResult({ rank, time: result.time, bumps: result.bumps });
      awardProgress(rank);
      setScreen(outcome.screen);
      return;
    }

    setRoundCleared(outcome.roundCleared);
    if (outcome.champion) {
      setResult({ rank: 1, time: result.time, bumps: result.bumps + score });
      awardProgress(1, true);
    }
    setScreen(outcome.screen);
  }, [awardProgress, result.bumps, result.time]);
  const handleRace3DFinish = useCallback((rank:number,time:number,bumps:number) => {
    const nextScreen = screenAfterRace(rank);
    setResult({rank,time,bumps});
    setRoundCleared(roundClearedAfterRace(rank));
    if (nextScreen === "result") awardProgress(rank);
    setScreen(nextScreen);
  },[awardProgress]);`,
  "round flow handlers",
);

replaceOnce(
  'onClick={()=>setScreen(roundCleared===1?"fruit":roundCleared===2?"survival":"final")}',
  'onClick={()=>setScreen(nextRoundAfterBreak(roundCleared))}',
  "round break target",
);

fs.writeFileSync(path, source);
