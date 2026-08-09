# WILD DASH 3D — Godot Next

이 폴더는 React/Electron **Prototype V1을 대체하지 않는** 차세대 Godot 3D 프로젝트입니다.
기존 Prototype V1의 게임 규칙과 밸런스 개념만 참고하고, Canvas/DOM 구현은 직접 이식하지 않습니다.

## 현재 단계 — Vertical Slice 01

현재 Godot 버전은 전체 게임이 아니라 **4-racer 3D gameplay vertical slice**입니다.

- Dog: 플레이어 1명
- Rabbit / Elephant / Cat: AI 3마리
- 실제 CharacterBody3D 이동/점프/collision
- smoothing chase camera
- 테스트 트랙 1개
- 기본 장애물
- FinishLine Area3D
- 실시간 순위/standings
- FPS HUD

목표는 그래픽 완성이 아니라 **"3D WILD DASH가 재미있는가?"**를 검증하는 것입니다.
상세 튜닝과 평가 기준은 `docs/VERTICAL_SLICE_01.md`를 참고하세요.

## 첫 단계 목표

현재 단계는 전체 게임 제작이 아니라 **실제 3D vertical-slice용 기본 구조**를 만드는 단계입니다.

포함:

- Godot 프로젝트 부팅 구조
- 테스트용 3D 직선 트랙
- Capsule 기반 임시 3D 캐릭터
- CharacterBody3D 물리 이동/점프
- 중앙 GameManager / RaceManager / InputManager / AudioManager / SaveManager
- 3-racer AI race
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

F6/F5로 실행하면 테스트 트랙과 4 racers가 표시됩니다.

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
  camera/       3D camera follow logic
  tracks/       3D 트랙 Scene / finish trigger
  systems/      엔진 독립에 가까운 게임 규칙/아이템 시스템
  ui/           Godot Control/HUD
  audio/        SFX/BGM 리소스
  assets/       GLB/glTF, texture, DCC source, material
  docs/         Vertical slice 검증 기록
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
└─ gameplay helpers
```

### CharacterRoot

`character_controller.gd`가 담당합니다.

- 이동
- 중력
- 점프
- physics collision
- skill cooldown
- held item
- race registration / finish state

### VisualModel

`character_visual.gd`가 담당합니다.

- GLB/glTF 모델
- Skeleton3D
- mesh/material
- animation playback
- visual-only 보정

`CharacterController`는 GLB 내부 bone/mesh/AnimationPlayer 경로를 직접 알지 않습니다.
따라서 나중에 모델을 교체할 때 `VisualModel` wrapper만 바꾸고 gameplay controller는 그대로 유지하는 것이 원칙입니다.

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

모든 playable animal의 기본 animation contract:

```text
Idle
Run
Jump
Hit
Skill
Win
Lose
```

WILD DASH는 최대 50 racers를 목표로 하므로 초기 제작 budget은 LOD0 약 8k–12k triangles, material 1개 우선, 1024 texture 중심으로 시작합니다.
더 상세한 제작/LOD/export/import 체크리스트는 `assets/CHARACTER_PIPELINE.md`를 참고하세요.

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

1. Vertical Slice 01을 Windows에서 3~5회 직접 플레이해 조작감 확정
2. camera / steering / jump / obstacle spacing 튜닝
3. checkpoint + Curve3D TrackProgress로 교체
4. 실제 GLB 캐릭터 1종 연결
5. 장애물 1종 + 아이템 박스 1종을 gameplay vertical slice로 완성
6. 성능 측정 후 AI 5 → 10 → 25 → 50 단계 확장

React/Electron Prototype V1은 저장소 루트에 계속 보존합니다.
