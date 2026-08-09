"use client";

import { useEffect, useState } from "react";

const STEPS = [
  { icon:"↕", title:"차선을 바꿔보세요", copy:"PC는 W/S 또는 방향키, 모바일은 위·아래 버튼을 사용해요.", keys:["w","s","arrowup","arrowdown"], action:"MOVE" },
  { icon:"⬆", title:"장애물을 점프하세요", copy:"통나무와 바나나는 뛰어넘을 수 있어요.", keys:[" "], action:"JUMP" },
  { icon:"⚡", title:"동물 스킬을 사용하세요", copy:"각 동물의 스킬은 강하지만 재사용 대기시간이 있어요.", keys:["e"], action:"SKILL" },
  { icon:"🎁", title:"아이템을 사용하세요", copy:"아이템은 역할과 레벨이 달라요. 순위에 맞는 타이밍이 중요해요.", keys:["q"], action:"ITEM" },
] as const;

export function Tutorial({ hero, onDone }: { hero:string; onDone:()=>void }) {
  const [step,setStep]=useState(0); const [flash,setFlash]=useState(false);
  const advance=()=>{setFlash(true);setTimeout(()=>{setFlash(false);if(step>=STEPS.length-1){try{localStorage.setItem("wild-dash-tutorial","done")}catch { /* local storage is optional */ }onDone();}else setStep((v)=>v+1);},350)};
  useEffect(()=>{const key=(e:KeyboardEvent)=>{if(STEPS[step].keys.includes(e.key.toLowerCase() as never))advance()};window.addEventListener("keydown",key);return()=>window.removeEventListener("keydown",key)},[step]);
  const current=STEPS[step];
  return <section className="tutorial-page"><button className="tutorial-skip" onClick={onDone}>건너뛰기 →</button><div className="tutorial-copy"><p>30초 훈련소 · {step+1}/{STEPS.length}</p><h2>{current.title}</h2><span>{current.copy}</span></div><div className={`training-ground ${flash?"success":""}`}><div className="training-lanes"><i/><i/></div><div className="training-obstacle">{step===0?"↕":step===1?"🪵":step===2?"🦊":"🎁"}</div><div className="training-hero"><span>{hero}</span><b>YOU</b></div>{flash&&<div className="training-good">GOOD!</div>}</div><div className="tutorial-action"><button onClick={advance}><b>{current.icon}</b><span>{current.action}</span><small>{step===0?"W / S":step===1?"SPACE":step===2?"E":"Q"}</small></button></div><div className="tutorial-dots">{STEPS.map((_,i)=><i key={i} className={i<=step?"active":""}/>)}</div></section>;
}
