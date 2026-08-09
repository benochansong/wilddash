"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { ArenaRound, type ArenaMode } from "./ArenaRound";
import { Tutorial } from "./Tutorial";
import { Race3D } from "./Race3D";

type Screen = "lobby" | "tutorial" | "lab" | "pick" | "countdown" | "race" | "roundBreak" | "fruit" | "survival" | "final" | "result";
type AnimalKey = "dog" | "rabbit" | "elephant" | "cat";
type ItemKey = "banana" | "shield" | "magnet" | "ink" | null;
type DifficultyKey = "wild" | "chaos" | "nightmare";
const ENABLE_3D_RACE = true;

type Animal = {
  name: string;
  emoji: string;
  label: string;
  skill: string;
  description: string;
  color: string;
  cooldown: number;
};

const ANIMALS: Record<AnimalKey, Animal> = {
  dog: { name: "멍대시", emoji: "🐶", label: "안정적인 러너", skill: "전력 질주", description: "2.5초 동안 속도 +18%", color: "#ff8a4c", cooldown: 10 },
  rabbit: { name: "깡총이", emoji: "🐰", label: "지형 돌파형", skill: "도약 추진", description: "높이 뛰며 앞으로 80m 도약", color: "#ff66ad", cooldown: 7 },
  elephant: { name: "코뿜이", emoji: "🐘", label: "탱커 · 방해형", skill: "코 휘두르기", description: "근접 경쟁자를 밀치고 1회 방어", color: "#6d7cff", cooldown: 9 },
  cat: { name: "냥쏘", emoji: "🐱", label: "교란 · 회피형", skill: "하악질", description: "2.2초 충돌 회피 + 주변 경직", color: "#b565f5", cooldown: 8 },
};

const HEADS = ["🐶", "🐰", "🐊", "🦊", "🐱", "🐘"];
const BODIES = ["🟠", "🟣", "🟢", "🔵", "🟡", "🔴"];
const TAILS = ["〰️", "⚡", "🌈", "🪶", "🍤", "🎀"];
const PART_UNLOCKS = [0, 0, 0, 300, 800, 1500];
const ITEM_INFO: Record<Exclude<ItemKey, null>, { emoji: string; name: string; level: string; description: string }> = {
  banana: { emoji: "🍌", name: "바나나", level: "방해 Lv.1", description: "뒤에 설치 · 짧은 미끄러짐" },
  shield: { emoji: "🐢", name: "등껍질", level: "방어 Lv.2", description: "3.5초 동안 공격 1회 방어" },
  ink: { emoji: "🦑", name: "먹물", level: "교란 Lv.2", description: "앞선 경쟁자를 1.2초 경직" },
  magnet: { emoji: "🧲", name: "자석", level: "역전 Lv.3", description: "앞으로 130m 안전 견인" },
};

const TRACK_LENGTH = 4400;
const LANES = [96, 176, 256];
const AI_EMOJIS = ["🦊", "🐼", "🐷", "🐸", "🦁", "🐵", "🐯", "🦝", "🐻", "🐨", "🦄", "🐮", "🐹", "🦓", "🦒", "🐺", "🦔", "🐲", "🦧", "🐙", "🦈", "🦖"];
const DIFFICULTIES: Record<DifficultyKey, { name: string; tag: string; aiSpeed: number; aggression: number; collision: number; count: number }> = {
  wild: { name: "야생", tag: "치열한 몸싸움", aiSpeed: 1, aggression: .72, collision: .85, count: 16 },
  chaos: { name: "난장판", tag: "추천 · 적극적인 방해", aiSpeed: 1.08, aggression: 1, collision: 1.05, count: 19 },
  nightmare: { name: "생존지옥", tag: "고수용 · 자비 없음", aiSpeed: 1.16, aggression: 1.28, collision: 1.25, count: 22 },
};
const OBSTACLES = [
  { x: 720, lane: 0, kind: "log" }, { x: 720, lane: 2, kind: "log" },
  { x: 1190, lane: 1, kind: "mud" }, { x: 1600, lane: 0, kind: "log" },
  { x: 1600, lane: 1, kind: "log" }, { x: 2140, lane: 2, kind: "mud" },
  { x: 2530, lane: 0, kind: "log" }, { x: 2530, lane: 2, kind: "log" },
  { x: 3110, lane: 1, kind: "mud" }, { x: 3570, lane: 0, kind: "log" },
  { x: 3570, lane: 1, kind: "log" },
];
const BOXES = [930, 1880, 2780, 3770];
const SWEEPERS = [1380, 2320, 3380, 4010];
const ROUTES: { x: number; lane: number; animal: AnimalKey; icon: string; label: string }[] = [
  { x: 1080, lane: 0, animal: "rabbit", icon: "☁️", label: "토끼 이단 점프 길" },
  { x: 1970, lane: 2, animal: "dog", icon: "⚡", label: "강아지 질주 레인" },
  { x: 2860, lane: 1, animal: "elephant", icon: "🧱", label: "코끼리 파괴 벽" },
  { x: 3650, lane: 0, animal: "cat", icon: "🕳️", label: "고양이 비밀 통로" },
];

function createRace(difficulty: DifficultyKey) {
  const config = DIFFICULTIES[difficulty];
  const variant = Math.floor(Math.random()*3);
  return {
    x: 0, y: 176, z: 0, vz: 0, speed: 0, time: 0, item: null as ItemKey,
    cooldown: 0, boost: 0, boostPower: 0, shield: 0, hit: 0, confused: 0, collisionLock: 0, variant,
    flash: "", crossed: new Set<number>(), bumps: 0,
    bananas: [] as { x: number; y: number; owner: "ai" | "player"; life: number }[],
    course: OBSTACLES.map((o,i)=>({...o,x:o.x+(variant-1)*(i%3)*42,lane:(o.lane+variant+(i%2))%3})),
    boxes: BOXES.map((x,i)=>x+(variant-1)*(45+i*12)),
    ai: Array.from({ length: config.count }, (_, i) => ({
      x: ((i % 7) - 3) * 34 - Math.floor(i / 7) * 46,
      y: LANES[i % 3], targetY: LANES[i % 3],
      pace: 3.15 + (i % 6) * .22, aggression: .55 + (i % 5) * .11,
      shoveCd: .8 + i * .1, itemCd: 2.8 + (i % 6) * .75,
      stun: 0, attacking: false, emoji: AI_EMOJIS[i % AI_EMOJIS.length],
    })),
  };
}

function Chimera({ head, body, tail, small = false }: { head: number; body: number; tail: number; small?: boolean }) {
  return (
    <div className={`chimera ${small ? "chimera-small" : ""}`} aria-label="조립한 키메라 동물">
      <span className="tail">{TAILS[tail]}</span><span className="body-part">{BODIES[body]}</span><span className="head">{HEADS[head]}</span>
      <span className="leg leg-a" /><span className="leg leg-b" />
    </div>
  );
}

let soundEnabled = true;
let hapticsEnabled = true;
function playTone(frequency = 440, duration = 0.08) {
  if (hapticsEnabled && frequency < 200 && navigator.vibrate) navigator.vibrate(Math.min(45, Math.round(duration*180)));
  if (!soundEnabled) return;
  if (typeof window === "undefined") return;
  const AudioCtx = window.AudioContext || (window as typeof window & { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
  if (!AudioCtx) return;
  const ctx = new AudioCtx();
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();
  oscillator.type = "square";
  oscillator.frequency.value = frequency;
  gain.gain.setValueAtTime(0.05, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
  oscillator.connect(gain); gain.connect(ctx.destination); oscillator.start(); oscillator.stop(ctx.currentTime + duration);
}

export default function Home() {
  const [screen, setScreen] = useState<Screen>("lobby");
  const [animal, setAnimal] = useState<AnimalKey>("dog");
  const [parts, setParts] = useState({ head: 0, body: 0, tail: 0 });
  const [difficulty, setDifficulty] = useState<DifficultyKey>("chaos");
  const [roundCleared, setRoundCleared] = useState(0);
  const [profile, setProfile] = useState({ fans: 0, wins: 0, best: 50 });
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [settings, setSettings] = useState({ sound: true, haptics: true, reducedMotion: false, highContrast: false, largeTouch: false });
  const [countdown, setCountdown] = useState(3);
  const [snapshot, setSnapshot] = useState({ x: 0, y: 176, z: 0, speed: 0, rank: 50, time: 0, item: null as ItemKey, cooldown: 0, boost: 0, shield: 0, hit: 0, confused: 0, danger: 0, bumps: 0, flash: "" });
  const [result, setResult] = useState({ rank: 1, time: 0, bumps: 0 });
  const keys = useRef<Record<string, boolean>>({});
  const game = useRef(createRace(difficulty));

  useEffect(() => {
    try { const saved = localStorage.getItem("wild-dash-profile"); if (saved) setProfile(JSON.parse(saved)); const savedSettings=localStorage.getItem("wild-dash-settings"); if(savedSettings){const next=JSON.parse(savedSettings);setSettings(next);soundEnabled=next.sound;hapticsEnabled=next.haptics;} } catch { /* device-local progress is optional */ }
  }, []);

  const updateSetting = <K extends keyof typeof settings,>(key: K, value: (typeof settings)[K]) => {
    const next={...settings,[key]:value}; setSettings(next); soundEnabled=next.sound; hapticsEnabled=next.haptics;
    try { localStorage.setItem("wild-dash-settings",JSON.stringify(next)); } catch { /* optional */ }
  };

  const awardProgress = useCallback((rank: number, champion = false) => {
    setProfile((previous) => {
      const next = { fans: previous.fans + Math.max(80, 620-rank*10) + (champion?500:0), wins: previous.wins + (champion?1:0), best: Math.min(previous.best,rank) };
      try { localStorage.setItem("wild-dash-profile", JSON.stringify(next)); } catch { /* ignore private mode storage errors */ }
      return next;
    });
  }, []);

  const resetGame = useCallback(() => {
    game.current = createRace(difficulty);
    setSnapshot({ x: 0, y: 176, z: 0, speed: 0, rank: 50, time: 0, item: null, cooldown: 0, boost: 0, shield: 0, hit: 0, confused: 0, danger: 0, bumps: 0, flash: "" });
  }, [difficulty]);

  const startCountdown = () => {
    resetGame(); setRoundCleared(0); setCountdown(3); setScreen("countdown"); playTone(520, 0.1);
  };
  const beginPlay = () => {
    try { setScreen(localStorage.getItem("wild-dash-tutorial") ? "pick" : "tutorial"); }
    catch { setScreen("pick"); }
  };

  const handleArenaComplete = useCallback((mode: ArenaMode, success: boolean, score: number) => {
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
  },[awardProgress]);

  useEffect(() => {
    if (screen !== "countdown") return;
    if (countdown === 0) { const t = window.setTimeout(() => setScreen("race"), 500); return () => clearTimeout(t); }
    const t = window.setTimeout(() => { setCountdown((v) => v - 1); playTone(countdown === 1 ? 880 : 520, 0.1); }, 760);
    return () => clearTimeout(t);
  }, [screen, countdown]);

  const doJump = useCallback(() => {
    const g = game.current;
    if (g.z <= 1) { g.vz = 9.5; playTone(690, 0.08); }
    else if (animal === "rabbit" && g.z < 65 && g.vz < 4) { g.vz = 8.5; g.x+=45; g.flash="🐰 이단 점프 추진 +45m"; playTone(900, 0.08); }
  }, [animal]);

  const useSkill = useCallback(() => {
    const g = game.current;
    if (g.cooldown > 0) return;
    if (animal === "dog") { g.boost = 2.5; g.boostPower=.18; g.flash = "전력 질주! 2.5초간 +18%"; }
    if (animal === "rabbit") { g.vz = 11; g.x+=80; g.shield=.45; g.flash = "도약 추진! 앞으로 +80m"; }
    if (animal === "elephant") { g.boost = .8; g.boostPower=.1; g.shield = 2; g.ai.forEach((a) => { if (Math.abs(a.x-g.x)<130 && Math.abs(a.y-g.y)<70) { a.x-=95; a.stun=1.2; } }); g.flash = "코 휘두르기! 1회 방어 준비"; }
    if (animal === "cat") { g.shield = 2.2; g.ai.forEach((a) => { if (Math.abs(a.x-g.x)<165) a.stun=1; }); g.flash = "하악질! 2.2초 충돌 회피"; }
    g.cooldown = ANIMALS[animal].cooldown; playTone(240, 0.18);
  }, [animal]);

  const useItem = useCallback(() => {
    const g = game.current;
    if (!g.item) return;
    if (g.item === "banana") { g.flash = "🍌 바나나 투척!"; g.bananas.push({x:g.x-55,y:g.y,owner:"player",life:7}); }
    if (g.item === "shield") { g.flash = "🐢 3.5초 방어막!"; g.shield = 3.5; }
    if (g.item === "magnet") { g.flash = "🧲 자석 견인 +130m"; g.x += 130; g.boost=.7; g.boostPower=.1; }
    if (g.item === "ink") { g.flash = "🦑 앞선 경쟁자 먹물 경직!"; g.ai.filter((a)=>a.x>g.x).sort((a,b)=>a.x-b.x).slice(0,5).forEach((a) => { a.x -= 45; a.stun=1.2; }); }
    g.item = null; playTone(330, 0.16);
  }, []);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      keys.current[e.key.toLowerCase()] = true;
      if ([" ", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(e.key.toLowerCase())) e.preventDefault();
      if (e.key === " ") doJump();
      if (e.key.toLowerCase() === "e") useSkill();
      if (e.key.toLowerCase() === "q") useItem();
    };
    const up = (e: KeyboardEvent) => { keys.current[e.key.toLowerCase()] = false; };
    window.addEventListener("keydown", down); window.addEventListener("keyup", up);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };
  }, [doJump, useItem, useSkill]);

  useEffect(() => {
    if (screen !== "race" || ENABLE_3D_RACE) return;
    let frame = 0; let last = performance.now(); let finished = false;
    const loop = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.035); last = now;
      const g = game.current; const config = DIFFICULTIES[difficulty]; const ramp = 1 + (g.x / TRACK_LENGTH) * .2;
      g.time += dt; g.cooldown = Math.max(0, g.cooldown - dt); g.boost = Math.max(0, g.boost - dt); g.shield = Math.max(0, g.shield - dt); g.hit = Math.max(0, g.hit - dt); g.confused = Math.max(0, g.confused - dt); g.collisionLock = Math.max(0, g.collisionLock - dt);
      const forward = keys.current["d"] || keys.current["arrowright"];
      const brake = keys.current["a"] || keys.current["arrowleft"];
      const baseTarget = forward ? 4.65 : 3.0;
      const target = baseTarget * (1 + (g.boost>0 ? g.boostPower : 0));
      g.speed += (target - g.speed) * dt * 3.8;
      if (brake) g.speed *= 0.97;
      g.speed=Math.min(5.55,g.speed);
      if (g.hit > 0) g.speed *= 0.94;
      let vertical = (keys.current["s"] || keys.current["arrowdown"] ? 1 : 0) - (keys.current["w"] || keys.current["arrowup"] ? 1 : 0);
      if (g.confused > 0) vertical *= -1;
      g.y = Math.max(85, Math.min(267, g.y + vertical * 150 * dt));
      g.vz -= 25 * dt; g.z = Math.max(0, g.z + g.vz * 10 * dt); if (g.z === 0 && g.vz < 0) g.vz = 0;
      g.x += g.speed * 38 * dt;
      g.course.forEach((o, i) => {
        if (Math.abs(g.x - o.x) < 30 && Math.abs(g.y - LANES[o.lane]) < 32 && g.z < 24 && !g.crossed.has(i)) {
          g.crossed.add(i);
          if (g.shield <= 0) { g.hit = o.kind === "mud" ? 1.2 : 0.75; g.speed = o.kind === "mud" ? 1.25 : -0.8; g.flash = o.kind === "mud" ? "철푸덕! 진흙탕!" : "뽀잉!"; playTone(120, 0.16); }
          else { g.flash = "방어 성공!"; }
        }
      });
      g.boxes.forEach((x, i) => {
        const key = 100 + i;
        if (Math.abs(g.x - x) < 28 && g.z < 35 && !g.crossed.has(key)) {
          g.crossed.add(key); const pool: Exclude<ItemKey, null>[] = ["banana", "shield", "magnet", "ink"]; g.item = pool[(i + Math.floor(g.time)) % pool.length]; g.flash = `${ITEM_INFO[g.item].emoji} ${ITEM_INFO[g.item].name} 획득!`; playTone(1050, 0.12);
        }
      });
      ROUTES.forEach((route, i) => {
        const key=500+i;
        if(Math.abs(g.x-route.x)<32 && Math.abs(g.y-LANES[route.lane])<34 && !g.crossed.has(key)){
          g.crossed.add(key);
          if(animal===route.animal){g.x+=120;g.boost=1.2;g.boostPower=.12;g.flash=`${route.icon} 전용 지름길 +120m`;playTone(980,.12);}
          else{g.hit=.65;g.speed=.7;g.flash=`🔒 ${route.label} - 다른 길로 피하세요!`;}
        }
      });
      SWEEPERS.forEach((x, i) => {
        const sweeperY = 176 + Math.sin(g.time * (1.7 + i * .18) + i) * 86;
        const key = 300 + i;
        if (Math.abs(g.x-x)<34 && Math.abs(g.y-sweeperY)<38 && g.z<30 && !g.crossed.has(key)) {
          g.crossed.add(key); if (g.shield<=0) { g.hit=1; g.speed=-1.1; g.x-=55; g.flash="💥 회전 장애물 직격!"; playTone(95,.2); } else g.flash="방어막으로 튕겨냈다!";
        }
      });
      g.bananas.forEach((b) => { b.life -= dt; });
      g.bananas = g.bananas.filter((b) => b.life>0 && b.x>g.x-700);
      g.bananas.forEach((b) => {
        if (b.owner==="ai" && Math.abs(g.x-b.x)<28 && Math.abs(g.y-b.y)<30 && g.z<18 && g.collisionLock<=0) {
          b.life=0; g.collisionLock=.8; if(g.shield<=0){g.hit=.85;g.speed=.45;g.x-=38;g.flash="🍌 경쟁자의 바나나! 짧게 미끄러짐";g.bumps++;playTone(110,.2);}else g.flash="방어막으로 바나나 무시!";
        }
      });
      g.ai.forEach((a, i) => {
        a.shoveCd=Math.max(0,a.shoveCd-dt); a.itemCd=Math.max(0,a.itemCd-dt); a.stun=Math.max(0,a.stun-dt);
        const dx=a.x-g.x; const close=Math.abs(dx)<280;
        a.attacking=close && a.aggression*config.aggression>.62 && a.shoveCd<=.45;
        if(a.attacking) a.targetY=g.y;
        else if(Math.floor(g.time*1.2+i)%13===0) a.targetY=LANES[(i+Math.floor(g.time/2))%3];
        a.y += Math.sign(a.targetY-a.y)*Math.min(Math.abs(a.targetY-a.y),dt*(88+config.aggression*35));
        let aiPace=(a.pace+Math.sin(g.time*1.7+i)*.22)*config.aiSpeed*ramp;
        if(dx<-330) aiPace+=1.15; if(dx>520) aiPace-=.65; if(a.stun>0) aiPace*=.28;
        a.x+=Math.max(.5,aiPace)*35*dt; a.x=Math.min(TRACK_LENGTH,a.x);
        if(close && a.itemCd<=0 && dx>25 && dx<240 && i%3===0){g.bananas.push({x:a.x-48,y:a.y,owner:"ai",life:7});a.itemCd=5.5/config.aggression;g.flash=`${a.emoji}가 앞에 바나나를 뿌렸다!`;}
        if(close && a.itemCd<=0 && dx<0 && dx>-250 && i%5===1){g.x-=22*config.collision;a.x+=38;a.itemCd=6;g.flash=`${a.emoji} 자석 견인 공격!`;}
        if(Math.abs(dx)<48 && Math.abs(a.y-g.y)<34 && g.z<24 && g.collisionLock<=0 && a.shoveCd<=0){
          g.collisionLock=.42;a.shoveCd=2.25/config.aggression;
          if(g.shield>0){a.x-=95;a.stun=1.2;g.flash=`${a.emoji}의 몸통박치기 반격!`;}
          else{const direction=g.y<176?-1:1;g.hit=.8;g.speed=Math.min(g.speed,.85);g.x-=42*config.collision;g.y=Math.max(85,Math.min(267,g.y+direction*34*config.collision));g.bumps++;if(i%6===2)g.confused=1.35;g.flash=`${a.emoji} 몸통박치기! 균형을 잃었다!`;playTone(145,.14);}
        }
        g.bananas.forEach((b)=>{if(b.owner==="player"&&Math.abs(a.x-b.x)<25&&Math.abs(a.y-b.y)<28){b.life=0;a.stun=.9;a.x-=45;}});
      });
      const visibleAhead = g.ai.filter((a) => a.x > g.x).length;
      const virtualAhead = Math.max(0, Math.floor((TRACK_LENGTH - g.x) / TRACK_LENGTH * 35));
      const rank = Math.min(50, 1 + visibleAhead + virtualAhead);
      const danger = g.ai.filter((a)=>Math.abs(a.x-g.x)<220).length;
      if (g.flash && Math.floor(g.time * 10) % 24 === 0) g.flash = "";
      setSnapshot({ x: g.x, y: g.y, z: g.z, speed: g.speed, rank, time: g.time, item: g.item, cooldown: g.cooldown, boost: g.boost, shield: g.shield, hit: g.hit, confused: g.confused, danger, bumps:g.bumps, flash: g.flash });
      if (g.x >= TRACK_LENGTH && !finished) { finished = true; setResult({ rank, time: g.time, bumps:g.bumps }); playTone(940, .25); if(rank<=25){setRoundCleared(1);setScreen("roundBreak");}else{awardProgress(rank);setScreen("result");} return; }
      if (g.time >= 75 && !finished) { finished = true; setResult({ rank, time: g.time, bumps:g.bumps }); awardProgress(rank); setScreen("result"); return; }
      frame = requestAnimationFrame(loop);
    };
    frame = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(frame);
  }, [screen, animal, difficulty, awardProgress]);

  const camera = Math.max(0, Math.min(TRACK_LENGTH - 900, snapshot.x - 210));
  const cyclePart = (key: keyof typeof parts, direction: number) => setParts((p) => {
    let candidate=p[key];
    do { candidate=(candidate+direction+6)%6; } while(PART_UNLOCKS[candidate]>profile.fans);
    return {...p,[key]:candidate};
  });
  const unlockedPartCount=PART_UNLOCKS.filter((need)=>need<=profile.fans).length;

  return (
    <main className={`app-shell screen-${screen} ${settings.highContrast?"high-contrast":""} ${settings.reducedMotion?"reduce-motion":""} ${settings.largeTouch?"large-touch":""}`}>
      <header className="brandbar"><button className="logo" onClick={() => setScreen("lobby")} aria-label="로비로 이동"><span>WILD</span> DASH <i>50</i></button><div className="season">SEASON 01 · SAFARI PANIC</div><div className="header-tools"><button className="sound" onClick={()=>updateSetting("sound",!settings.sound)} aria-label={settings.sound?"사운드 끄기":"사운드 켜기"}>{settings.sound?"♫":"×"}</button><button className="sound" onClick={()=>setSettingsOpen(true)} aria-label="게임 설정">⚙</button></div></header>
      {settingsOpen&&<div className="settings-backdrop" onClick={()=>setSettingsOpen(false)}><section className="settings-panel" onClick={(e)=>e.stopPropagation()}><button className="settings-close" onClick={()=>setSettingsOpen(false)}>×</button><p>GAME SETTINGS</p><h2>플레이 설정</h2><SettingRow label="사운드" note="효과음과 간단한 배경 리듬" checked={settings.sound} onChange={(v)=>updateSetting("sound",v)}/><SettingRow label="모바일 진동" note="충돌과 스킬 사용 시 햅틱" checked={settings.haptics} onChange={(v)=>updateSetting("haptics",v)}/><SettingRow label="화면 움직임 줄이기" note="흔들림과 반복 애니메이션 최소화" checked={settings.reducedMotion} onChange={(v)=>updateSetting("reducedMotion",v)}/><SettingRow label="고대비 모드" note="경고와 조작 요소를 더 선명하게" checked={settings.highContrast} onChange={(v)=>updateSetting("highContrast",v)}/><SettingRow label="큰 터치 버튼" note="모바일 조작 버튼을 20% 확대" checked={settings.largeTouch} onChange={(v)=>updateSetting("largeTouch",v)}/><button className="primary compact" onClick={()=>setSettingsOpen(false)}>저장하고 돌아가기</button></section></div>}

      {screen === "lobby" && <section className="lobby">
        <div className="ticker"><span>● OFFLINE</span> 오늘의 코스: 우당탕탕 사파리 고속도로 · 인터넷 연결 없이 바로 플레이!</div>
        <div className="lobby-copy"><p className="eyebrow">50-PLAYER PARTY ROYALE</p><h1>엉뚱한 동물들의<br/><em>미친 질주!</em></h1><p className="subcopy">나만의 키메라를 만들고, 장애물을 돌파하고,<br/>마지막 결승선까지 살아남으세요.</p><div className="lobby-actions"><button className="primary" onClick={beginPlay}>PLAY! <span>→</span></button><button className="secondary" onClick={() => setScreen("lab")}>🧪 키메라 연구소</button><button className="install-button" onClick={()=>setScreen("tutorial")}>🎓 훈련소</button></div><div className="profile-strip"><span>⭐ 팬 <b>{profile.fans.toLocaleString()}</b></span><span>🏆 우승 <b>{profile.wins}</b></span><span>🥇 최고 <b>{profile.best}위</b></span></div><div className="online"><b>● LOCAL</b>진행 기록은 이 PC에 자동 저장됩니다</div></div>
        <div className="hero-stage"><div className="spotlight"/><div className="crown">오늘의 엉뚱왕</div><Chimera {...parts}/><div className="nameplate"><b>{ANIMALS[animal].name}</b><span>베이스: {ANIMALS[animal].name.replace("멍대시","강아지").replace("깡총이","토끼").replace("코뿜이","코끼리").replace("냥쏘","고양이")}</span></div><div className="float-sticker sticker-a">WOW!</div><div className="float-sticker sticker-b">⚡</div></div>
        <div className="news-card"><span>WILD NEWS</span><b>🍌 바나나 대란 발생!</b><small>고속도로 3구간이 미끄러워요</small></div>
      </section>}

      {screen === "tutorial" && <Tutorial hero={HEADS[parts.head]} onDone={()=>setScreen("pick")}/>} 

      {screen === "lab" && <section className="lab-page">
        <button className="back" onClick={() => setScreen("lobby")}>← 로비</button><div className="section-title"><p>CHIMERA LAB · 04</p><h2>키메라 연구소</h2><span>성능 손해 없이, 이상할수록 완벽해요.</span></div>
        <div className="lab-layout"><div className="part-panel"><PartPicker title="머리" value={HEADS[parts.head]} onPrev={() => cyclePart("head",-1)} onNext={() => cyclePart("head",1)}/><PartPicker title="몸통" value={BODIES[parts.body]} onPrev={() => cyclePart("body",-1)} onNext={() => cyclePart("body",1)}/><PartPicker title="꼬리" value={TAILS[parts.tail]} onPrev={() => cyclePart("tail",-1)} onNext={() => cyclePart("tail",1)}/></div><div className="lab-stage"><div className="grid-floor"/><div className="lab-bubble">이 조합… 진짜 괜찮은 거 맞지?</div><Chimera {...parts}/><button className="shuffle" onClick={() => { const pick=()=>Math.floor(Math.random()*unlockedPartCount); setParts({head:pick(),body:pick(),tail:pick()}); playTone(760,.1); }}>🎲 해금 파츠 랜덤 조립</button></div><div className="fair-card"><span>FAIR PLAY SYSTEM</span><h3>겉모습은 자유롭게.<br/>성능은 공정하게.</h3><p>비주얼 파츠는 충돌 판정과 능력치에 영향을 주지 않아요. 실제 성능은 베이스 동물로만 결정됩니다.</p><div className="unlock-track"><b>파츠 해금 {unlockedPartCount}/6</b><span>{unlockedPartCount<6?`다음 파츠까지 팬 ${PART_UNLOCKS[unlockedPartCount]-profile.fans}명`:`모든 파츠 해금 완료!`}</span><i><em style={{width:`${Math.min(100,profile.fans/1500*100)}%`}}/></i></div><div className="fair-meter"><i/><b>100% FAIR</b></div><button className="primary compact" onClick={() => setScreen("pick")}>이 모습으로 출전 →</button></div></div>
      </section>}

      {screen === "pick" && <section className="pick-page">
        <button className="back" onClick={() => setScreen("lobby")}>← 로비</button><div className="round-board"><span>NEXT ROUND · 3D GRAND PRIX</span><b>ROUND 1 · 입체 레이싱</b><h2>와일드 월드 그랑프리</h2><div><i>급커브</i><i>언덕·내리막</i><i>램프·터널</i><i>5개 테마 구간</i></div></div><p className="pick-hint">모두 같은 기본 속도로 출발 · 스킬은 5초 뒤 해제됩니다</p><div className="animal-grid">{(Object.keys(ANIMALS) as AnimalKey[]).map((key) => { const a=ANIMALS[key]; return <button key={key} className={`animal-card ${animal===key?"selected":""}`} style={{"--animal":a.color} as React.CSSProperties} onClick={() => {setAnimal(key);playTone(600,.06)}}><span className="animal-emoji">{a.emoji}</span><span className="check">✓</span><b>{a.name}</b><small>{a.label}</small><div><strong>{a.skill}</strong><span>{a.description}</span></div></button>})}</div><div className="difficulty-picker"><span>경쟁 강도</span>{(Object.keys(DIFFICULTIES) as DifficultyKey[]).map((key)=><button key={key} className={difficulty===key?"selected":""} onClick={()=>setDifficulty(key)}><b>{DIFFICULTIES[key].name}</b><small>{DIFFICULTIES[key].tag}</small></button>)}</div><div className="item-balance">{(Object.keys(ITEM_INFO) as Exclude<ItemKey,null>[]).map((key)=><span key={key}><b>{ITEM_INFO[key].emoji} {ITEM_INFO[key].level}</b><small>{ITEM_INFO[key].description}</small></span>)}</div><button className="primary deploy" onClick={startCountdown}>3D 그랑프리 출전! <span>→</span></button><p className="control-hint"><b>조향</b> A/D · 좌우　<b>가속</b> W　<b>점프</b> SPACE　<b>스킬</b> E　<b>아이템</b> Q</p>
      </section>}

      {screen === "countdown" && <section className="countdown-page"><div className="letterbox top"/><div className="versus"><div><Chimera {...parts} small/><b>YOU · {ANIMALS[animal].name}</b></div><span>VS</span><div className="rival"><div className="rival-animal">🦊</div><b>49 WILD ANIMALS</b></div></div><p>3D GRAND PRIX · 동일 기본 속도 · 스킬 5초 잠금</p><div className="count-number">{countdown === 0 ? "GO!" : countdown}</div><div className="letterbox bottom"/></section>}

      {!ENABLE_3D_RACE && screen === "race" && <section className={`race-page ${snapshot.hit>0?"screen-impact":""} ${snapshot.boost>0?"speeding":""}`}>
        <div className="race-hud"><div className="rank-box"><small>CURRENT</small><b>{snapshot.rank}<sup>위</sup></b><span>/ 50</span></div><div className="progress-wrap"><span>START</span><div className="progress"><i style={{width:`${Math.min(100,snapshot.x/TRACK_LENGTH*100)}%`}}/><em style={{left:`${Math.min(98,snapshot.x/TRACK_LENGTH*100)}%`}}>{ANIMALS[animal].emoji}</em></div><span>FINISH</span></div><div className="timer">⏱ <b>{snapshot.time.toFixed(1)}</b></div><div className={`danger-meter ${snapshot.danger>=4?"hot":""}`}><small>주변 위협</small><b>{"!".repeat(Math.min(5,snapshot.danger)) || "안전"}</b></div></div>
        <div className="track-window"><div className="speed-lines"/><div className="sky"><i/><i/><i/></div><div className="track" style={{transform:`translateX(${-camera}px)`}}><div className="lane-lines"><i/><i/></div>{Array.from({length:12},(_,i)=><div className="track-sign" key={i} style={{left:i*400+180}}>{i%3===0?"⚡":i%3===1?"🌴":"⭐"}</div>)}{game.current.course.map((o,i)=><div key={i} className={`obstacle ${o.kind}`} style={{left:o.x,top:LANES[o.lane]-25}}>{o.kind==="log"?"🪵":"🟤"}</div>)}{ROUTES.map((r,i)=><div key={r.x} className={`route-gate route-${r.animal} ${game.current.crossed.has(500+i)?"used":""}`} style={{left:r.x,top:LANES[r.lane]-33}}><b>{r.icon}</b><span>{r.label}</span></div>)}{SWEEPERS.map((x,i)=><div key={x} className="sweeper" style={{left:x,top:176+Math.sin(snapshot.time*(1.7+i*.18)+i)*86}}>🌀</div>)}{game.current.bananas.map((b,i)=><div key={`${b.x}-${i}`} className={`banana-trap ${b.owner}`} style={{left:b.x,top:b.y}}>🍌</div>)}{game.current.boxes.map((x,i)=><div key={x} className={`item-box ${game.current.crossed.has(100+i)?"taken":""}`} style={{left:x,top:LANES[(i+1+game.current.variant)%3]-25}}>?</div>)}<div className="finish-line" style={{left:TRACK_LENGTH}}><span>FINISH</span></div>{game.current.ai.map((a,i)=><div className={`ai-racer ${a.attacking?"attacking":""} ${a.stun>0?"stunned":""}`} key={i} style={{left:a.x,top:a.y,transform:`translateY(-50%) scale(${.72+(a.y/900)})`}}><span>{a.emoji}</span><i>{a.attacking?"⚠ ATTACK":i+2}</i>{a.attacking&&<em className="attack-telegraph"/>}</div>)}<div className={`player-racer ${snapshot.hit>0?"hit":""} ${snapshot.confused>0?"confused":""}`} style={{left:snapshot.x,top:snapshot.y,transform:`translateY(calc(-50% - ${snapshot.z}px))`}}><div className="player-shadow" style={{transform:`translateY(${snapshot.z}px) scale(${Math.max(.5,1-snapshot.z/130)})`}}/><Chimera {...parts} small/><b>YOU</b>{snapshot.shield>0&&<span className="shield-aura"/>}</div></div>{snapshot.flash&&<div className="game-flash">{snapshot.flash}</div>}{snapshot.confused>0&&<div className="confused-alert">↔ 조작 반전!</div>}</div>
        <div className="race-bottom"><div className="skill-card"><span>{ANIMALS[animal].emoji}</span><div><small>E · ACTIVE SKILL</small><b>{ANIMALS[animal].skill}</b><i><em style={{width:`${Math.max(0,100-snapshot.cooldown/ANIMALS[animal].cooldown*100)}%`}}/></i></div><strong>{snapshot.cooldown>0?Math.ceil(snapshot.cooldown):"READY"}</strong></div><button className={`item-slot ${snapshot.item?"ready":""}`} onClick={useItem}><small>Q · {snapshot.item?ITEM_INFO[snapshot.item].level:"ITEM"}</small><b>{snapshot.item?ITEM_INFO[snapshot.item].emoji:"?"}</b><span>{snapshot.item?ITEM_INFO[snapshot.item].description:"비어 있음"}</span></button></div>
        <div className="mobile-controls"><div className="mobile-steer"><small>AUTO RUN</small><button onPointerDown={()=>keys.current["w"]=true} onPointerUp={()=>keys.current["w"]=false} onPointerCancel={()=>keys.current["w"]=false}>▲</button><button onPointerDown={()=>keys.current["s"]=true} onPointerUp={()=>keys.current["s"]=false} onPointerCancel={()=>keys.current["s"]=false}>▼</button></div><button onPointerDown={()=>keys.current["d"]=true} onPointerUp={()=>keys.current["d"]=false} onPointerCancel={()=>keys.current["d"]=false}>BOOST</button><button onClick={doJump}>JUMP</button><button onClick={useSkill}>SKILL</button><button onClick={useItem}>ITEM</button></div>
      </section>}

      {ENABLE_3D_RACE && screen === "race" && <Race3D animal={animal} hero={HEADS[parts.head]} difficulty={difficulty} sound={settings.sound} haptics={settings.haptics} reducedMotion={settings.reducedMotion} onFinish={handleRace3DFinish}/>} 

      {screen === "roundBreak" && <section className="round-break"><p className="eyebrow">QUALIFIED · TOP {roundCleared===1?25:roundCleared===2?10:5}</p><h2>{roundCleared===1?"레이스 통과!":roundCleared===2?"과일 확보 완료!":"최후의 5마리 생존!"}</h2><div className="survivor-showcase">{AI_EMOJIS.slice(0,roundCleared===1?8:roundCleared===2?5:3).map((e,i)=><span key={i}>{e}</span>)}</div><div className="next-mission"><small>NEXT MISSION</small><b>{roundCleared===1?"🍎 과일 바구니 쟁탈전":roundCleared===2?"🧊 바닥 붕괴 생존 지대":"🥊 끝장 밀어내기 아레나"}</b><p>{roundCleared===1?"과일 8개를 먼저 모으세요":roundCleared===2?"붉게 경고되는 타일을 피하세요":"상대를 링 밖으로 밀어내면 우승!"}</p></div><button className="primary" onClick={()=>setScreen(roundCleared===1?"fruit":roundCleared===2?"survival":"final")}>다음 라운드 시작 →</button></section>}

      {(screen === "fruit" || screen === "survival" || screen === "final") && <ArenaRound mode={screen} hero={HEADS[parts.head]} difficulty={difficulty} sound={settings.sound} haptics={settings.haptics} onComplete={(success,score)=>handleArenaComplete(screen,success,score)}/>}

      {screen === "result" && <section className="result-page"><div className="confetti">✦　●　▲　★　●　✦　▲</div><p className="eyebrow">{roundCleared===4?"WILD CHAMPION":"RUN COMPLETE"} · {DIFFICULTIES[difficulty].name}</p><h2>{roundCleared===4?"최후의 1마리! 완전 우승!":result.rank<=10?"강력한 생존 기록!":"난장판에 휘말렸다!"}</h2><div className="podium"><span className="laurel">❬</span><div className="winner"><div className="crown-big">♛</div><Chimera {...parts}/><b>{ANIMALS[animal].name}</b><small>{roundCleared===4?"WILD CHAMPION":"WILD #0050"}</small></div><span className="laurel">❭</span></div><div className="score-row"><div><small>최종 순위</small><b>{result.rank}<em>위</em></b></div><div><small>통과 라운드</small><b>{roundCleared}<em>/4</em></b></div><div><small>누적 팬</small><b>{profile.fans.toLocaleString()}</b></div></div><div className="result-actions"><button className="secondary" onClick={() => setScreen("lab")}>🧪 모습 바꾸기</button><button className="primary" onClick={() => setScreen("pick")}>한 판 더! →</button></div><button className="share" onClick={() => {navigator.clipboard?.writeText("나 방금 WILD DASH 50에서 우당탕탕 완주했어! 🐾");playTone(800,.1)}}>▣ 쇼츠로 뽐내기</button></section>}
    </main>
  );
}

function PartPicker({ title, value, onPrev, onNext }: { title: string; value: string; onPrev: () => void; onNext: () => void }) {
  return <div className="part-picker"><small>{title}</small><button onClick={onPrev} aria-label={`${title} 이전`}>‹</button><span>{value}</span><button onClick={onNext} aria-label={`${title} 다음`}>›</button></div>;
}

function SettingRow({label,note,checked,onChange}:{label:string;note:string;checked:boolean;onChange:(value:boolean)=>void}){
  return <label className="setting-row"><span><b>{label}</b><small>{note}</small></span><input type="checkbox" checked={checked} onChange={(e)=>onChange(e.target.checked)}/><i/></label>;
}
