"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { inputManager, type InputAction } from "../game/input/InputManager";
import { audio } from "../game/audio/AudioManager";

export type ArenaMode = "fruit" | "survival" | "final";

type Props = {
  mode: ArenaMode;
  hero: string;
  difficulty: "wild" | "chaos" | "nightmare";
  sound: boolean;
  haptics: boolean;
  onComplete: (success: boolean, score: number) => void;
};

const MODE_INFO = {
  fruit: { round: "ROUND 2", title: "과일 바구니 쟁탈전", mission: "과일 8개를 먼저 모으세요", time: 32 },
  survival: { round: "ROUND 3", title: "바닥 붕괴 생존 지대", mission: "무너지는 타일에서 살아남으세요", time: 26 },
  final: { round: "FINAL", title: "끝장 밀어내기 아레나", mission: "상대를 링 밖으로 밀어내세요", time: 38 },
} as const;

const FRUIT = ["🍎", "🍋", "🍇", "🍉", "🍊", "🍓"];
const RIVALS = ["🦊", "🐼", "🐸", "🦁", "🐷", "🐵", "🐯", "🦝"];

export function ArenaRound({ mode, hero, difficulty, sound, haptics, onComplete }: Props) {
  const info = MODE_INFO[mode];
  const scale = difficulty === "wild" ? .9 : difficulty === "chaos" ? 1 : 1.15;
  const [view, setView] = useState({ x: 50, y: 72, time: Number(info.time), score: 0, hearts: 3, flash: "", shove: 0 });
  const state = useRef({
    x: 50, y: 72, time: Number(info.time), score: 0, hearts: 3, immune: 0, shove: 0, flash: "", done: false,
    fruit: Array.from({ length: 12 }, (_, i) => ({ id: i, x: 10 + ((i * 31) % 80), y: 12 + ((i * 47) % 70), active: true, respawn: 0, emoji: FRUIT[i % FRUIT.length] })),
    bots: RIVALS.slice(0, mode === "final" ? 2 : 8).map((emoji, i) => ({ emoji, x: 16 + (i * 19) % 70, y: 18 + (i * 27) % 62, tx: 50, ty: 50, stun: 0, windup: 1 + i * .35 })),
  });

  const shove = useCallback(() => {
    const s = state.current;
    if (s.shove > 0) return;
    s.shove = 2.2;
    s.flash = "💥 밀치기!";
    if(haptics&&navigator.vibrate)navigator.vibrate(28);
    if(sound)audio.playSfx({frequency:180,duration:.1,volume:.04,waveform:"sine"});
    s.bots.forEach((b) => {
      const d = Math.hypot(b.x - s.x, b.y - s.y);
      if (d < 18) { const push = 18 / Math.max(4, d); b.x += (b.x - s.x) * push; b.y += (b.y - s.y) * push; b.stun = .8; }
    });
  }, [haptics, sound]);

  useEffect(() => inputManager.activate(`arena:${mode}`, { onJump: shove, onSkill: shove }), [mode, shove]);

  useEffect(() => {
    let frame = 0; let last = performance.now();
    const loop = (now: number) => {
      const dt = Math.min(.035, (now - last) / 1000); last = now;
      const s = state.current;
      if (s.done) return;
      s.time = Math.max(0, s.time - dt); s.immune = Math.max(0, s.immune - dt); s.shove = Math.max(0, s.shove - dt);
      const dx = (inputManager.isPressed("right") ? 1 : 0) - (inputManager.isPressed("left") ? 1 : 0);
      const dy = (inputManager.isPressed("down") ? 1 : 0) - (inputManager.isPressed("up") ? 1 : 0);
      const len = Math.hypot(dx, dy) || 1;
      s.x += dx / len * 34 * dt; s.y += dy / len * 34 * dt;
      s.x = Math.max(4, Math.min(96, s.x)); s.y = Math.max(5, Math.min(94, s.y));

      if (mode === "fruit") {
        s.fruit.forEach((f) => {
          if (!f.active) { f.respawn -= dt; if (f.respawn<=0) { f.active=true; f.x=10+((f.id*29+s.time*13)%80); f.y=10+((f.id*43+s.time*9)%80); } }
          if (f.active && Math.hypot(f.x - s.x, f.y - s.y) < 7) { f.active = false; f.respawn=1.4; s.score++; s.flash = `${f.emoji} 획득! ${s.score}/8`; }
        });
        if (s.score >= 8) { s.done = true; onComplete(true, s.score); return; }
      }

      s.bots.forEach((b, i) => {
        b.stun = Math.max(0, b.stun - dt); b.windup -= dt;
        let tx = b.tx, ty = b.ty;
        if (mode === "fruit") {
          const target = s.fruit.find((f) => f.active);
          if (target) { tx = target.x; ty = target.y; }
        } else if (mode === "final" && b.windup < 1.2) { tx = s.x; ty = s.y; }
        else if (Math.floor(s.time * 2 + i) % 9 === 0) { b.tx = 10 + ((i * 37 + s.time * 11) % 80); b.ty = 10 + ((i * 23 + s.time * 7) % 80); }
        const dist = Math.hypot(tx - b.x, ty - b.y) || 1;
        const pace = (b.stun > 0 ? 4 : mode === "final" && b.windup < 0 ? 38 : 18) * scale;
        b.x += (tx - b.x) / dist * pace * dt; b.y += (ty - b.y) / dist * pace * dt;
        if (mode === "fruit") s.fruit.forEach((f) => { if (f.active && Math.hypot(f.x-b.x,f.y-b.y)<5) { f.active=false; f.respawn=1.8; } });
        const contact = Math.hypot(b.x-s.x,b.y-s.y);
        if (contact < 8 && s.immune <= 0) {
          const push = (mode === "final" ? 8 : 4) * scale / Math.max(2, contact);
          s.x += (s.x-b.x)*push; s.y += (s.y-b.y)*push; s.immune=.65; s.flash=`${b.emoji} 몸통박치기!`;
          if(haptics&&navigator.vibrate)navigator.vibrate(35);
        }
        if (mode === "final" && b.windup < -.25) b.windup = 2.4 / scale;
      });

      if (mode === "survival") {
        const col = Math.min(5, Math.floor(s.x / (100/6))); const row = Math.min(4, Math.floor(s.y / 20)); const index = row*6+col;
        const phase = Math.floor((info.time-s.time)/2.25);
        const collapsed = (index+phase*3)%11 < Math.min(3, 1+Math.floor(phase/4));
        if (collapsed && s.immune<=0) { s.hearts--; s.immune=1.8; s.x=50; s.y=50; s.flash="💔 바닥 붕괴! 중앙으로 구조!"; }
        if (s.hearts<=0) { s.done=true; onComplete(false,Math.ceil(info.time-s.time)); return; }
      }
      if (mode === "final") {
        const playerRadius=Math.hypot(s.x-50,(s.y-50)*1.25);
        s.bots=s.bots.filter((b)=>Math.hypot(b.x-50,(b.y-50)*1.25)<48);
        if(playerRadius>48){s.done=true;onComplete(false,s.bots.length);return;}
        if(s.bots.length===0){s.done=true;onComplete(true,2);return;}
      }
      if (s.time<=0) { s.done=true; onComplete(mode === "survival" || (mode === "final" && s.bots.length===0), mode === "fruit" ? s.score : s.hearts); return; }
      setView({x:s.x,y:s.y,time:s.time,score:s.score,hearts:s.hearts,flash:s.flash,shove:s.shove});
      if (s.flash && Math.floor(s.time*10)%18===0) s.flash="";
      frame=requestAnimationFrame(loop);
    };
    frame=requestAnimationFrame(loop); return()=>cancelAnimationFrame(frame);
  }, [haptics, info.time, mode, onComplete, scale]);

  const tilePhase=Math.floor((info.time-view.time)/2.25);
  const press=(action:InputAction,value:boolean)=>inputManager.setExternalAction("arena-touch",action,value);
  return <section className={`arena-page arena-${mode}`}>
    <div className="arena-head"><div><small>{info.round}</small><h2>{info.title}</h2><p>{info.mission}</p></div><div className="arena-stat">{mode==="fruit"?<>🍎 <b>{view.score}/8</b></>:mode==="survival"?<>❤️ <b>{view.hearts}</b></>:<>🏆 <b>{state.current.bots.length}명</b></>}<span>{view.time.toFixed(1)}초</span></div></div>
    <div className={`mini-arena ${view.flash?"impact":""}`}>
      {mode==="survival"&&<div className="tile-grid">{Array.from({length:30},(_,i)=>{const danger=(i+tilePhase*3)%11<Math.min(3,1+Math.floor(tilePhase/4));const warn=(i+(tilePhase+1)*3)%11<Math.min(3,1+Math.floor((tilePhase+1)/4));return <i key={i} className={danger?"gone":warn?"warn":""}/>})}</div>}
      {mode==="final"&&<div className="final-ring"/>}
      {mode==="fruit"&&state.current.fruit.map((f)=><span key={f.id} className={`fruit ${f.active?"":"taken"}`} style={{left:`${f.x}%`,top:`${f.y}%`}}>{f.emoji}</span>)}
      {state.current.bots.map((b,i)=><div key={i} className={`arena-bot ${mode==="final"&&b.windup<1.2?"charging":""} ${b.stun>0?"stunned":""}`} style={{left:`${b.x}%`,top:`${b.y}%`}}><span>{b.emoji}</span>{mode==="final"&&b.windup<1.2&&<i>!</i>}</div>)}
      <div className="arena-player" style={{left:`${view.x}%`,top:`${view.y}%`}}><span>{hero}</span><b>YOU</b>{view.shove>1.8&&<i className="shove-wave"/>}</div>
      {view.flash&&<div className="arena-flash">{view.flash}</div>}
    </div>
    <div className="arena-help"><span>이동 WASD / 방향키</span><span>밀치기 SPACE 또는 E</span></div>
    <div className="arena-mobile"><div className="dpad"><button onPointerDown={()=>press("up",true)} onPointerUp={()=>press("up",false)}>▲</button><button onPointerDown={()=>press("left",true)} onPointerUp={()=>press("left",false)}>◀</button><button onPointerDown={()=>press("down",true)} onPointerUp={()=>press("down",false)}>▼</button><button onPointerDown={()=>press("right",true)} onPointerUp={()=>press("right",false)}>▶</button></div><button className="shove-button" onPointerDown={()=>inputManager.trigger("skill")}>밀치기!</button></div>
  </section>;
}
