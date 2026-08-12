# WILD DASH

WILD DASH는 **Godot 기반의 3D 동물 파티 레이싱 게임 프로젝트**입니다.

현재 개발 기준은 Godot 버전이며, 저장소 루트의 React/Electron 코드는 초기 Prototype V1 검증용 구현으로 함께 보존합니다.

## 현재 캠페인

1. **Wild World Grand Prix** — 메인 레이스
2. **Fruit Collection** — 과일 수집
3. **Neon Harbor Night Race** — 야간 항구 레이스
4. **Push Out** — 밀어내기 아레나
5. **Snowpeak Winter Rally** — 설산/빙판 레이스

`Floor Collapse` 모드는 저장소에 보존되어 있으며 향후 Free Play 또는 추가 라운드용으로 사용할 수 있습니다.

## 레이싱 구성

- Casual: 총 10 racers
- Normal: 총 15 racers
- Hard: 총 18 racers
- 플레이어 캐릭터 4종: Dog, Rabbit, Elephant, Cat
- 레이스 전체 종족 12종: 기본 4종 + NPC 전용 8종
- 레이싱 아이템 18종
- 캐릭터별 스킬 및 AI 스킬/아이템 판단
- 아이템 박스, 장애물, 지름길, 체크포인트, 순위 시스템
- 카메라 장애물 대응 및 터널 가시성 보정
- 고속 벽 관통 방지용 레이스 환경 충돌 보강

## 최근 레이스 확장

### Wild World Grand Prix
- 약 2.47 km 메인 코스
- 30 route points
- 11 checkpoints
- 2 shortcuts
- 숲, 협곡, 다리, 터널, 점프, 장애물 구간

### Neon Harbor Night Race
- 약 1.8 km 야간 항구 코스
- Container Yard, Warehouse, Dockside, Industrial Tunnel, Neon Downtown 등 10개 구역
- 서비스 레인 shortcut
- 야간 가시성/조명 및 Racing Feel 시스템

### Snowpeak Winter Rally
- 약 2.1 km 겨울 코스
- 눈길, 빙판, Ice Cave, Frozen Lake, Ski Lift, Blizzard Ridge
- 겨울 노면별 slip/속도 반응
- Snowpeak 전용 장애물과 snowfall 연출

## 아이템

기존 12종에 다음 6종이 추가되어 현재 레이싱 아이템은 총 **18종**입니다.

- Snowball
- Bee Swarm
- Turbo Chili
- Mud Splash
- Spring Trap
- Swap Boost

Rocket Nut은 목표가 없을 때도 전방으로 발사되며, Snowball/Rocket Nut은 터널과 벽을 관통하지 않도록 월드 충돌 검사를 사용합니다.

## 조작

| 기능 | 키 / 입력 |
| --- | --- |
| 이동 / 조향 | WASD / 방향키 |
| 점프 | Space |
| 캐릭터 스킬 | E |
| 아이템 사용 | Q / Gamepad B |

## Godot 프로젝트

주요 3D 게임 코드는 `godot/` 아래에 있습니다.

```text
godot/
  characters/   플레이어/NPC 캐릭터, AI
  modes/        캠페인 및 게임 모드
  tracks/       트랙, 환경, 장애물
  items/        아이템 및 아이템 효과
  systems/      레이싱/충돌/스킬 시스템
  camera/       추적 카메라
  scripts/      GameManager, SaveManager, AudioManager 등
  tests/        Godot regression / smoke tests
```

현재 개발/검증 기준 Godot 버전은 **4.7.1**입니다.

## React / Electron Prototype

저장소 루트의 `app/`, `game/`, `ui/`, `electron/` 구조는 WILD DASH 초기 Prototype V1입니다.

이 코드는 초기 게임 규칙, 입력, 저장, 오디오, Windows 패키징 구조를 검증한 기록으로 보존하며 현재 3D 게임 개발의 중심은 Godot 프로젝트입니다.

## CI / 검증

저장소에는 다음을 포함한 여러 GitHub Actions 검증 workflow가 있습니다.

- TypeScript typecheck / lint / unit test / build
- Godot project import
- Grand Prix racer probes
- Neon Harbor / Snowpeak track checks
- Item Box pickup regression
- Item combat / obstacle regression
- Race environment collision regression
- Windows build / release candidate workflows

일부 최신 Actions 실행은 GitHub 계정의 billing/spending-limit 문제로 runner가 시작되기 전에 중단된 기록이 있으므로, Public/Release 전에는 최신 workflow 재실행과 수동 Godot 플레이 검증을 권장합니다.

## 저장소 공개 및 권리

소스 코드를 공개 저장소에서 열람할 수 있게 하더라도 별도 허가 없이 코드, 게임 콘텐츠, 이름, 그래픽 및 프로젝트 자산의 사용·복제·재배포·상업적 이용을 허가하는 것은 아닙니다.

자세한 내용은 `COPYRIGHT.md`를 확인하세요.

## Git 작성자 이메일 개인정보

앞으로 로컬 Git 커밋에서 개인 이메일 대신 GitHub noreply 주소를 사용하는 것을 권장합니다.

```bash
git config user.email "230676375+benochansong@users.noreply.github.com"
```

저장소에만 적용하려면 위 명령을 WILD DASH 저장소 폴더에서 실행하고, 모든 로컬 저장소에 적용하려면 `--global` 옵션을 추가합니다.

---

Copyright © 2026 Beno Chansong Lee. All Rights Reserved.
