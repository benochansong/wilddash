"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { inputManager, type InputAction } from "../game/input/InputManager";
import { audio } from "../game/audio/AudioManager";
import { RACE3D_SKILLS as SKILLS } from "../game/config/animals";
import { RACE3D_ITEM_EMOJIS as ITEMS } from "../game/config/items";
import { RACE3D_BRAKE_SPEED as BRAKE_SPEED, RACE3D_CRUISE_SPEED as CRUISE_SPEED, RACE3D_LENGTH as LENGTH, RACE3D_SECTIONS as SECTIONS, RACE3D_SPRINT_SPEED as SPRINT_SPEED, RACE3D_TRACK_WIDTH as TRACK_WIDTH } from "../game/config/race";
import { seeded } from "../game/systems/aiSystem";
import { isRaceCollision, obstacleLateral } from "../game/systems/collisionSystem";
import { consumeItem, selectRace3DItem } from "../game/systems/itemSystem";
import { canUseSkill, tickCooldown } from "../game/systems/skillSystem";
import { calculateRank } from "../game/systems/rankingSystem";
import { createRace3DState, sectionFor, trackCenter as center, trackElevation as elevation } from "../game/systems/raceSystem";
import type { AnimalKey, DifficultyKey, ItemKey } from "../game/types/game";

type Props = {
  animal: AnimalKey;
  hero: string;
  difficulty: DifficultyKey;
  sound: boolean;
  haptics: boolean;
  reducedMotion: boolean;
  onFinish: (rank:number,time:number,bumps:number)=>void;
};

export function Race3D({animal,hero,difficulty,sound,haptics,reducedMotion,onFinish}:Props){
  const canvasRef=useRef<HTMLCanvasElement>(null);
  const [view,setView]=useState({rank:25,time:0,speed:0,progress:0,skillCd:5,item:null as ItemKey,flash:"출발 보호 · 스킬 5초 잠금",section:SECTIONS[0].name as string});
  const seed=useRef(Math.floor(Math.random()*9999));
  const game=useRef(createRace3DState(seed.current));
  const feedback=useCallback((frequency:number,duration=.1)=>{
    if(haptics&&frequency<220&&navigator.vibrate)navigator.vibrate(Math.round(duration*220));
    if(!sound)return;
    audio.playSfx({frequency,duration,volume:.035,waveform:"square"});
  },[haptics,sound]);

  const activateSkill=useCallback(()=>{
    const g=game.current;if(!canUseSkill(g.skillCd)){g.flash=`출발 보호 · ${g.skillCd.toFixed(1)}초 후 사용`;return;}
    if(animal==="dog"){g.boost=1.6;g.flash="🐶 균형 질주 +10%";}
    if(animal==="rabbit"){g.vJump=330;g.jump=Math.max(g.jump,10);g.s+=220;g.flash="🐰 고속 도약 추진 +220m";}
    if(animal==="elephant"){g.shield=2;g.flash="🐘 충돌 1회 방어";}
    if(animal==="cat"){g.phase=1.8;g.flash="🐱 1.8초 장애물 통과";}
    g.skillCd=SKILLS[animal].cooldown;feedback(260,.12);
  },[animal,feedback]);

  const activateItem=useCallback(()=>{
    const g=game.current;const item=consumeItem(g.item);if(!item)return;
    if(item==="banana"){g.bananas.push({s:g.s-160,lateral:g.lateral,life:7,owner:"player"});g.flash="🍌 뒤에 바나나 설치";}
    if(item==="shield"){g.shield=3.2;g.flash="🐢 충돌 1회 방어";}
    if(item==="magnet"){g.s+=400;g.flash="🧲 초고속 견인 +400m";}
    if(item==="ink"){game.current.ai.filter(a=>a.s>g.s).sort((a,b)=>a.s-b.s).slice(0,6).forEach(a=>a.stun=1.1);g.flash="🦑 앞선 6마리 시야 방해";}
    g.item=null;feedback(420,.1);
  },[feedback]);

  const jump=useCallback(()=>{const g=game.current;if(g.jump<=1){g.vJump=285;feedback(640,.07)}else if(animal==="rabbit"&&g.jump<75&&g.vJump<80){g.vJump=245;g.s+=150;g.flash="🐰 이단 점프 +150m";feedback(850,.07)}},[animal,feedback]);

  useEffect(()=>inputManager.activate("race3d",{onJump:jump,onSkill:activateSkill,onItem:activateItem}),[jump,activateItem,activateSkill]);

  useEffect(()=>{
    const canvas=canvasRef.current;if(!canvas)return;const ctx=canvas.getContext("2d");if(!ctx)return;
    let frame=0,last=performance.now(),lastUi=0;
    const project=(worldX:number,worldY:number,worldS:number,w:number,h:number)=>{
      const g=game.current;const ahead=worldS-g.s;const depth=Math.max(0,Math.min(1,ahead/1750));const scale=1.08-depth*.42;const tangent=(center(g.s+50)-center(g.s))/50;const relativeX=worldX-center(g.s)-tangent*ahead-g.lateral*.7;return{x:w/2+relativeX*scale*(w/850),y:h*.83-ahead*(h/1780)-(worldY-elevation(g.s))*.32,scale,visible:ahead>-180&&ahead<1780};
    };
    const draw=(w:number,h:number)=>{
      const g=game.current;const section=sectionFor(g.s);const gradient=ctx.createLinearGradient(0,0,0,h);gradient.addColorStop(0,section.sky[0]);gradient.addColorStop(.55,section.sky[1]);gradient.addColorStop(.56,section.ground);gradient.addColorStop(1,"#183c35");ctx.fillStyle=gradient;ctx.fillRect(0,0,w,h);
      ctx.save();if(!reducedMotion){const bank=Math.sin(g.s/700)*.025;ctx.translate(w/2,h/2);ctx.rotate(bank);ctx.translate(-w/2,-h/2)}
      if(!reducedMotion){ctx.save();ctx.globalAlpha=.2+Math.min(.25,Math.max(0,(g.speed-250)/300));ctx.strokeStyle="#ffffff";ctx.lineWidth=3;for(let i=0;i<18;i++){const side=i%2?-1:1;const y=h*.44+((g.s*1.9+i*83)%(h*.6));const spread=(y-h*.35)/(h*.65);const x=w/2+side*(w*.4+spread*w*.24);ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x+side*(18+spread*42),y+30+spread*34);ctx.stroke()}ctx.restore()}
      ctx.globalAlpha=.35;ctx.fillStyle="#fff";for(let i=0;i<7;i++){const x=(i*211-g.s*.05)%(w+240)-100;ctx.beginPath();ctx.ellipse(x,70+(i%3)*42,65,20,0,0,Math.PI*2);ctx.fill()}ctx.globalAlpha=1;
      const arenaPalettes=[["#5f5be8","#706cf2"],["#ff8a57","#ff9d6e"],["#79dff2","#99ebf7"],["#42c892","#59dba6"],["#c35dd3","#da74e5"]];const palette=arenaPalettes[SECTIONS.findIndex(v=>v.name===section.name)];
      for(let d=1740;d>=-150;d-=52){const s1=g.s+d,s2=s1+58,c1=center(s1),c2=center(s2),e1=elevation(s1),e2=elevation(s2);const a=project(c1-TRACK_WIDTH/2,e1,s1,w,h),b=project(c1+TRACK_WIDTH/2,e1,s1,w,h),c=project(c2+TRACK_WIDTH/2,e2,s2,w,h),d2=project(c2-TRACK_WIDTH/2,e2,s2,w,h);ctx.fillStyle=Math.floor(s1/210)%2?palette[0]:palette[1];ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.lineTo(c.x,c.y);ctx.lineTo(d2.x,d2.y);ctx.closePath();ctx.fill();ctx.strokeStyle="rgba(255,255,255,.22)";ctx.lineWidth=Math.max(1,a.scale*2);[-.6,-.2,.2,.6].forEach(l=>{const p1=project(c1+l*TRACK_WIDTH/2,e1+1,s1,w,h),p2=project(c2+l*TRACK_WIDTH/2,e2+1,s2,w,h);ctx.beginPath();ctx.moveTo(p1.x,p1.y);ctx.lineTo(p2.x,p2.y);ctx.stroke()});const left1=project(c1-TRACK_WIDTH/2,e1+5,s1,w,h),left2=project(c2-TRACK_WIDTH/2,e2+5,s2,w,h),right1=project(c1+TRACK_WIDTH/2,e1+5,s1,w,h),right2=project(c2+TRACK_WIDTH/2,e2+5,s2,w,h);ctx.strokeStyle=Math.floor(s1/260)%2?"#fff16b":"#ff5bad";ctx.lineWidth=Math.max(3,a.scale*8);ctx.beginPath();ctx.moveTo(left1.x,left1.y);ctx.lineTo(left2.x,left2.y);ctx.moveTo(right1.x,right1.y);ctx.lineTo(right2.x,right2.y);ctx.stroke();}
      const objects:[number,()=>void][]=[];
      g.obstacles.forEach(o=>{const p=project(center(o.s)+obstacleLateral(o,g.time),elevation(o.s),o.s,w,h);if(!p.visible)return;objects.push([o.s,()=>{ctx.save();ctx.translate(p.x,p.y);ctx.scale(p.scale,p.scale);if(o.type==="spinner"){ctx.rotate(g.time*4+o.id);ctx.strokeStyle="#ffed55";ctx.lineWidth=14;ctx.lineCap="round";ctx.beginPath();ctx.moveTo(-54,0);ctx.lineTo(54,0);ctx.moveTo(0,-54);ctx.lineTo(0,54);ctx.stroke();ctx.fillStyle="#ff4f9b";ctx.beginPath();ctx.arc(0,0,18,0,Math.PI*2);ctx.fill()}else if(o.type==="log"){ctx.fillStyle="#ff8b3d";ctx.strokeStyle="#7f3b2e";ctx.lineWidth=5;ctx.beginPath();ctx.roundRect(-48,-18,96,36,18);ctx.fill();ctx.stroke()}else if(o.type==="mud"){ctx.fillStyle="rgba(91,54,116,.8)";ctx.beginPath();ctx.ellipse(0,0,48,29,0,0,Math.PI*2);ctx.fill()}else if(o.type==="ball"){ctx.fillStyle="#ff5b91";ctx.strokeStyle="#fff";ctx.lineWidth=5;ctx.beginPath();ctx.arc(0,0,34,0,Math.PI*2);ctx.fill();ctx.stroke()}else{ctx.fillStyle="#54e0d0";ctx.strokeStyle="#fff";ctx.lineWidth=4;ctx.beginPath();ctx.moveTo(-46,25);ctx.lineTo(46,25);ctx.lineTo(0,-34);ctx.closePath();ctx.fill();ctx.stroke()}ctx.restore()}])});
      g.boxes.filter(b=>!b.taken).forEach(b=>{const p=project(center(b.s)+b.lateral,elevation(b.s)+12,b.s,w,h);if(p.visible)objects.push([b.s,()=>{ctx.fillStyle="#ff4f9b";ctx.strokeStyle="#17152f";ctx.lineWidth=Math.max(1,3*p.scale);const size=42*p.scale;ctx.fillRect(p.x-size/2,p.y-size,size,size);ctx.strokeRect(p.x-size/2,p.y-size,size,size);ctx.fillStyle="#fff";ctx.font=`bold ${25*p.scale}px sans-serif`;ctx.fillText("?",p.x,p.y-size*.18)}])});
      g.bananas.forEach(b=>{const p=project(center(b.s)+b.lateral,elevation(b.s),b.s,w,h);if(p.visible)objects.push([b.s,()=>{ctx.font=`${35*p.scale}px sans-serif`;ctx.fillText("🍌",p.x,p.y)}])});
      g.ai.forEach((a,i)=>{const p=project(center(a.s)+a.lateral,elevation(a.s),a.s,w,h);if(!p.visible||p.scale<.12)return;objects.push([a.s,()=>{ctx.font=`${Math.max(12,47*p.scale)}px sans-serif`;ctx.fillText(a.emoji,p.x,p.y);if(Math.abs(a.s-g.s)<120){ctx.fillStyle="rgba(24,22,50,.85)";ctx.fillRect(p.x-12,p.y-43*p.scale,24,10);ctx.fillStyle="#fff";ctx.font="7px sans-serif";ctx.fillText(String(i+2),p.x,p.y-35*p.scale)}}])});
      objects.sort((a,b)=>b[0]-a[0]).forEach(([,fn])=>fn());
      const playerY=h*.82-g.jump*.55;ctx.font=`${Math.max(58,w*.068)}px sans-serif`;ctx.textAlign="center";ctx.shadowColor="rgba(0,0,0,.25)";ctx.shadowBlur=10;ctx.fillText(hero,w/2,playerY);ctx.shadowBlur=0;ctx.fillStyle="#dfff45";ctx.strokeStyle="#17152f";ctx.lineWidth=2;ctx.fillRect(w/2-22,playerY-72,44,15);ctx.strokeRect(w/2-22,playerY-72,44,15);ctx.fillStyle="#17152f";ctx.font="bold 9px sans-serif";ctx.fillText("YOU",w/2,playerY-61);
      if(g.phase>0){ctx.strokeStyle="#66ffff";ctx.lineWidth=5;ctx.beginPath();ctx.arc(w/2,playerY-28,48,0,Math.PI*2);ctx.stroke()}ctx.restore();
      const fog=ctx.createLinearGradient(0,h*.22,0,h*.55);fog.addColorStop(0,"rgba(255,255,255,.48)");fog.addColorStop(1,"rgba(255,255,255,0)");ctx.fillStyle=fog;ctx.fillRect(0,h*.2,w,h*.38);
    };
    const loop=(now:number)=>{const g=game.current;const dt=Math.min(.035,(now-last)/1000);last=now;if(g.finished)return;g.time+=dt;g.skillCd=tickCooldown(g.skillCd,dt);g.boost=Math.max(0,g.boost-dt);g.shield=Math.max(0,g.shield-dt);g.phase=Math.max(0,g.phase-dt);g.hit=Math.max(0,g.hit-dt);
      const steer=(inputManager.isPressed("right")?1:0)-(inputManager.isPressed("left")?1:0);g.lateral+=steer*850*dt;g.lateral=Math.max(-TRACK_WIDTH*.46,Math.min(TRACK_WIDTH*.46,g.lateral));const accelerate=inputManager.isPressed("up");const brake=inputManager.isPressed("down");let target=accelerate?SPRINT_SPEED:CRUISE_SPEED;if(brake)target=BRAKE_SPEED;if(g.boost>0)target*=1.1;if(g.hit>0)target*=.72;g.speed+=(target-g.speed)*dt*4.4;g.s+=g.speed*dt;
      g.vJump-=620*dt;g.jump=Math.max(0,g.jump+g.vJump*dt);if(g.jump===0&&g.vJump<0)g.vJump=0;
      g.obstacles.forEach(o=>{if(g.crossed.has(o.id))return;if(isRaceCollision(g.s,o.s,g.lateral,obstacleLateral(o,g.time))){g.crossed.add(o.id);if(o.type==="ramp"){g.vJump=310;g.flash="🔺 램프 점프!"}else if(g.jump<26&&g.phase<=0){if(g.shield>0){g.shield=0;g.flash="방어 성공!"}else{g.hit=.65;g.speed*=.72;g.bumps++;g.flash=`${o.type==="mud"?"진흙탕":"장애물"} 충돌!`;feedback(130,.16)}}}});
      g.boxes.forEach((b,i)=>{if(!b.taken&&Math.abs(g.s-b.s)<90&&Math.abs(g.lateral-b.lateral)<54){b.taken=true;g.item=selectRace3DItem(g.ai.filter(a=>a.s>g.s).length,i);g.flash=`${ITEMS[g.item]} 아이템 획득`;feedback(920,.08)}});
      g.ai.forEach((a,i)=>{a.stun=Math.max(0,a.stun-dt);a.itemCd=Math.max(0,a.itemCd-dt);const diff=difficulty==="wild"?.985:difficulty==="nightmare"?1.018:1;let pace=a.speed*diff;if(a.s<g.s-1800)pace*=1.035;if(a.s>g.s+1800)pace*=.97;if(a.stun>0)pace*=.45;a.s+=pace*dt;a.lateral+=Math.sin(g.time*.9+a.phase)*45*dt;g.obstacles.forEach(o=>{if(!a.crossed.has(o.id)&&Math.abs(a.s-o.s)<75){a.crossed.add(o.id);if(Math.abs(a.lateral-obstacleLateral(o,g.time))<48&&o.type!=="ramp")a.stun=.38+seeded(i+o.id,seed.current)*.28}});if(a.s>g.s+220&&a.s<g.s+900&&a.itemCd<=0&&i%5===0){g.bananas.push({s:a.s-160,lateral:a.lateral,life:6,owner:"ai"});a.itemCd=9+seeded(i+Math.floor(g.time),seed.current)*5;g.flash=`${a.emoji}가 앞에 바나나 설치!`;}if(Math.abs(a.s-g.s)<75&&Math.abs(a.lateral-g.lateral)<38&&g.jump<20&&g.phase<=0){g.lateral+=Math.sign(g.lateral-a.lateral||1)*28;g.speed*=.94;g.bumps++;if(i%8===0)g.flash=`${a.emoji}와 어깨 충돌!`}});
      g.bananas.forEach(b=>{b.life-=dt;if(b.owner==="player")g.ai.forEach(a=>{if(Math.abs(a.s-b.s)<70&&Math.abs(a.lateral-b.lateral)<35){a.stun=.65;b.life=0}});else if(Math.abs(g.s-b.s)<70&&Math.abs(g.lateral-b.lateral)<35&&g.jump<18&&g.phase<=0){b.life=0;if(g.shield>0){g.shield=0;g.flash="방어막으로 바나나 차단!"}else{g.hit=.5;g.speed*=.82;g.bumps++;g.flash="🍌 AI 바나나에 미끄러짐!";feedback(120,.14)}}});g.bananas=g.bananas.filter(b=>b.life>0);
      const rank=calculateRank(g.s,g.ai);const canvasRect=canvas.getBoundingClientRect();const dpr=Math.min(2,window.devicePixelRatio||1);if(canvas.width!==Math.floor(canvasRect.width*dpr)||canvas.height!==Math.floor(canvasRect.height*dpr)){canvas.width=Math.floor(canvasRect.width*dpr);canvas.height=Math.floor(canvasRect.height*dpr)}ctx.setTransform(dpr,0,0,dpr,0,0);draw(canvasRect.width,canvasRect.height);
      if(now-lastUi>60){lastUi=now;setView({rank,time:g.time,speed:g.speed,progress:Math.min(1,g.s/LENGTH),skillCd:g.skillCd,item:g.item,flash:g.flash,section:sectionFor(g.s).name});if(g.flash&&Math.floor(g.time*10)%25===0)g.flash=""}
      if(g.s>=LENGTH){g.finished=true;onFinish(rank,g.time,g.bumps);feedback(980,.25);return}frame=requestAnimationFrame(loop)};
    frame=requestAnimationFrame(loop);return()=>cancelAnimationFrame(frame);
  },[animal,difficulty,feedback,hero,onFinish,reducedMotion]);

  const press=(action:InputAction,value:boolean)=>inputManager.setExternalAction("race3d-touch",action,value);
  return <section className="race3d-page">
    <canvas ref={canvasRef} className="race3d-canvas" aria-label="위에서 내려다보는 원근 연출 파티 동물 레이싱 경기장"/>
    <div className="race3d-hud"><div className="race3d-rank"><small>POSITION</small><b>{view.rank}<sup>위</sup></b><span>/ 50</span></div><div className="race3d-progress"><span>{view.section}</span><i><em style={{width:`${view.progress*100}%`}}/></i><small>넓은 플랫폼 · 장애물 건틀릿 · 복수 경로</small></div><div className="race3d-speed"><b>{Math.round(view.speed)}</b><small>5X SPEED</small></div></div>
    <div className="camera-badge">🎥 OVERHEAD PARTY CAM · 5X</div>
    {view.flash&&<div className="race3d-flash">{view.flash}</div>}
    <div className="race3d-bottom"><div className="race3d-skill"><span>{animal==="dog"?"🐶":animal==="rabbit"?"🐰":animal==="elephant"?"🐘":"🐱"}</span><div><small>E · {view.skillCd>0&&view.time<5?"START LOCK":"ACTIVE"}</small><b>{SKILLS[animal].name}</b><i><em style={{width:`${Math.max(0,100-view.skillCd/SKILLS[animal].cooldown*100)}%`}}/></i></div><strong>{view.skillCd>0?view.skillCd.toFixed(1):"READY"}</strong></div><button className="race3d-item" onClick={()=>inputManager.trigger("item")}><small>Q · ITEM</small><b>{view.item?ITEMS[view.item]:"?"}</b></button></div>
    <div className="race3d-controls"><div><button onPointerDown={()=>press("left",true)} onPointerUp={()=>press("left",false)} onPointerCancel={()=>press("left",false)}>◀</button><button onPointerDown={()=>press("right",true)} onPointerUp={()=>press("right",false)} onPointerCancel={()=>press("right",false)}>▶</button></div><button onPointerDown={()=>press("up",true)} onPointerUp={()=>press("up",false)} onPointerCancel={()=>press("up",false)}>가속</button><button onClick={()=>inputManager.trigger("jump")}>점프</button><button onClick={()=>inputManager.trigger("skill")}>스킬</button><button onClick={()=>inputManager.trigger("item")}>아이템</button></div>
  </section>;
}
