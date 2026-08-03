"use client";

import { useCallback, useEffect, useRef, useState } from "react";

type AnimalKey = "dog" | "rabbit" | "elephant" | "cat";
type DifficultyKey = "wild" | "chaos" | "nightmare";
type ItemKey = "banana" | "shield" | "magnet" | "ink" | null;

type Props = {
  animal: AnimalKey;
  hero: string;
  difficulty: DifficultyKey;
  sound: boolean;
  haptics: boolean;
  reducedMotion: boolean;
  onFinish: (rank:number,time:number,bumps:number)=>void;
};

const LENGTH=7600;
// Wide party-race arena: room for the full 50-animal pack to fan out.
const TRACK_WIDTH=680;
const CRUISE_SPEED=305;
const SPRINT_SPEED=355;
const BRAKE_SPEED=205;
const EMOJIS=["🦊","🐼","🐷","🐸","🦁","🐵","🐯","🦝","🐻","🐨","🦄","🐮","🐹","🦓","🦒","🐺","🦔","🐲","🦧","🐙","🦈","🦖"];
const ITEMS: Record<Exclude<ItemKey,null>,string>={banana:"🍌",shield:"🐢",magnet:"🧲",ink:"🦑"};
const SKILLS:Record<AnimalKey,{name:string,cooldown:number}>={dog:{name:"균형 질주 +10%",cooldown:12},rabbit:{name:"도약 추진",cooldown:8},elephant:{name:"코 방어",cooldown:10},cat:{name:"그림자 회피",cooldown:9}};
const SECTIONS=[
  {at:0,name:"초원 스타디움",sky:["#53d6ff","#d7fff1"],ground:"#59b96a"},
  {at:1450,name:"구불구불 캐니언",sky:["#ff9e6b","#ffe2a9"],ground:"#d66f45"},
  {at:2950,name:"빙글빙글 설산",sky:["#77cfff","#effcff"],ground:"#d7f6ff"},
  {at:4550,name:"정글 터널",sky:["#42b887","#baf39f"],ground:"#237b55"},
  {at:6150,name:"네온 결승 도시",sky:["#4b3fb7","#ef70b8"],ground:"#413584"},
] as const;

const center=(s:number)=>Math.sin(s/510)*175+Math.sin(s/1280)*250+(s>4300?Math.sin((s-4300)/220)*70:0);
const elevation=(s:number)=>Math.sin(s/620)*42+(s>1550&&s<2750?Math.sin((s-1550)/1200*Math.PI)*150:0)+(s>3150&&s<4250?Math.sin((s-3150)/1100*Math.PI)*-90:0)+(s>5100&&s<6200?Math.sin((s-5100)/1100*Math.PI)*110:0);
const sectionFor=(s:number)=>[...SECTIONS].reverse().find((section)=>s>=section.at)??SECTIONS[0];

function seeded(index:number,seed:number){const x=Math.sin(index*9283.31+seed*77.1)*43758.5453;return x-Math.floor(x)}

export function Race3D({animal,hero,difficulty,sound,haptics,reducedMotion,onFinish}:Props){
  const canvasRef=useRef<HTMLCanvasElement>(null);
  const keys=useRef<Record<string,boolean>>({});
  const [view,setView]=useState({rank:25,time:0,speed:0,progress:0,skillCd:5,item:null as ItemKey,flash:"출발 보호 · 스킬 5초 잠금",section:SECTIONS[0].name});
  const seed=useRef(Math.floor(Math.random()*9999));
  const game=useRef({
    s:0,lateral:0,speed:CRUISE_SPEED,jump:0,vJump:0,time:0,skillCd:5,boost:0,shield:0,phase:0,hit:0,bumps:0,item:null as ItemKey,flash:"출발 보호 · 스킬 5초 잠금",finished:false,
    crossed:new Set<number>(),
    ai:Array.from({length:49},(_,i)=>({s:((i%10)-5)*12-Math.floor(i/10)*9,lateral:((i%7)-3)*86,speed:298+seeded(i,seed.current)*18,stun:0,phase:seeded(i+80,seed.current)*6.28,itemCd:6+seeded(i+110,seed.current)*7,crossed:new Set<number>(),emoji:EMOJIS[i%EMOJIS.length]})),
    // Four hazards share each arena row, leaving several readable escape routes.
    obstacles:Array.from({length:60},(_,i)=>({id:i,s:520+Math.floor(i/4)*475+seeded(i,seed.current)*72,lateral:((i*3+Math.floor(seeded(i+30,seed.current)*3))%7-3)*90,type:["log","spinner","mud","ball","ramp"][Math.floor(seeded(i+90,seed.current)*5)]})),
    boxes:Array.from({length:18},(_,i)=>({id:i,s:760+Math.floor(i/3)*1080+seeded(i+4,seed.current)*90,lateral:((i*2)%7-3)*90,taken:false})),
    bananas:[] as {s:number,lateral:number,life:number,owner:"player"|"ai"}[],
  });
  const feedback=useCallback((frequency:number,duration=.1)=>{
    if(haptics&&frequency<220&&navigator.vibrate)navigator.vibrate(Math.round(duration*220));
    if(!sound)return;
    const ctx=new AudioContext();const osc=ctx.createOscillator();const gain=ctx.createGain();osc.type="square";osc.frequency.value=frequency;gain.gain.setValueAtTime(.035,ctx.currentTime);gain.gain.exponentialRampToValueAtTime(.001,ctx.currentTime+duration);osc.connect(gain);gain.connect(ctx.destination);osc.start();osc.stop(ctx.currentTime+duration);
  },[haptics,sound]);

  const useSkill=useCallback(()=>{
    const g=game.current;if(g.skillCd>0){g.flash=`출발 보호 · ${g.skillCd.toFixed(1)}초 후 사용`;return;}
    if(animal==="dog"){g.boost=1.6;g.flash="🐶 균형 질주 +10%";}
    if(animal==="rabbit"){g.vJump=330;g.jump=Math.max(g.jump,10);g.s+=35;g.flash="🐰 도약 추진 +35m";}
    if(animal==="elephant"){g.shield=2;g.flash="🐘 충돌 1회 방어";}
    if(animal==="cat"){g.phase=1.8;g.flash="🐱 1.8초 장애물 통과";}
    g.skillCd=SKILLS[animal].cooldown;feedback(260,.12);
  },[animal,feedback]);

  const useItem=useCallback(()=>{
    const g=game.current;if(!g.item)return;
    if(g.item==="banana"){g.bananas.push({s:g.s-30,lateral:g.lateral,life:7,owner:"player"});g.flash="🍌 뒤에 바나나 설치";}
    if(g.item==="shield"){g.shield=3.2;g.flash="🐢 충돌 1회 방어";}
    if(g.item==="magnet"){g.s+=80;g.flash="🧲 안전 견인 +80m";}
    if(g.item==="ink"){game.current.ai.filter(a=>a.s>g.s).sort((a,b)=>a.s-b.s).slice(0,6).forEach(a=>a.stun=1.1);g.flash="🦑 앞선 6마리 시야 방해";}
    g.item=null;feedback(420,.1);
  },[feedback]);

  const jump=useCallback(()=>{const g=game.current;if(g.jump<=1){g.vJump=285;feedback(640,.07)}else if(animal==="rabbit"&&g.jump<75&&g.vJump<80){g.vJump=245;g.s+=25;g.flash="🐰 이단 점프 +25m";feedback(850,.07)}},[animal,feedback]);

  useEffect(()=>{
    const down=(e:KeyboardEvent)=>{keys.current[e.key.toLowerCase()]=true;if(e.key===" "){e.preventDefault();jump()}if(e.key.toLowerCase()==="e")useSkill();if(e.key.toLowerCase()==="q")useItem()};
    const up=(e:KeyboardEvent)=>{keys.current[e.key.toLowerCase()]=false};window.addEventListener("keydown",down);window.addEventListener("keyup",up);return()=>{window.removeEventListener("keydown",down);window.removeEventListener("keyup",up)};
  },[jump,useItem,useSkill]);

  useEffect(()=>{
    const canvas=canvasRef.current;if(!canvas)return;const ctx=canvas.getContext("2d");if(!ctx)return;
    let frame=0,last=performance.now(),lastUi=0;
    const project=(worldX:number,worldY:number,worldS:number,w:number,h:number)=>{
      const g=game.current;const dz=worldS-g.s+150;const sectionIndex=SECTIONS.findIndex(v=>v.name===sectionFor(g.s).name);const speedFov=Math.max(0,Math.min(52,g.speed-CRUISE_SPEED))*.72;const focal=[470,410,535,445,490][sectionIndex]-speedFov;const scale=focal/Math.max(80,dz+focal);const tangent=(center(g.s+15)-center(g.s))/15;const relativeX=worldX-center(g.s)-tangent*(worldS-g.s)-g.lateral*.32;const horizon=h*[.32,.27,.37,.33,.3][sectionIndex];return{x:w/2+relativeX*scale*(w/920),y:horizon+h*.55*scale-(worldY-elevation(g.s))*scale*(h/520),scale,visible:dz>25&&dz<2100};
    };
    const draw=(w:number,h:number)=>{
      const g=game.current;const section=sectionFor(g.s);const gradient=ctx.createLinearGradient(0,0,0,h);gradient.addColorStop(0,section.sky[0]);gradient.addColorStop(.55,section.sky[1]);gradient.addColorStop(.56,section.ground);gradient.addColorStop(1,"#183c35");ctx.fillStyle=gradient;ctx.fillRect(0,0,w,h);
      ctx.save();if(!reducedMotion){const bank=Math.sin(g.s/700)*.025;ctx.translate(w/2,h/2);ctx.rotate(bank);ctx.translate(-w/2,-h/2)}
      if(!reducedMotion){ctx.save();ctx.globalAlpha=.2+Math.min(.25,Math.max(0,(g.speed-250)/300));ctx.strokeStyle="#ffffff";ctx.lineWidth=3;for(let i=0;i<18;i++){const side=i%2?-1:1;const y=h*.44+((g.s*1.9+i*83)%(h*.6));const spread=(y-h*.35)/(h*.65);const x=w/2+side*(w*.4+spread*w*.24);ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x+side*(18+spread*42),y+30+spread*34);ctx.stroke()}ctx.restore()}
      ctx.globalAlpha=.35;ctx.fillStyle="#fff";for(let i=0;i<7;i++){const x=(i*211-g.s*.05)%(w+240)-100;ctx.beginPath();ctx.ellipse(x,70+(i%3)*42,65,20,0,0,Math.PI*2);ctx.fill()}ctx.globalAlpha=1;
      for(let d=2050;d>=0;d-=48){const s1=g.s+d,s2=s1+54,c1=center(s1),c2=center(s2),e1=elevation(s1),e2=elevation(s2);const a=project(c1-TRACK_WIDTH/2,e1,s1,w,h),b=project(c1+TRACK_WIDTH/2,e1,s1,w,h),c=project(c2+TRACK_WIDTH/2,e2,s2,w,h),d2=project(c2-TRACK_WIDTH/2,e2,s2,w,h);ctx.fillStyle=Math.floor(s1/96)%2?"#8a6c61":"#96796c";ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.lineTo(c.x,c.y);ctx.lineTo(d2.x,d2.y);ctx.closePath();ctx.fill();ctx.strokeStyle="rgba(255,255,255,.28)";ctx.lineWidth=Math.max(1,a.scale*2);[-.6,-.2,.2,.6].forEach(l=>{const p1=project(c1+l*TRACK_WIDTH/2,e1+1,s1,w,h),p2=project(c2+l*TRACK_WIDTH/2,e2+1,s2,w,h);ctx.beginPath();ctx.moveTo(p1.x,p1.y);ctx.lineTo(p2.x,p2.y);ctx.stroke()});}
      const objects:[number,()=>void][]=[];
      g.obstacles.forEach(o=>{const p=project(center(o.s)+o.lateral,elevation(o.s),o.s,w,h);if(!p.visible)return;objects.push([o.s,()=>{ctx.font=`${Math.max(13,58*p.scale)}px sans-serif`;ctx.textAlign="center";ctx.fillText(o.type==="log"?"🪵":o.type==="spinner"?"🌀":o.type==="mud"?"🟤":o.type==="ball"?"🪨":"🔺",p.x,p.y)}])});
      g.boxes.filter(b=>!b.taken).forEach(b=>{const p=project(center(b.s)+b.lateral,elevation(b.s)+12,b.s,w,h);if(p.visible)objects.push([b.s,()=>{ctx.fillStyle="#ff4f9b";ctx.strokeStyle="#17152f";ctx.lineWidth=Math.max(1,3*p.scale);const size=42*p.scale;ctx.fillRect(p.x-size/2,p.y-size,size,size);ctx.strokeRect(p.x-size/2,p.y-size,size,size);ctx.fillStyle="#fff";ctx.font=`bold ${25*p.scale}px sans-serif`;ctx.fillText("?",p.x,p.y-size*.18)}])});
      g.bananas.forEach(b=>{const p=project(center(b.s)+b.lateral,elevation(b.s),b.s,w,h);if(p.visible)objects.push([b.s,()=>{ctx.font=`${35*p.scale}px sans-serif`;ctx.fillText("🍌",p.x,p.y)}])});
      g.ai.forEach((a,i)=>{const p=project(center(a.s)+a.lateral,elevation(a.s),a.s,w,h);if(!p.visible||p.scale<.12)return;objects.push([a.s,()=>{ctx.font=`${Math.max(12,47*p.scale)}px sans-serif`;ctx.fillText(a.emoji,p.x,p.y);if(Math.abs(a.s-g.s)<120){ctx.fillStyle="rgba(24,22,50,.85)";ctx.fillRect(p.x-12,p.y-43*p.scale,24,10);ctx.fillStyle="#fff";ctx.font="7px sans-serif";ctx.fillText(String(i+2),p.x,p.y-35*p.scale)}}])});
      objects.sort((a,b)=>b[0]-a[0]).forEach(([,fn])=>fn());
      const playerY=h*.82-g.jump*.55;ctx.font=`${Math.max(58,w*.068)}px sans-serif`;ctx.textAlign="center";ctx.shadowColor="rgba(0,0,0,.25)";ctx.shadowBlur=10;ctx.fillText(hero,w/2,playerY);ctx.shadowBlur=0;ctx.fillStyle="#dfff45";ctx.strokeStyle="#17152f";ctx.lineWidth=2;ctx.fillRect(w/2-22,playerY-72,44,15);ctx.strokeRect(w/2-22,playerY-72,44,15);ctx.fillStyle="#17152f";ctx.font="bold 9px sans-serif";ctx.fillText("YOU",w/2,playerY-61);
      if(g.phase>0){ctx.strokeStyle="#66ffff";ctx.lineWidth=5;ctx.beginPath();ctx.arc(w/2,playerY-28,48,0,Math.PI*2);ctx.stroke()}ctx.restore();
      const fog=ctx.createLinearGradient(0,h*.22,0,h*.55);fog.addColorStop(0,"rgba(255,255,255,.48)");fog.addColorStop(1,"rgba(255,255,255,0)");ctx.fillStyle=fog;ctx.fillRect(0,h*.2,w,h*.38);
    };
    const loop=(now:number)=>{const g=game.current;const dt=Math.min(.035,(now-last)/1000);last=now;if(g.finished)return;g.time+=dt;g.skillCd=Math.max(0,g.skillCd-dt);g.boost=Math.max(0,g.boost-dt);g.shield=Math.max(0,g.shield-dt);g.phase=Math.max(0,g.phase-dt);g.hit=Math.max(0,g.hit-dt);
      const steer=(keys.current["d"]||keys.current["arrowright"]?1:0)-(keys.current["a"]||keys.current["arrowleft"]?1:0);g.lateral+=steer*360*dt;g.lateral=Math.max(-TRACK_WIDTH*.46,Math.min(TRACK_WIDTH*.46,g.lateral));const accelerate=keys.current["w"]||keys.current["arrowup"];const brake=keys.current["s"]||keys.current["arrowdown"];let target=accelerate?SPRINT_SPEED:CRUISE_SPEED;if(brake)target=BRAKE_SPEED;if(g.boost>0)target*=1.1;if(g.hit>0)target*=.72;g.speed+=(target-g.speed)*dt*4.4;g.s+=g.speed*dt;
      g.vJump-=620*dt;g.jump=Math.max(0,g.jump+g.vJump*dt);if(g.jump===0&&g.vJump<0)g.vJump=0;
      g.obstacles.forEach(o=>{if(g.crossed.has(o.id))return;if(Math.abs(g.s-o.s)<28&&Math.abs(g.lateral-o.lateral)<52){g.crossed.add(o.id);if(o.type==="ramp"){g.vJump=310;g.flash="🔺 램프 점프!"}else if(g.jump<26&&g.phase<=0){if(g.shield>0){g.shield=0;g.flash="방어 성공!"}else{g.hit=.65;g.speed*=.72;g.bumps++;g.flash=`${o.type==="mud"?"진흙탕":"장애물"} 충돌!`;feedback(130,.16)}}}});
      g.boxes.forEach((b,i)=>{if(!b.taken&&Math.abs(g.s-b.s)<30&&Math.abs(g.lateral-b.lateral)<54){b.taken=true;const pool:Exclude<ItemKey,null>[]=g.ai.filter(a=>a.s>g.s).length>30?["shield","magnet","ink","magnet"]:["banana","shield","ink","magnet"];g.item=pool[i%pool.length];g.flash=`${ITEMS[g.item]} 아이템 획득`;feedback(920,.08)}});
      g.ai.forEach((a,i)=>{a.stun=Math.max(0,a.stun-dt);a.itemCd=Math.max(0,a.itemCd-dt);const diff=difficulty==="wild"?.985:difficulty==="nightmare"?1.018:1;let pace=a.speed*diff;if(a.s<g.s-500)pace*=1.035;if(a.s>g.s+500)pace*=.97;if(a.stun>0)pace*=.45;a.s+=pace*dt;a.lateral+=Math.sin(g.time*.9+a.phase)*18*dt;g.obstacles.forEach(o=>{if(!a.crossed.has(o.id)&&Math.abs(a.s-o.s)<24){a.crossed.add(o.id);if(Math.abs(a.lateral-o.lateral)<48&&o.type!=="ramp")a.stun=.38+seeded(i+o.id,seed.current)*.28}});if(a.s>g.s+45&&a.s<g.s+260&&a.itemCd<=0&&i%5===0){g.bananas.push({s:a.s-35,lateral:a.lateral,life:6,owner:"ai"});a.itemCd=9+seeded(i+Math.floor(g.time),seed.current)*5;g.flash=`${a.emoji}가 앞에 바나나 설치!`;}if(Math.abs(a.s-g.s)<25&&Math.abs(a.lateral-g.lateral)<38&&g.jump<20&&g.phase<=0){g.lateral+=Math.sign(g.lateral-a.lateral||1)*28;g.speed*=.94;g.bumps++;if(i%8===0)g.flash=`${a.emoji}와 어깨 충돌!`}});
      g.bananas.forEach(b=>{b.life-=dt;if(b.owner==="player")g.ai.forEach(a=>{if(Math.abs(a.s-b.s)<22&&Math.abs(a.lateral-b.lateral)<35){a.stun=.65;b.life=0}});else if(Math.abs(g.s-b.s)<22&&Math.abs(g.lateral-b.lateral)<35&&g.jump<18&&g.phase<=0){b.life=0;if(g.shield>0){g.shield=0;g.flash="방어막으로 바나나 차단!"}else{g.hit=.5;g.speed*=.82;g.bumps++;g.flash="🍌 AI 바나나에 미끄러짐!";feedback(120,.14)}}});g.bananas=g.bananas.filter(b=>b.life>0);
      const rank=1+g.ai.filter(a=>a.s>g.s).length;const canvasRect=canvas.getBoundingClientRect();const dpr=Math.min(2,window.devicePixelRatio||1);if(canvas.width!==Math.floor(canvasRect.width*dpr)||canvas.height!==Math.floor(canvasRect.height*dpr)){canvas.width=Math.floor(canvasRect.width*dpr);canvas.height=Math.floor(canvasRect.height*dpr)}ctx.setTransform(dpr,0,0,dpr,0,0);draw(canvasRect.width,canvasRect.height);
      if(now-lastUi>60){lastUi=now;setView({rank,time:g.time,speed:g.speed,progress:Math.min(1,g.s/LENGTH),skillCd:g.skillCd,item:g.item,flash:g.flash,section:sectionFor(g.s).name});if(g.flash&&Math.floor(g.time*10)%25===0)g.flash=""}
      if(g.s>=LENGTH){g.finished=true;onFinish(rank,g.time,g.bumps);feedback(980,.25);return}frame=requestAnimationFrame(loop)};
    frame=requestAnimationFrame(loop);return()=>cancelAnimationFrame(frame);
  },[animal,difficulty,feedback,hero,onFinish,reducedMotion]);

  const press=(key:string,value:boolean)=>{keys.current[key]=value};
  return <section className="race3d-page">
    <canvas ref={canvasRef} className="race3d-canvas" aria-label="뒤에서 바라보는 3D 동물 레이싱 코스"/>
    <div className="race3d-hud"><div className="race3d-rank"><small>POSITION</small><b>{view.rank}<sup>위</sup></b><span>/ 50</span></div><div className="race3d-progress"><span>{view.section}</span><i><em style={{width:`${view.progress*100}%`}}/></i><small>입체 코스 · 커브 · 고저차</small></div><div className="race3d-speed"><b>{Math.round(view.speed)}</b><small>KM/H</small></div></div>
    <div className="camera-badge">🎥 DYNAMIC CHASE CAM</div>
    {view.flash&&<div className="race3d-flash">{view.flash}</div>}
    <div className="race3d-bottom"><div className="race3d-skill"><span>{animal==="dog"?"🐶":animal==="rabbit"?"🐰":animal==="elephant"?"🐘":"🐱"}</span><div><small>E · {view.skillCd>0&&view.time<5?"START LOCK":"ACTIVE"}</small><b>{SKILLS[animal].name}</b><i><em style={{width:`${Math.max(0,100-view.skillCd/SKILLS[animal].cooldown*100)}%`}}/></i></div><strong>{view.skillCd>0?view.skillCd.toFixed(1):"READY"}</strong></div><button className="race3d-item" onClick={useItem}><small>Q · ITEM</small><b>{view.item?ITEMS[view.item]:"?"}</b></button></div>
    <div className="race3d-controls"><div><button onPointerDown={()=>press("a",true)} onPointerUp={()=>press("a",false)} onPointerCancel={()=>press("a",false)}>◀</button><button onPointerDown={()=>press("d",true)} onPointerUp={()=>press("d",false)} onPointerCancel={()=>press("d",false)}>▶</button></div><button onPointerDown={()=>press("w",true)} onPointerUp={()=>press("w",false)} onPointerCancel={()=>press("w",false)}>가속</button><button onClick={jump}>점프</button><button onClick={useSkill}>스킬</button><button onClick={useItem}>아이템</button></div>
  </section>;
}
