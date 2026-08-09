# WILD DASH 50 — Prototype V1 Readiness

이 문서는 React + Vite + Electron 기반 WILD DASH 50을 **Prototype V1로 보존하기 위한 마감 기준**을 기록합니다.

## 현재 상태

Prototype V1의 목적은 온라인 서비스나 정식 3D 게임 출시가 아니라 다음 핵심 게임 경험을 검증하는 것입니다.

- Windows 오프라인 앱 실행
- 플레이어 1명 + AI 경쟁자 방식
- 캐릭터 선택
- 키메라 외형 조합
- 3단계 난이도
- 4개 라운드 토너먼트
- 로컬 저장
- 설정
- 결과/진행도
- NSIS Windows installer

## 플레이 흐름

정상 성공 흐름은 다음과 같습니다.

```text
Lobby
→ Character Select
→ Countdown
→ Race
→ Round Break
→ Fruit Arena
→ Round Break
→ Survival Arena
→ Round Break
→ Final Arena
→ Result
→ Lobby 또는 다시 출전
```

첫 실행에서 튜토리얼이 완료되지 않았다면 Lobby와 Character Select 사이에 Tutorial이 들어갑니다.

`game/systems/flowSystem.ts`가 주요 화면 전환 규칙을 순수 함수로 보유하며, 자동 테스트에서 성공 흐름을 100회 반복 검증합니다.

## 라운드 완료 조건

### Round 1 — Race

- 50-racer local AI race
- 플레이어 포함 총 50마리
- 25위 이내: 다음 라운드
- 26위 이하: Result

### Round 2 — Fruit

- 과일 8개 획득: 성공
- 시간 종료 전 목표 실패: Result

### Round 3 — Survival

- 하트가 0 이하가 되면 실패
- 제한 시간까지 생존하면 성공

### Round 4 — Final

- 플레이어가 링 경계를 벗어나면 실패
- 남은 AI가 0이면 우승

## 반복 실행 / lifecycle 점검

### InputManager

- 전역 `keydown` / `keyup` listener는 InputManager 한 곳에서만 관리합니다.
- 화면 context가 바뀌어도 listener pair를 중복 등록하지 않습니다.
- stale cleanup이 현재 화면의 listener를 제거하지 않도록 token을 사용합니다.
- 자동 테스트에서 context를 50회 교체한 뒤 listener 개수를 확인합니다.

### AudioManager

- Web Audio `AudioContext`는 lazy singleton 형태로 한 번 생성해 재사용합니다.
- React 화면에서 직접 `AudioContext`를 생성하지 않습니다.
- 자동 테스트에서 SFX를 100회 요청해도 AudioContext 생성 횟수가 1회인지 확인합니다.

### requestAnimationFrame

- `Race3D.tsx`의 RAF loop는 effect cleanup에서 `cancelAnimationFrame` 합니다.
- `ArenaRound.tsx`의 RAF loop도 effect cleanup에서 `cancelAnimationFrame` 합니다.
- legacy race loop 역시 cleanup에서 RAF를 취소합니다.

### timer

- Countdown timer는 화면/카운트 변경 시 `clearTimeout` 됩니다.
- Tutorial의 350ms feedback timer는 ref로 추적하며 unmount 시 `clearTimeout` 됩니다.
- Tutorial은 advance가 처리되는 동안 추가 advance timer가 중복 생성되지 않도록 guard를 사용합니다.
- Prototype V1 React 화면에는 `setInterval` loop를 사용하지 않습니다.

## 저장 안정성

`game/save/SaveManager.ts`가 저장을 전담합니다.

- `version: 1` 저장 포맷
- profile / settings / tutorial / unlocks / records
- legacy key migration
- corrupt JSON 복구
- 필드 validation
- 미래 버전 데이터 비파괴
- localStorage write 실패 시 gameplay 예외 전파 방지

## 자동 테스트 범위

현재 테스트는 다음을 포함합니다.

- InputManager source/context 동작
- 반복 context 변경 시 keyboard listener 중복 방지
- AudioManager 단일 AudioContext 소유/재사용
- 스킬 cooldown
- 아이템 획득 pool / 아이템 소모
- 충돌 판정
- 순위 계산
- 라운드 성공/실패 조건
- 난이도 증가 순서
- Prototype 전체 화면 흐름
- flowSystem 실제 page 연결 여부
- SaveManager validation / legacy migration / corrupt data recovery
- UI의 직접 localStorage 접근 방지
- UI 문구 정확성
- RAF / timer lifecycle cleanup guard
- Vite desktop shell 산출물

## CI / Windows installer

영구 workflow: `.github/workflows/ci.yml`

Pull Request와 main push에서:

1. `npm ci`
2. `npm run typecheck`
3. `npm run lint`
4. `npm test`
5. `npm run build`
6. `npm run test:desktop`
7. Windows runner에서 `npm run dist:win`
8. NSIS `.exe` 존재 확인
9. installer artifact 업로드

Windows installer 생성은 GitHub Actions Windows runner에서 실제 성공 확인된 상태입니다.

## 남아 있는 버그 / 제한

### Prototype V1을 막지는 않는 항목

1. **진짜 3D가 아님**
   - Race3D라는 컴포넌트 이름은 남아 있지만 렌더링은 Canvas 2D 원근 연출입니다.
   - Prototype V1에서는 의도된 제한입니다.

2. **실제 BGM 없음**
   - 현재 오디오는 oscillator 기반 SFX 중심입니다.
   - AudioManager에는 향후 sample/BGM 구조만 준비되어 있습니다.

3. **브라우저형 pointer/touch UI 코드 일부 잔존**
   - Windows에서 마우스로 사용할 수 있어 Prototype에는 유지합니다.
   - Godot 이전 시 폐기 가능합니다.

4. **완전한 GUI E2E 자동화는 없음**
   - 화면 전환 규칙은 100회 반복 unit simulation으로 검증하지만 실제 사람이 창을 클릭하는 Playwright/Electron E2E 테스트는 없습니다.
   - tag 전 최종 수동 smoke play 1~3회는 권장합니다.

5. **기존 legacy race fallback 코드가 page.tsx에 남음**
   - `ENABLE_3D_RACE`가 현재 Canvas race를 사용하도록 되어 있어 fallback은 일반 플레이에서 실행되지 않습니다.
   - Godot 이전 시 제거 대상입니다.

## 외부 공개 출시 전에 해결해야 할 항목

다음은 **Prototype V1 보존 자체를 막지는 않지만 정식 외부 배포 전에는 검토해야 하는 항목**입니다.

1. **의존성 보안 audit**
   - 최근 CI 설치 단계에서 npm audit가 20개 취약점(17 high, 3 critical)을 보고했습니다.
   - 대부분 dev/build transitive dependency인지 실제 런타임 영향이 있는지 분리 조사해야 합니다.
   - `npm audit fix --force`는 호환성 검토 없이 실행하지 않습니다.

2. **Windows 코드 서명**
   - 현재 installer는 정식 코드 서명을 하지 않습니다.
   - 공개 배포 시 Windows SmartScreen 신뢰/경고 문제를 고려해야 합니다.

3. **실제 Windows 수동 플레이 smoke test**
   - installer 설치 → 실행 → 4라운드 → 결과 → 재시작 → 저장 복구까지 실제 PC에서 최종 확인하는 것이 좋습니다.

## Godot 이전 시 재사용할 게임 규칙

다음은 엔진과 비교적 독립적이어서 Godot 버전 설계의 기준 데이터/규칙으로 재사용할 가치가 높습니다.

### config

- `game/config/animals.ts`
  - 4개 베이스 동물
  - 스킬명 / cooldown / 역할
- `game/config/items.ts`
  - 바나나 / 방어 / 자석 / 먹물 아이템 개념
- `game/config/difficulty.ts`
  - AI 속도 / 공격성 / 충돌 압력 단계
- `game/config/race.ts`
  - 코스 길이, 속도 범위, 섹션 구성 개념

### systems

- `game/systems/flowSystem.ts`
  - 4라운드 진행 순서
  - 진출/탈락 화면 규칙
- `game/systems/roundSystem.ts`
  - 과일 8개
  - 생존 하트
  - final ring 탈락/우승 조건
- `game/systems/rankingSystem.ts`
  - 플레이어보다 앞선 경쟁자 수 기반 순위
- `game/systems/skillSystem.ts`
  - cooldown 규칙
- `game/systems/itemSystem.ts`
  - 순위 기반 item pool / 소모 개념
- `game/systems/collisionSystem.ts`
  - 충돌 허용 범위와 판정 기준
- `game/systems/aiSystem.ts`
  - 49 AI 생성/seed 개념과 난이도 방향

### save schema

- fan / wins / best rank
- settings
- tutorial completed
- unlocks
- records
- versioned migration 개념

Godot에서는 TypeScript 구현을 그대로 복사하기보다 위 규칙과 수치를 GDScript/Resource 구조로 옮기는 것이 적절합니다.

## Godot 이전 시 버려도 되는 브라우저 전용 코드

다음 구현은 Prototype V1의 웹/Electron shell을 위한 것이므로 Godot 이전 때 재작성 또는 폐기할 수 있습니다.

- React 화면 컴포넌트 전체
  - `app/page.tsx`
  - `app/Race3D.tsx`의 Canvas draw/project 코드
  - `app/ArenaRound.tsx` DOM 렌더링
  - `app/Tutorial.tsx` DOM UI
- `app/globals.css`
- Vite entry / HTML
- Electron `BrowserWindow` shell
- DOM keyboard listener 구현 자체
  - 입력 action 이름/매핑 개념은 재사용 가능
- Web Audio `AudioContext` 구현 자체
  - SFX/BGM bus 개념은 재사용 가능
- `localStorage` adapter 자체
  - versioned save schema/migration 원칙은 재사용 가능
- `navigator.vibrate`
- pointer/touch DOM controls
- Canvas 2D 원근 projection/drawing 코드
- legacy browser race fallback

## Prototype V1 보존 절차

1. PR #2에서 모든 CI check가 green인지 확인
2. `stabilization/wilddash-prototype`을 `main`에 merge
3. main push CI가 다시 green인지 확인
4. Windows installer artifact 확인
5. 실제 Windows PC에서 간단한 수동 smoke test
6. 그 시점의 main commit에 `prototype-v1` tag 생성

태그 생성 전에는 Prototype V1 후보 상태로 취급합니다.
