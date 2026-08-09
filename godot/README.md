# WILD DASH 3D — Godot Next

이 폴더는 React/Electron **Prototype V1을 대체하지 않는** 차세대 Godot 3D 프로젝트입니다.
기존 Prototype V1의 게임 규칙과 밸런스 개념만 참고하고, Canvas/DOM 구현은 직접 이식하지 않습니다.

## 첫 단계 목표

현재 단계는 전체 게임 제작이 아니라 **실제 3D vertical-slice용 기본 구조**를 만드는 단계입니다.

포함:

- Godot 프로젝트 부팅 구조
- 테스트용 3D 직선 트랙
- Capsule 기반 임시 3D 플레이어 캐릭터
- CharacterBody3D 물리 이동/점프
- 중앙 GameManager / RaceManager / InputManager / AudioManager / SaveManager
- AIController 스켈레톤
- ItemSystem 인터페이스
- Prototype V1에서 가져온 규칙 상수 모음
- 3D 모델과 게임 로직을 분리하는 CharacterRoot / VisualModel 구조
- Blender/Maya → GLB/glTF → Godot asset pipeline

아직 포함하지 않음:

- 완성 캐릭터 모델
- 49 AI 동시 레이스
- 완성 트랙
- 아이템 실제 3D 프리팹/효과
- 동물별 완성 스킬 연출
- 4개 라운드 전체 구현
- 정식 UI/오디오

## 프로젝트 열기

Godot 4.x에서 다음 파일을 프로젝트로 import합니다.

```text
godot/project.godot
```

F6/F5로 실행하면 테스트 트랙과 임시 플레이어가 표시됩니다.

기본 조작:

- W / ↑ : 가속
- S / ↓ : 감속
- A/D 또는 ←/→ : 조향
- Space : 점프
- E : 스킬 요청
- Q : 아이템 사용 요청

## 폴더 구조

```text
godot/
  scenes/       엔트리/게임 화면 Scene
  scripts/      전역 Manager
  characters/   CharacterRoot / visual wrapper / Controller / AI
  tracks/       3D 트랙 Scene
  systems/      엔진 독립에 가까운 게임 규칙/아이템 시스템
  ui/           Godot Control UI
  audio/        SFX/BGM 리소스
  assets/       GLB/glTF, texture, DCC source, material
```

## Character Scene 설계

캐릭터의 물리/게임 로직과 외형 모델을 분리합니다.

```text
CharacterRoot (CharacterBody3D)
├─ CollisionShape3D
├─ VisualModel
│  └─ ImportedModel (GLB/glTF instance)
│     ├─ Skeleton3D
│     ├─ skinned MeshInstance3D
│     └─ AnimationPlayer 또는 AnimationTree
└─ CameraRig / gameplay helper
```

### CharacterRoot

`character_controller.gd`가 담당합니다.

- 이동
- 중력
- 점프
- physics collision
- skill cooldown
- held item
- race registration

### VisualModel

`character_visual.gd`가 담당합니다.

- GLB/glTF 모델
- Skeleton3D
- mesh/material
- animation playback
- visual-only 보정

`CharacterController`는 GLB 내부 bone/mesh/AnimationPlayer 경로를 직접 알지 않습니다.
따라서 나중에 모델을 교체할 때 `VisualModel` wrapper만 바꾸고 gameplay controller는 그대로 유지하는 것이 원칙입니다.

현재 임시 모델도 이 구조를 사용합니다.

```text
characters/test_racer.tscn
└─ VisualModel → characters/visuals/test_visual.tscn
```

## 3D 모델 제작 → Export → Godot Import

WILD DASH의 기본 캐릭터 asset pipeline입니다.

```text
Blender / Maya
→ GLB(default) 또는 glTF 2.0
→ godot/assets/characters/<animal>/
→ Godot import
→ characters/visuals/<animal>_visual.tscn
→ CharacterRoot에 VisualModel로 instance
```

### Step 1 — Blender / Maya에서 모델 제작

캐릭터는 다음 계약을 지킵니다.

```text
Visual mesh
Skeleton / skin
Idle
Run
Jump
Hit
Skill
Win
Lose
```

기본 animation 이름은 대소문자까지 통일하는 것을 권장합니다.

```text
Idle
Run
Jump
Hit
Skill
Win
Lose
```

DCC 원본 `.blend`, `.ma` 등은 다음 위치에 둘 수 있습니다.

```text
assets/source/
```

이 폴더는 `.gdignore`로 Godot runtime import에서 제외합니다.

### Step 2 — 게임용 저폴리곤 기준 확인

WILD DASH는 화면에 최대 **50 racers**가 동시에 나타날 수 있으므로 한 캐릭터를 고사양 hero model 기준으로 만들지 않습니다.

초기 목표값:

| 항목 | 시작 목표 |
| --- | ---: |
| LOD0 | 8k–12k triangles |
| LOD1 | 4k–6k triangles |
| LOD2 | 1.5k–3k triangles |
| deform bones | 약 40–60 이하 우선 |
| materials | 1개 우선, 최대 2개 목표 |
| 기본 texture | 1024×1024 |

이 값은 절대 제한이 아니라 **50-racer profiler test를 시작하기 위한 budget**입니다.

귀/꼬리/실루엣처럼 멀리서도 보이는 형태에 polygon을 우선 사용하고, 얼굴의 아주 작은 디테일에는 과도한 polygon/material을 쓰지 않습니다.

### Step 3 — Export 준비

Export 전 체크:

1. skeleton rest pose/T-pose 확인
2. mesh/armature transform 확인
3. skin weight 오류 확인
4. triangulation 확인
5. animation clip 이름 확인
6. 사용하지 않는 camera/light/helper 제거
7. material slot 최소화

게임 이동은 CharacterBody3D가 담당하므로 Run/Jump animation은 가능하면 **in-place** 방식으로 제작합니다.

### Step 4 — GLB/glTF Export

기본 runtime 파일은 `.glb`를 사용합니다.

예:

```text
assets/characters/dog/dog.glb
assets/characters/rabbit/rabbit.glb
```

텍스처를 별도 파일로 관리해야 할 특별한 이유가 있다면 `.gltf + .bin + textures`도 사용할 수 있습니다.

DCC exporter의 UI 이름은 버전에 따라 달라질 수 있지만 결과물에는 최소한 다음이 포함되어야 합니다.

```text
mesh
skin
skeleton
PBR material data
Idle / Run / Jump / Hit / Skill / Win / Lose
```

### Step 5 — Godot Import

GLB/glTF를 `assets/characters/`에 넣고 Godot에서 import합니다.

확인 항목:

1. Skeleton3D 생성
2. skinning 정상
3. scale 정상
4. material/texture 정상
5. 7개 기본 animation 존재
6. loop 설정 확인
7. Generate LODs 활성 상태 확인
8. 불필요한 mesh/material/animation 제거 여부 확인

import된 GLB scene에는 gameplay script를 직접 붙이지 않습니다.

### Step 6 — VisualModel wrapper 생성

예:

```text
characters/visuals/dog_visual.tscn
```

구조:

```text
VisualModel (Node3D + character_visual.gd)
└─ ImportedModel (dog.glb instance)
   ├─ Skeleton3D
   ├─ MeshInstance3D
   └─ AnimationPlayer / AnimationTree
```

GLB의 회전/scale/pivot을 약간 보정할 필요가 있다면 이 wrapper 안에서만 처리합니다.

### Step 7 — CharacterRoot에 연결

```text
CharacterRoot
├─ CollisionShape3D
├─ VisualModel (dog_visual.tscn)
└─ CameraRig
```

이후 dog 모델을 새 파일로 바꿔도 `character_controller.gd`, `RaceManager`, `ItemSystem`, `AIController`를 수정하지 않는 것을 목표로 합니다.

## Animation contract

모든 playable animal은 다음 semantic animation을 기본으로 제공합니다.

```text
Idle
Run
Jump
Hit
Skill
Win
Lose
```

`character_visual.gd`가 이 이름을 받아 AnimationPlayer 또는 AnimationTree로 전달합니다.
게임 로직은 Skeleton3D나 animation track을 직접 제어하지 않습니다.

## LOD / 50-racer 원칙

Godot import의 automatic mesh LOD를 우선 사용합니다.
필요하면 나중에 수동 LOD/HLOD를 추가합니다.

성능 검증 순서는 다음과 같이 진행합니다.

```text
1 racer
→ 5 racers
→ 10 racers
→ 25 racers
→ 50 racers
```

50 racers에서 문제가 생기면 다음 순서로 최적화를 검토합니다.

1. material/shader 수
2. skeleton/bone 수
3. animation 평가 비용
4. mesh triangle 수
5. texture memory
6. shadow distance/quality
7. 먼 AI의 update frequency

고사양 PC 한 대에서만 잘 돌아가는 모델을 기준으로 확정하지 않습니다.

더 상세한 체크리스트는 [`assets/CHARACTER_PIPELINE.md`](./assets/CHARACTER_PIPELINE.md)를 참고하세요.

## Prototype V1에서 재사용하는 개념

- 플레이어 1명 + 최대 AI 49마리
- 총 50-racer 구조
- 25위 이내 다음 라운드 진출
- dog / rabbit / elephant / cat 역할과 cooldown 개념
- banana / shield / magnet / ink 아이템 개념
- Wild / Chaos / Nightmare 난이도 단계
- 4라운드 토너먼트 흐름
- versioned save schema 원칙

TypeScript 소스 자체를 복사하는 것이 아니라 Godot의 Scene/Node/Resource/CharacterBody3D 방식으로 다시 구현합니다.

## 다음 개발 순서

1. 테스트 맵에서 플레이어 이동/카메라/충돌 감각 확정
2. 임시 AI 3~5마리 추가
3. 체크포인트 기반 TrackProgress/Ranking 구현
4. 4개 동물 중 1종만 실제 GLB vertical slice로 완성
5. Idle/Run/Jump/Hit/Skill/Win/Lose 연결
6. 장애물 1종 + 아이템 박스 1종
7. 성능 측정 후 AI 10 → 25 → 50 단계 확장

React/Electron Prototype V1은 저장소 루트에 계속 보존합니다.
