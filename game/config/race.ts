import type { AnimalKey } from "../types/game";

export const TRACK_LENGTH = 4400;
export const LANES = [96, 176, 256] as const;
export const AI_EMOJIS = ["🦊", "🐼", "🐷", "🐸", "🦁", "🐵", "🐯", "🦝", "🐻", "🐨", "🦄", "🐮", "🐹", "🦓", "🦒", "🐺", "🦔", "🐲", "🦧", "🐙", "🦈", "🦖"] as const;

export const OBSTACLES = [
  { x: 720, lane: 0, kind: "log" }, { x: 720, lane: 2, kind: "log" },
  { x: 1190, lane: 1, kind: "mud" }, { x: 1600, lane: 0, kind: "log" },
  { x: 1600, lane: 1, kind: "log" }, { x: 2140, lane: 2, kind: "mud" },
  { x: 2530, lane: 0, kind: "log" }, { x: 2530, lane: 2, kind: "log" },
  { x: 3110, lane: 1, kind: "mud" }, { x: 3570, lane: 0, kind: "log" },
  { x: 3570, lane: 1, kind: "log" },
] as const;

export const BOXES = [930, 1880, 2780, 3770] as const;
export const SWEEPERS = [1380, 2320, 3380, 4010] as const;

export const ROUTES: { x: number; lane: number; animal: AnimalKey; icon: string; label: string }[] = [
  { x: 1080, lane: 0, animal: "rabbit", icon: "☁️", label: "토끼 이단 점프 길" },
  { x: 1970, lane: 2, animal: "dog", icon: "⚡", label: "강아지 질주 레인" },
  { x: 2860, lane: 1, animal: "elephant", icon: "🧱", label: "코끼리 파괴 벽" },
  { x: 3650, lane: 0, animal: "cat", icon: "🕳️", label: "고양이 비밀 통로" },
];

export const RACE3D_LENGTH = 24000;
export const RACE3D_TRACK_WIDTH = 680;
export const RACE3D_CRUISE_SPEED = 1525;
export const RACE3D_SPRINT_SPEED = 1775;
export const RACE3D_BRAKE_SPEED = 1025;
export const RACE3D_AI_EMOJIS = AI_EMOJIS;

export const RACE3D_SECTIONS = [
  { at: 0, name: "초원 스타디움", sky: ["#53d6ff", "#d7fff1"], ground: "#59b96a" },
  { at: 4800, name: "구불구불 캐니언", sky: ["#ff9e6b", "#ffe2a9"], ground: "#d66f45" },
  { at: 9600, name: "빙글빙글 설산", sky: ["#77cfff", "#effcff"], ground: "#d7f6ff" },
  { at: 14400, name: "정글 터널", sky: ["#42b887", "#baf39f"], ground: "#237b55" },
  { at: 19200, name: "네온 결승 도시", sky: ["#4b3fb7", "#ef70b8"], ground: "#413584" },
] as const;
