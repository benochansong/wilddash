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
  characters/   캐릭터 Scene/Controller/AI
  tracks/       3D 트랙 Scene
  systems/      엔진 독립에 가까운 게임 규칙/아이템 시스템
  ui/           향후 Godot Control UI
  audio/        향후 SFX/BGM 리소스
  assets/       GLB/glTF, texture, material 등
```

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

1. 이 테스트 맵에서 플레이어 이동/카메라/충돌 감각 확정
2. 임시 AI 3~5마리 추가
3. 체크포인트 기반 TrackProgress/Raking 구현
4. 4개 동물 중 1종만 vertical slice로 완성
5. 장애물 1종 + 아이템 박스 1종
6. 성능 측정 후 AI 10 → 25 → 50 단계 확장

React/Electron Prototype V1은 저장소 루트에 계속 보존합니다.
