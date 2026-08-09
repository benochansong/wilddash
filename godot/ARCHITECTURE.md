# WILD DASH 3D Architecture

## 원칙

- React/Electron Prototype V1은 레퍼런스/보존본으로 유지한다.
- Canvas draw loop, DOM, CSS, localStorage, Web Audio를 Godot으로 복사하지 않는다.
- 게임 규칙과 수치만 가져와 Godot Scene/Node/Resource 방식으로 재구현한다.
- 첫 vertical slice는 플레이어 1명 + 임시 트랙 + 소수 AI만 사용한다.
- 49 AI는 프로파일링 후 10 → 25 → 50 단계로 확장한다.

## 폴더 책임

### scenes/
게임의 상위 composition Scene. 현재 `main.tscn`만 존재하며 테스트 트랙과 플레이어를 조립한다.

### scripts/
전역 Autoload Manager.

- `GameManager`: 화면/게임 상태와 선택 캐릭터·난이도·키메라 선택 보유
- `RaceManager`: racer 등록, race lifecycle, 순위/진출 인터페이스
- `InputManager`: Godot InputMap 생성 및 gameplay action 접근
- `AudioManager`: AudioStream 기반 SFX/BGM 중앙 재생
- `SaveManager`: `user://` JSON 저장, version/validation/default 구조

### characters/

- `character_controller.gd`: CharacterBody3D 플레이어 물리 이동, 점프, skill/item 요청
- `ai_controller.gd`: 첫 단계 단순 AI 이동 스켈레톤
- `test_racer.tscn`: Capsule primitive 임시 플레이어

향후 실제 동물 GLB를 `CharacterBody3D` 아래 visual child로 교체합니다. 물리 body와 visual model을 분리해 모델 교체가 게임 규칙에 영향을 덜 주게 합니다.

### tracks/
현재 `test_track.tscn`은 CSGBox3D 기반 직선 테스트 코스입니다. 실제 트랙은 checkpoint 또는 curve/spline 기반 진행률을 가져야 합니다.

### systems/

- `prototype_rules.gd`: Prototype V1에서 재사용할 엔진 독립 규칙 상수
- `item_system.gd`: 아이템 지급/소모 경계. 실제 아이템 효과는 이후 별도 Scene/Resource로 확장

## 데이터 흐름

```text
Godot Input
   ↓
InputManager
   ↓
CharacterController ──→ ItemSystem / skill signal
   ↓
CharacterBody3D physics
   ↓
Track collision / obstacle physics
   ↓
RaceManager
   ↓
GameManager state / future UI
```

AI는 player input을 사용하지 않고 `AIController`가 동일한 CharacterBody3D 이동 계층을 제어하는 방향으로 확장합니다.

## Prototype V1 → Godot 매핑

| Prototype V1 | Godot Next |
| --- | --- |
| React screen state | GameManager + Godot scenes/UI |
| Canvas racer update | CharacterBody3D physics |
| Canvas obstacle math | StaticBody3D/Area3D/RigidBody3D |
| InputManager keyboard listener | Godot InputMap + InputManager |
| Web Audio AudioContext | AudioStreamPlayer |
| localStorage SaveManager | `user://` SaveManager |
| TS config objects | GDScript constants → later Resource `.tres` |
| flowSystem/roundSystem | Godot systems/state machine |

## 다음 vertical slice의 기준

완성 게임이 아니라 아래가 먼저입니다.

1. 플레이어가 실제 3D 바닥과 장애물에 충돌한다.
2. 카메라가 플레이어를 안정적으로 추적한다.
3. 임시 AI 3~5마리가 같은 트랙을 달린다.
4. checkpoint 기반 진행률과 순위가 동작한다.
5. 한 동물 스킬과 한 아이템이 실제 3D 환경에서 동작한다.
6. Windows에서 안정적으로 60 FPS를 확인한 뒤 AI 수를 늘린다.
