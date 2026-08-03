"use client";

import { useCallback, useEffect, useRef, useState } from "react";

type Screen = "lobby" | "lab" | "pick" | "countdown" | "race" | "result";
type AnimalKey = "dog" | "rabbit" | "elephant" | "cat";
type ItemKey = "banana" | "shield" | "magnet" | "ink" | null;

type Animal = {
  name: string;
  emoji: string;
  label: string;
  skill: string;
  description: string;
  color: string;
};

const ANIMALS: Record<AnimalKey, Animal> = {
  dog: { name: "멍대시", emoji: "🐶", label: "밸런스 러너", skill: "전력 질주", description: "4초 동안 속도 +30%", color: "#ff8a4c" },
  rabbit: { name: "깡총이", emoji: "🐰", label: "지형 극복형", skill: "이단 점프", description: "공중에서 한 번 더 점프", color: "#ff66ad" },
  elephant: { name: "코뿜이", emoji: "🐘", label: "탱커 · 방해형", skill: "코 휘두르기", description: "장애물과 앞선 동물을 날려요", color: "#6d7cff" },
  cat: { name: "냥쏘", emoji: "🐱", label: "유연한 회피형", skill: "하악질", description: "근처 경쟁자를 2초간 혼란", color: "#b565f5" },
};

const HEADS = ["🐶", "🐰", "🐊", "🦊", "🐱", "🐘"];
const BODIES = ["🟠", "🟣", "🟢", "🔵", "🟡", "🔴"];
const TAILS = ["〰️", "⚡", "🌈", "🪶", "🍤", "🎀"];
const ITEM_INFO: Record<Exclude<ItemKey, null>, { emoji: string; name: string }> = {
  banana: { emoji: "🍌", name: "바나나" }, shield: { emoji: "🐢", name: "등껍질" }, magnet: { emoji: "🧲", name: "자석" }, ink: { emoji: "🦑", name: "먹물" },
};

const TRACK_LENGTH = 4400;
const LANES = [96, 176, 256];
const OBSTACLES = [
  { x: 720, lane: 0, kind: "log" }, { x: 720, lane: 2, kind: "log" },
  { x: 1190, lane: 1, kind: "mud" }, { x: 1600, lane: 0, kind: "log" },
  { x: 1600, lane: 1, kind: "log" }, { x: 2140, lane: 2, kind: "mud" },
  { x: 2530, lane: 0, kind: "log" }, { x: 2530, lane: 2, kind: "log" },
  { x: 3110, lane: 1, kind: "mud" }, { x: 3570, lane: 0, kind: "log" },
  { x: 3570, lane: 1, kind: "log" },
];
const BOXES = [930, 1880, 2780, 3770];

function Chimera({ head, body, tail, small = false }: { head: number; body: number; tail: number; small?: boolean }) {
  return (
    <div className={`chimera ${small ? "chimera-small" : ""}`} aria-label="조립한 키메라 동물">
      <span className="tail">{TAILS[tail]}</span><span className="body-part">{BODIES[body]}</span><span className="head">{HEADS[head]}</span>
      <span className="leg leg-a" /><span className="leg leg-b" />
    </div>
  );
}

function playTone(frequency = 440, duration = 0.08) {
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
  const [countdown, setCountdown] = useState(3);
  const [snapshot, setSnapshot] = useState({ x: 0, y: 176, z: 0, speed: 0, rank: 50, time: 0, item: null as ItemKey, cooldown: 0, boost: 0, shield: 0, hit: 0, flash: "" });
  const [result, setResult] = useState({ rank: 1, time: 0 });
  const keys = useRef<Record<string, boolean>>({});
  const game = useRef({ x: 0, y: 176, z: 0, vz: 0, speed: 0, time: 0, item: null as ItemKey, cooldown: 0, boost: 0, shield: 0, hit: 0, flash: "", crossed: new Set<number>(), ai: Array.from({ length: 14 }, (_, i) => ({ x: -80 - i * 18, lane: i % 3, pace: 2.7 + (i % 6) * 0.16 })) });

  const resetGame = useCallback(() => {
    game.current = { x: 0, y: 176, z: 0, vz: 0, speed: 0, time: 0, item: null, cooldown: 0, boost: 0, shield: 0, hit: 0, flash: "", crossed: new Set(), ai: Array.from({ length: 14 }, (_, i) => ({ x: -80 - i * 18, lane: i % 3, pace: 2.7 + (i % 6) * 0.16 })) };
    setSnapshot({ x: 0, y: 176, z: 0, speed: 0, rank: 50, time: 0, item: null, cooldown: 0, boost: 0, shield: 0, hit: 0, flash: "" });
  }, []);

  const startCountdown = () => {
    resetGame(); setCountdown(3); setScreen("countdown"); playTone(520, 0.1);
  };

  useEffect(() => {
    if (screen !== "countdown") return;
    if (countdown === 0) { const t = window.setTimeout(() => setScreen("race"), 500); return () => clearTimeout(t); }
    const t = window.setTimeout(() => { setCountdown((v) => v - 1); playTone(countdown === 1 ? 880 : 520, 0.1); }, 760);
    return () => clearTimeout(t);
  }, [screen, countdown]);

  const doJump = useCallback(() => {
    const g = game.current;
    if (g.z <= 1) { g.vz = 9.5; playTone(690, 0.08); }
    else if (animal === "rabbit" && g.z < 65 && g.vz < 4) { g.vz = 8.5; playTone(900, 0.08); }
  }, [animal]);

  const useSkill = useCallback(() => {
    const g = game.current;
    if (g.cooldown > 0) return;
    if (animal === "dog") { g.boost = 4; g.flash = "전력 질주!"; }
    if (animal === "rabbit") { g.vz = 12; g.flash = "슈퍼 깡총!"; }
    if (animal === "elephant") { g.boost = 1.5; g.shield = 2; g.flash = "코 휘두르기!"; }
    if (animal === "cat") { g.shield = 2.5; g.flash = "하악질!"; }
    g.cooldown = 8; playTone(240, 0.18);
  }, [animal]);

  const useItem = useCallback(() => {
    const g = game.current;
    if (!g.item) return;
    if (g.item === "banana") { g.flash = "🍌 바나나 투척!"; g.boost = 1.4; }
    if (g.item === "shield") { g.flash = "🐢 등껍질 방어!"; g.shield = 5; }
    if (g.item === "magnet") { g.flash = "🧲 자석 견인!"; g.x += 230; }
    if (g.item === "ink") { g.flash = "🦑 선두에 먹물 발사!"; g.ai.forEach((a) => { if (a.x > g.x) a.x -= 120; }); }
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
    if (screen !== "race") return;
    let frame = 0; let last = performance.now(); let finished = false;
    const loop = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.035); last = now;
      const g = game.current; g.time += dt; g.cooldown = Math.max(0, g.cooldown - dt); g.boost = Math.max(0, g.boost - dt); g.shield = Math.max(0, g.shield - dt); g.hit = Math.max(0, g.hit - dt);
      const forward = keys.current["d"] || keys.current["arrowright"];
      const brake = keys.current["a"] || keys.current["arrowleft"];
      const target = forward ? 4.8 : 3.15;
      g.speed += (target - g.speed) * dt * 3.8;
      if (brake) g.speed *= 0.97;
      if (g.boost > 0) g.speed += animal === "dog" ? 1.8 : 1;
      if (g.hit > 0) g.speed *= 0.94;
      const vertical = (keys.current["s"] || keys.current["arrowdown"] ? 1 : 0) - (keys.current["w"] || keys.current["arrowup"] ? 1 : 0);
      g.y = Math.max(85, Math.min(267, g.y + vertical * 150 * dt));
      g.vz -= 25 * dt; g.z = Math.max(0, g.z + g.vz * 10 * dt); if (g.z === 0 && g.vz < 0) g.vz = 0;
      g.x += g.speed * 38 * dt;
      OBSTACLES.forEach((o, i) => {
        if (Math.abs(g.x - o.x) < 30 && Math.abs(g.y - LANES[o.lane]) < 32 && g.z < 24 && !g.crossed.has(i)) {
          g.crossed.add(i);
          if (g.shield <= 0) { g.hit = o.kind === "mud" ? 1.2 : 0.75; g.speed = o.kind === "mud" ? 1.25 : -0.8; g.flash = o.kind === "mud" ? "철푸덕! 진흙탕!" : "뽀잉!"; playTone(120, 0.16); }
          else { g.flash = "방어 성공!"; }
        }
      });
      BOXES.forEach((x, i) => {
        const key = 100 + i;
        if (Math.abs(g.x - x) < 28 && g.z < 35 && !g.crossed.has(key)) {
          g.crossed.add(key); const pool: Exclude<ItemKey, null>[] = ["banana", "shield", "magnet", "ink"]; g.item = pool[(i + Math.floor(g.time)) % pool.length]; g.flash = `${ITEM_INFO[g.item].emoji} ${ITEM_INFO[g.item].name} 획득!`; playTone(1050, 0.12);
        }
      });
      g.ai.forEach((a, i) => { a.x += (a.pace + Math.sin(g.time * 1.6 + i) * .28) * 35 * dt; if (a.x > TRACK_LENGTH) a.x = TRACK_LENGTH; });
      const visibleAhead = g.ai.filter((a) => a.x > g.x).length;
      const virtualAhead = Math.max(0, Math.floor((TRACK_LENGTH - g.x) / TRACK_LENGTH * 35));
      const rank = Math.min(50, 1 + visibleAhead + virtualAhead);
      if (g.flash && Math.floor(g.time * 10) % 24 === 0) g.flash = "";
      setSnapshot({ x: g.x, y: g.y, z: g.z, speed: g.speed, rank, time: g.time, item: g.item, cooldown: g.cooldown, boost: g.boost, shield: g.shield, hit: g.hit, flash: g.flash });
      if (g.x >= TRACK_LENGTH && !finished) { finished = true; setResult({ rank, time: g.time }); playTone(940, .25); setScreen("result"); return; }
      if (g.time >= 75 && !finished) { finished = true; setResult({ rank, time: g.time }); setScreen("result"); return; }
      frame = requestAnimationFrame(loop);
    };
    frame = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(frame);
  }, [screen, animal]);

  const camera = Math.max(0, Math.min(TRACK_LENGTH - 900, snapshot.x - 210));
  const cyclePart = (key: keyof typeof parts, direction: number) => setParts((p) => ({ ...p, [key]: (p[key] + direction + 6) % 6 }));

  return (
    <main className={`app-shell screen-${screen}`}>
      <header className="brandbar"><button className="logo" onClick={() => setScreen("lobby")} aria-label="로비로 이동"><span>WILD</span> DASH <i>50</i></button><div className="season">SEASON 01 · SAFARI PANIC</div><button className="sound" aria-label="사운드 켜짐">♫</button></header>

      {screen === "lobby" && <section className="lobby">
        <div className="ticker"><span>● LIVE</span> 오늘의 코스: 우당탕탕 사파리 고속도로 · 수로 비중 20% · 낭떠러지 주의!</div>
        <div className="lobby-copy"><p className="eyebrow">50-PLAYER PARTY ROYALE</p><h1>엉뚱한 동물들의<br/><em>미친 질주!</em></h1><p className="subcopy">나만의 키메라를 만들고, 장애물을 돌파하고,<br/>마지막 결승선까지 살아남으세요.</p><div className="lobby-actions"><button className="primary" onClick={() => setScreen("pick")}>PLAY! <span>→</span></button><button className="secondary" onClick={() => setScreen("lab")}>🧪 키메라 연구소</button></div><div className="online"><b>● 12,481</b>마리 지금 우당탕탕 중</div></div>
        <div className="hero-stage"><div className="spotlight"/><div className="crown">오늘의 엉뚱왕</div><Chimera {...parts}/><div className="nameplate"><b>{ANIMALS[animal].name}</b><span>베이스: {ANIMALS[animal].name.replace("멍대시","강아지").replace("깡총이","토끼").replace("코뿜이","코끼리").replace("냥쏘","고양이")}</span></div><div className="float-sticker sticker-a">WOW!</div><div className="float-sticker sticker-b">⚡</div></div>
        <div className="news-card"><span>WILD NEWS</span><b>🍌 바나나 대란 발생!</b><small>고속도로 3구간이 미끄러워요</small></div>
      </section>}

      {screen === "lab" && <section className="lab-page">
        <button className="back" onClick={() => setScreen("lobby")}>← 로비</button><div className="section-title"><p>CHIMERA LAB · 04</p><h2>키메라 연구소</h2><span>성능 손해 없이, 이상할수록 완벽해요.</span></div>
        <div className="lab-layout"><div className="part-panel"><PartPicker title="머리" value={HEADS[parts.head]} onPrev={() => cyclePart("head",-1)} onNext={() => cyclePart("head",1)}/><PartPicker title="몸통" value={BODIES[parts.body]} onPrev={() => cyclePart("body",-1)} onNext={() => cyclePart("body",1)}/><PartPicker title="꼬리" value={TAILS[parts.tail]} onPrev={() => cyclePart("tail",-1)} onNext={() => cyclePart("tail",1)}/></div><div className="lab-stage"><div className="grid-floor"/><div className="lab-bubble">이 조합… 진짜 괜찮은 거 맞지?</div><Chimera {...parts}/><button className="shuffle" onClick={() => { setParts({head: Math.floor(Math.random()*6),body: Math.floor(Math.random()*6),tail: Math.floor(Math.random()*6)}); playTone(760,.1); }}>🎲 랜덤 조립</button></div><div className="fair-card"><span>FAIR PLAY SYSTEM</span><h3>겉모습은 자유롭게.<br/>성능은 공정하게.</h3><p>비주얼 파츠는 충돌 판정과 능력치에 영향을 주지 않아요. 실제 성능은 베이스 동물로만 결정됩니다.</p><div className="fair-meter"><i/><b>100% FAIR</b></div><button className="primary compact" onClick={() => setScreen("pick")}>이 모습으로 출전 →</button></div></div>
      </section>}

      {screen === "pick" && <section className="pick-page">
        <button className="back" onClick={() => setScreen("lobby")}>← 로비</button><div className="round-board"><span>NEXT ROUND</span><b>ROUND 1 · 레이싱</b><h2>우당탕탕 사파리 고속도로</h2><div><i>평지 55%</i><i>진흙 25%</i><i>점프 20%</i></div></div><p className="pick-hint">지형을 읽고 베이스 동물을 선택하세요</p><div className="animal-grid">{(Object.keys(ANIMALS) as AnimalKey[]).map((key) => { const a=ANIMALS[key]; return <button key={key} className={`animal-card ${animal===key?"selected":""}`} style={{"--animal":a.color} as React.CSSProperties} onClick={() => {setAnimal(key);playTone(600,.06)}}><span className="animal-emoji">{a.emoji}</span><span className="check">✓</span><b>{a.name}</b><small>{a.label}</small><div><strong>{a.skill}</strong><span>{a.description}</span></div></button>})}</div><button className="primary deploy" onClick={startCountdown}>출전 준비 완료! <span>→</span></button><p className="control-hint"><b>이동</b> WASD / 방향키　<b>점프</b> SPACE　<b>스킬</b> E　<b>아이템</b> Q</p>
      </section>}

      {screen === "countdown" && <section className="countdown-page"><div className="letterbox top"/><div className="versus"><div><Chimera {...parts} small/><b>YOU · {ANIMALS[animal].name}</b></div><span>VS</span><div className="rival"><div className="rival-animal">🦊</div><b>49 WILD ANIMALS</b></div></div><p>ROUND 1 · 우당탕탕 사파리 고속도로</p><div className="count-number">{countdown === 0 ? "GO!" : countdown}</div><div className="letterbox bottom"/></section>}

      {screen === "race" && <section className="race-page">
        <div className="race-hud"><div className="rank-box"><small>CURRENT</small><b>{snapshot.rank}<sup>위</sup></b><span>/ 50</span></div><div className="progress-wrap"><span>START</span><div className="progress"><i style={{width:`${Math.min(100,snapshot.x/TRACK_LENGTH*100)}%`}}/><em style={{left:`${Math.min(98,snapshot.x/TRACK_LENGTH*100)}%`}}>{ANIMALS[animal].emoji}</em></div><span>FINISH</span></div><div className="timer">⏱ <b>{snapshot.time.toFixed(1)}</b></div></div>
        <div className="track-window"><div className="sky"><i/><i/><i/></div><div className="track" style={{transform:`translateX(${-camera}px)`}}><div className="lane-lines"><i/><i/></div>{Array.from({length:12},(_,i)=><div className="track-sign" key={i} style={{left:i*400+180}}>{i%3===0?"⚡":i%3===1?"🌴":"⭐"}</div>)}{OBSTACLES.map((o,i)=><div key={i} className={`obstacle ${o.kind}`} style={{left:o.x,top:LANES[o.lane]-25}}>{o.kind==="log"?"🪵":"🟤"}</div>)}{BOXES.map((x,i)=><div key={x} className={`item-box ${game.current.crossed.has(100+i)?"taken":""}`} style={{left:x,top:LANES[(i+1)%3]-25}}>?</div>)}<div className="finish-line" style={{left:TRACK_LENGTH}}><span>FINISH</span></div>{game.current.ai.map((a,i)=><div className="ai-racer" key={i} style={{left:a.x,top:LANES[a.lane],transform:`translateY(-50%) scale(${.72+(a.lane*.04)})`}}><span>{["🦊","🐼","🐷","🐸","🦁","🐵"][i%6]}</span><i>{i+2}</i></div>)}<div className={`player-racer ${snapshot.hit>0?"hit":""}`} style={{left:snapshot.x,top:snapshot.y,transform:`translateY(calc(-50% - ${snapshot.z}px))`}}><div className="player-shadow" style={{transform:`translateY(${snapshot.z}px) scale(${Math.max(.5,1-snapshot.z/130)})`}}/><Chimera {...parts} small/><b>YOU</b>{snapshot.shield>0&&<span className="shield-aura"/>}</div></div>{snapshot.flash&&<div className="game-flash">{snapshot.flash}</div>}</div>
        <div className="race-bottom"><div className="skill-card"><span>{ANIMALS[animal].emoji}</span><div><small>E · ACTIVE SKILL</small><b>{ANIMALS[animal].skill}</b><i><em style={{width:`${Math.max(0,100-snapshot.cooldown/8*100)}%`}}/></i></div><strong>{snapshot.cooldown>0?Math.ceil(snapshot.cooldown):"READY"}</strong></div><button className={`item-slot ${snapshot.item?"ready":""}`} onClick={useItem}><small>Q · ITEM</small><b>{snapshot.item?ITEM_INFO[snapshot.item].emoji:"?"}</b><span>{snapshot.item?ITEM_INFO[snapshot.item].name:"비어 있음"}</span></button></div>
        <div className="mobile-controls"><div><button onPointerDown={()=>keys.current["w"]=true} onPointerUp={()=>keys.current["w"]=false}>▲</button><button onPointerDown={()=>keys.current["s"]=true} onPointerUp={()=>keys.current["s"]=false}>▼</button></div><button onPointerDown={()=>keys.current["d"]=true} onPointerUp={()=>keys.current["d"]=false}>BOOST</button><button onClick={doJump}>JUMP</button><button onClick={useSkill}>SKILL</button></div>
      </section>}

      {screen === "result" && <section className="result-page"><div className="confetti">✦　●　▲　★　●　✦　▲</div><p className="eyebrow">RACE COMPLETE</p><h2>{result.rank <= 25 ? "통과! 다음 라운드 진출" : "아깝다! 다시 도전"}</h2><div className="podium"><span className="laurel">❬</span><div className="winner"><div className="crown-big">♛</div><Chimera {...parts}/><b>{ANIMALS[animal].name}</b><small>WILD #0050</small></div><span className="laurel">❭</span></div><div className="score-row"><div><small>최종 순위</small><b>{result.rank}<em>위</em></b></div><div><small>기록</small><b>{result.time.toFixed(2)}<em>초</em></b></div><div><small>획득 팬</small><b>+{Math.max(120,620-result.rank*10)}</b></div></div><div className="result-actions"><button className="secondary" onClick={() => setScreen("lab")}>🧪 모습 바꾸기</button><button className="primary" onClick={() => setScreen("pick")}>한 판 더! →</button></div><button className="share" onClick={() => {navigator.clipboard?.writeText("나 방금 WILD DASH 50에서 우당탕탕 완주했어! 🐾");playTone(800,.1)}}>▣ 쇼츠로 뽐내기</button></section>}
    </main>
  );
}

function PartPicker({ title, value, onPrev, onNext }: { title: string; value: string; onPrev: () => void; onNext: () => void }) {
  return <div className="part-picker"><small>{title}</small><button onClick={onPrev} aria-label={`${title} 이전`}>‹</button><span>{value}</span><button onClick={onNext} aria-label={`${title} 다음`}>›</button></div>;
}
