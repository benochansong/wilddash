# WILD DASH 3D — Four Round Architecture

이 문서는 React/Electron Prototype의 4개 라운드를 Godot 3D로 옮길 때 사용하는 현재 구조와 안정화 기준을 기록합니다.

## 개발 원칙

- React 코드를 그대로 번역하지 않는다.
- 기존 Prototype의 규칙과 재미 요소만 참고하고 Godot의 Scene / CharacterBody3D / physics 구조에 맞게 다시 설계한다.
- 각 라운드는 독립 Scene + 전용 ModeController를 가진다.
- Player / AI / Input / Audio / Result / GameManager는 공유한다.
- 현재 AI 수는 최소 4, 최대 10으로 강제한다.
- 4개 라운드가 모두 안정화되기 전에는 50 racers로 확장하지 않는다.

`GameManager.MAX_AI_COUNT`가 10으로 잠겨 있기 때문에 환경변수나 호출자가 더 큰 값을 요청해도 현재 단계에서는 10을 넘지 않는다.

## Scene 구성

```text
res://scenes/main.tscn
  Campaign bootstrap

res://modes/grand_prix/grand_prix.tscn
  Round 1 — Wild World Grand Prix

res://modes/fruit_collection/fruit_collection.tscn
  Round 2 — Fruit Collection

res://modes/floor_collapse/floor_collapse.tscn
  Round 3 — Floor Collapse Survival

res://modes/push_out/push_out.tscn
  Final — Push-Out Arena

res://scenes/result.tscn
  Shared four-round result
```

`main.tscn`은 게임 규칙을 직접 갖지 않고 캠페인을 시작하는 bootstrap 역할만 한다.

## 공유 시스템

### GameManager

- 라운드 순서 관리
- Scene 전환
- 현재 round state
- AI 수 4~10 clamp
- 각 ModeController의 완료 결과를 ResultManager로 전달

### Player

공통 `WildDashCharacterController`를 사용한다.

두 가지 movement mode를 지원한다.

- `RACE`: 전방 주행, 조향, 점프, 장애물 collision
- `ARENA`: 자유 평면 이동, knockback, arena action

라운드마다 별도 Player 코드를 복사하지 않는다.

### AI

공통 `WildDashAIController`를 사용한다.

- `RACE`: racing lane, obstacle ray, avoidance, jump, stuck recovery
- `ARENA`: ModeController가 정한 target을 향해 실제 CharacterBody3D로 이동

중요한 경계는 **AI의 이동은 공유하지만, 무엇을 목표로 삼을지는 라운드 규칙이 결정한다**는 것이다.

예:

- Fruit Collection: ModeController가 가장 가까운 과일을 target으로 지정
- Floor Collapse: ModeController가 살아 있는 안전 타일을 target으로 지정
- Push-Out: ModeController가 플레이어 주변을 target으로 지정하고 body-check 판정 수행

### Input

공통 InputManager가 W/A/S/D, 방향키, Space, E, Q 입력을 관리한다.

- Race에서는 steer/throttle/jump로 사용
- Arena에서는 2D move vector와 arena action으로 사용

### Audio

기존 공통 AudioManager를 유지한다. 라운드 전용 Controller가 AudioStreamPlayer를 직접 난립시키지 않는 것을 원칙으로 한다.

### Result

공통 ResultManager가 각 라운드의:

- mode id
- clear/miss
- score
- details

를 저장하며 마지막 `result.tscn`에서 요약한다.

## Round 1 — Wild World Grand Prix

현재 Vertical Slice의 3D race 기반을 재사용하되 독립 Mode Scene으로 이동했다.

구현 요소:

- 실제 CharacterBody3D race
- chase camera
- 실제 장애물 / ramp collision
- finish line Area3D
- live rank
- AI racing
- 모든 racer finish order 기록

4 AI에서 기존 안전 racing lane을 기반으로 안정화했고, 추가 AI는 outer safe lane + staggered grid를 사용한다.

10 AI 검증에서는 Player 1 + AI 10 = 총 11 racers가 모두 결승선을 통과했다.

## Round 2 — Fruit Collection

React Prototype의 핵심 재미 요소인 “제한 시간 안에 과일을 먼저 확보하고 AI에게 뺏기지 않는다”를 3D arena 규칙으로 재설계했다.

현재 규칙:

- 과일 12개
- 플레이어 목표 8개
- 과일 respawn
- AI가 실제 arena를 이동하며 가장 가까운 과일을 탐색
- AI도 과일을 획득하고 점수를 가진다
- 플레이어가 8개를 먼저 모으면 clear
- AI가 먼저 8개에 도달하거나 시간이 끝나면 miss

CI는 `FRUIT AI PICKUP` 이벤트를 요구하므로 Scene이 타이머만 돌고 끝나는 것이 아니라 AI의 실제 이동 + 획득까지 검증한다.

## Round 3 — Floor Collapse Survival

React Prototype의 6×5 타일 / 3 hearts / 단계적 붕괴 아이디어를 Godot physics로 재구성했다.

현재 규칙:

- 6×5 = 30개의 실제 StaticBody3D tile
- phase마다 일부 tile collision 비활성화
- 다음 위험 타일 시각 경고
- 플레이어 3 hearts
- 추락 시 heart 감소 + 안전 타일 respawn
- AI는 살아 있는 tile을 target으로 이동
- 제한 시간을 버티면 clear

CI는 여러 `FLOOR PHASE` 진행을 확인한다.

## Final — Push-Out Arena

원형 실제 collision arena에서 knockback 경쟁을 구현한다.

현재 규칙:

- 원형 CSG collision ring
- Space / E: 플레이어 push action
- 범위 안 AI에 실제 knockback 적용
- AI는 플레이어를 추적하고 cooldown 기반 body-check 수행
- arena 반경 밖 또는 아래로 떨어지면 탈락
- 모든 AI를 밀어내면 clear
- 플레이어가 먼저 이탈하거나 제한 시간 종료 시 miss

CI는 `PUSH OUT AI BODY CHECK` 이벤트를 요구하므로 AI가 단순 이동만 하는 것이 아니라 실제 밀치기 상호작용까지 검증한다.

## AI 규모 안정화 게이트

현재 자동 검증은 두 단계로 실행한다.

### 4 AI baseline

- Player 1 + AI 4
- 4개 Scene 순차 실행
- Grand Prix 전원 완주
- Fruit AI 실제 pickup
- Floor Collapse phase 진행
- Push-Out AI body-check
- Result Scene 도달

### 10 AI stress

- Player 1 + AI 10
- Grand Prix 11 racers 전원 완주
- Fruit AI pickup
- Floor Collapse
- Push-Out interaction
- Result Scene까지 전체 lifecycle 완료

2026-08-09 GitHub Actions에서 4 AI와 10 AI 두 검증 단계가 모두 성공했다.

Headless 테스트에서는 사용자 입력이 없기 때문에 Player가 Grand Prix / Fruit / Push-Out에서 miss가 나올 수 있다. 이것은 자동 입력이 없는 smoke/stress run의 정상 결과이며, CI 성공 기준은 각 모드의 물리·AI·규칙 이벤트와 전체 lifecycle이 멈추지 않고 완료되는 것이다.

## 50 racers를 아직 하지 않는 이유

현재 4~10 AI 단계는 **게임 규칙의 3D 재구성 및 물리 안정화 단계**다.

50 racers로 바로 확장하면 다음 문제가 동시에 섞인다.

- CharacterBody3D collision 밀도
- AI avoidance 비용
- crowd navigation
- animation 비용
- draw call / shadow 비용
- 라운드별 target contention
- push-out mass collision

따라서 다음 순서를 유지한다.

```text
4 AI 안정화
→ 10 AI stress 안정화
→ Windows 직접 playtest
→ 각 라운드 조작감/카메라/규칙 튜닝
→ 10~20 중간 규모 profiling
→ 그 이후에만 50 racers 검토
```

현재 코드에서는 50 AI 확장을 허용하지 않는다.

## 다음 품질 단계

기능 수를 늘리기 전에 Windows에서 다음을 직접 확인한다.

1. Round 1 조향/점프/카메라 재미
2. Round 2 과일을 쫓고 빼앗기는 긴장감
3. Round 3 붕괴 속도와 3 hearts의 적절성
4. Final 밀치기 강도와 ring 크기
5. 4 AI와 10 AI에서 실제 렌더링 FPS
6. AI가 플레이어에게 불공정하게 느껴지는 구간

이 검증이 긍정적일 때 그래픽, 애니메이션, 아이템/스킬, 더 많은 racer를 단계적으로 추가한다.
