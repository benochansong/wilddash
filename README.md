# WILD DASH 50 — Prototype V1

WILD DASH 50은 **Windows PC에서 오프라인으로 실행하는 로컬 동물 파티 레이싱 프로토타입**입니다.
현재 버전은 온라인 멀티플레이 게임이 아니며, **플레이어 1명 + AI 경쟁자 49마리**가 경쟁합니다.

화면은 React + Canvas 2D로 만든 원근 연출 레이싱 화면이며 Unity/Godot/Three.js 기반의 실제 3D 엔진 게임은 아닙니다.

## Prototype V1 플레이 흐름

```text
Lobby
→ Character Select
→ Countdown
→ Race (Round 1)
→ Round Break
→ Fruit Arena (Round 2)
→ Round Break
→ Survival Arena (Round 3)
→ Round Break
→ Final Push-out Arena (Round 4)
→ Result
→ Lobby / 다시 출전
```

실패하면 해당 라운드에서 Result 화면으로 이동합니다.

### Round 1 — Wild Grand Prix

- 플레이어 1명 + 로컬 AI 경쟁자 49마리
- 장애물, 아이템 박스, 바나나, 점프, 동물 스킬
- 상위 25위 안에 들어오면 Round 2 진출
- Canvas 2D 기반 원근 연출 코스

### Round 2 — 과일 바구니 쟁탈전

- 과일 8개 획득 시 통과
- AI와 같은 공간에서 과일을 경쟁

### Round 3 — 바닥 붕괴 생존 지대

- 무너지는 타일을 피하며 제한 시간 생존
- 하트가 모두 소진되면 탈락

### Round 4 — 끝장 밀어내기 아레나

- 경쟁자를 링 밖으로 밀어내는 최종 라운드
- 마지막까지 살아남으면 우승

## 캐릭터와 키메라

베이스 동물은 다음 4종입니다.

- 강아지 — 질주형
- 토끼 — 점프/도약형
- 코끼리 — 방어/밀치기형
- 고양이 — 회피/교란형

키메라 연구소에서 머리, 몸통, 꼬리 파츠를 조합할 수 있습니다.
비주얼 파츠는 충돌 판정이나 능력치에 영향을 주지 않으며, 실제 성능은 선택한 베이스 동물로 결정됩니다.

## 난이도

- Wild
- Chaos
- Nightmare

난이도에 따라 AI 속도, 공격성, 충돌 압력이 달라집니다.

## 조작

| 기능 | 키 |
| --- | --- |
| 이동/조향 | WASD / 방향키 |
| 점프 | Space |
| 동물 스킬 | E |
| 아이템 | Q |

## 저장되는 데이터

게임 데이터는 이 PC의 `localStorage`에 버전이 포함된 형태로 저장됩니다.

- 팬 수
- 우승 횟수
- 최고 순위
- 설정
- 튜토리얼 완료 여부
- 향후 캐릭터 해금 데이터 영역
- 향후 기록 데이터 영역

기존 Prototype 저장 데이터는 SaveManager가 가능한 범위에서 v1 형식으로 마이그레이션합니다.
손상된 저장 데이터나 저장 실패가 발생해도 게임 실행 자체가 중단되지 않도록 기본값 복구를 사용합니다.

## 현재 오디오

현재 Prototype V1에는 별도 BGM 파일이 없습니다.
효과음은 중앙 `AudioManager`가 하나의 Web Audio `AudioContext`를 재사용해 생성하는 간단한 SFX입니다.
향후 WAV/OGG 파일을 등록할 수 있는 구조만 준비되어 있습니다.

## 기술 구조

```text
game/
  audio/       AudioManager
  input/       InputManager
  config/      동물, 아이템, 난이도, 레이스 설정
  systems/     AI, 충돌, 아이템, 스킬, 랭킹, 라운드, 진행 흐름
  save/        버전형 SaveManager
  types/       공용 게임 타입

ui/
  components/  재사용 UI 컴포넌트

app/
  page.tsx     상위 화면/상태 연결
  Race3D.tsx   Canvas 원근 레이스
  ArenaRound.tsx
  Tutorial.tsx
```

## 개발 환경

Node.js **22.13.0 이상**이 필요합니다.

```powershell
npm ci
npm run desktop:dev
```

웹 개발 화면만 실행하려면:

```powershell
npm run dev
```

## 검증

```powershell
npm run typecheck
npm run lint
npm test
npm run build
npm run test:desktop
```

`npm test`는 게임 규칙, 입력, 오디오, 저장 migration, Prototype 화면 흐름과 lifecycle 정리를 검사합니다.

## Windows 설치 프로그램

```powershell
npm run dist:win
```

완료되면 다음과 같은 NSIS 설치 파일이 생성됩니다.

```text
release/WILD-DASH-50-Setup-1.0.0.exe
```

설치 후 시작 메뉴 또는 바탕 화면의 **WILD DASH 50** 바로가기로 실행할 수 있습니다.

## GitHub Actions CI

Pull Request와 `main` push에서 자동으로 다음을 검사합니다.

1. `npm ci`
2. TypeScript typecheck
3. ESLint
4. unit test
5. Vite production build
6. desktop build shell 검증
7. Windows runner에서 NSIS installer 생성 및 artifact 업로드

## Prototype V1의 범위 밖

현재 버전에 포함되지 않는 기능입니다.

- 온라인 멀티플레이
- 네트워크 매치메이킹
- 서버 계정/로그인
- 실제 3D 엔진
- 실제 BGM 트랙
- 정식 게임패드 지원
- 클라우드 저장

이 저장소의 React/Electron 버전은 **게임 규칙과 UX를 검증하기 위한 Prototype V1**으로 유지하고, 향후 실제 3D 버전은 Godot 등 별도 엔진으로 이전하는 것을 전제로 합니다.

Prototype V1 readiness와 Godot 이전 시 재사용/폐기 범위는 `docs/PROTOTYPE_V1_READINESS.md`를 참고하세요.
