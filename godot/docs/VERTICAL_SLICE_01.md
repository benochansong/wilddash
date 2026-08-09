# WILD DASH 3D — Vertical Slice 01

목표는 전체 게임 완성이 아니라 **"3D WILD DASH가 재미있는가?"**를 검증하는 것입니다.

## 범위

- 플레이어: Dog 1마리
- AI: Rabbit / Elephant / Cat 3마리
- 총 4 racers
- 테스트 트랙 1개
- Capsule 기반 임시 visual

## 구현된 플레이 요소

- CharacterBody3D 기반 3D 이동
- W/↑ 가속, S/↓ 감속
- A/D 또는 좌우 방향키 조향
- Space 점프
- 실제 바닥/벽/장애물 collision
- smoothing chase camera
- 3개 AI의 속도/선호 lane 차이
- forward ray 기반 단순 장애물/경쟁자 회피
- FinishLine Area3D
- finish order 고정
- 실시간 player rank / standings
- speed / FPS HUD
- 기본 CSG 장애물 4종 배치

## 트랙 구조

현재 트랙은 +Z에서 -Z 방향으로 달리는 약 107m 테스트 직선입니다.

- 시작선: z=37 부근
- racers 시작: z=40
- 결승선: z=-70
- 양쪽 collision wall
- box obstacle 3개
- ramp 1개

현재 진행률은 `-global_position.z`로 계산합니다. 이 방식은 Vertical Slice 전용이며, 정식 트랙에서는 checkpoint + Curve3D 기반 TrackProgress로 교체합니다.

## 캐릭터 튜닝

### Dog (player)

- cruise speed: 8.8
- max speed: 14.5
- acceleration: 24
- jump velocity: 7.5
- steering: 2.15

플레이어는 입력을 하지 않아도 낮은 cruise speed로 전진하고, W/↑를 누르면 AI보다 빠른 max speed를 사용할 수 있습니다. 이는 party racer에서 조향/점프에 집중하면서도 멈춰 있는 느낌을 줄이기 위한 첫 테스트 설정입니다.

### AI

- Rabbit: target 10.8, lane -2.0
- Elephant: target 9.9, lane +2.2, 비교적 둔한 steering
- Cat: target 10.5, lane +5.5, 빠른 steering

AI는 아직 완성 racing AI가 아닙니다. 현재 목적은 3마리가 실제 물리 공간에서 장애물과 서로를 피하면서 결승선까지 도달할 수 있는지 확인하는 것입니다.

## 물리 안정성 기준

Vertical Slice 01에서 확인할 사항:

1. Capsule이 바닥을 뚫지 않는다.
2. 벽 충돌 후 track 밖으로 튀어나가지 않는다.
3. obstacle collision 후 영구적으로 끼이지 않는다.
4. ramp 접촉 후 과도한 회전/발사가 발생하지 않는다.
5. 점프 착지 시 반복 bounce가 발생하지 않는다.
6. racers끼리 접촉해도 scene이 불안정해지지 않는다.

CharacterRoot는 `floor_snap_length=0.35`를 사용하고, collision 후 속도를 약간 감쇠해 obstacle 충돌을 읽을 수 있도록 했습니다.

## AI 평가 기준

- 3 AI가 race start 전에 움직이지 않는가
- 각각 다른 lane/속도 성향이 보이는가
- 앞의 obstacle/racer를 감지하면 회피를 시도하는가
- 벽에 장시간 박혀 있지 않는가
- 20초 내외 simulation에서 모두 finish 가능한가

Godot CI는 60 fixed FPS, 1200 frames의 headless simulation을 실행하고 다음 로그를 요구합니다.

- Vertical Slice scene boot
- Player finish
- Race complete (4 racers 모두 finish)

## FPS 평가

HUD와 `main.gd`가 `Engine.get_frames_per_second()`를 수집합니다.

중요: GitHub Actions headless FPS는 실제 Windows GPU rendering 성능 지표가 아닙니다. FPS 평가는 Windows PC에서 Godot editor 또는 export build로 확인해야 합니다.

첫 목표:

- 4 racers: 60 FPS 안정 유지
- frame hitch가 조작 중 체감되지 않을 것
- 이후 5 → 10 → 25 → 50 racers 순으로 profile

## 조작감 평가 질문

Windows에서 직접 3~5회 플레이하면서 다음을 체크합니다.

- W를 눌렀을 때 가속이 즉각적이면서 너무 급하지 않은가
- A/D 조향이 미끄럽거나 너무 민감하지 않은가
- obstacle을 피하는 선택이 재미있는가
- Space 점프가 obstacle 대응 수단으로 느껴지는가
- 카메라가 회전할 때 멀미나 급격한 흔들림이 없는가
- AI와 접촉했을 때 경쟁하는 느낌이 나는가
- 10~15초짜리 한 판을 다시 하고 싶은가

## 이번 slice에서 의도적으로 하지 않은 것

- 49 AI
- 정식 동물 GLB
- AnimationTree 완성
- 아이템 실제 효과
- 동물 skill 실제 효과
- checkpoint/spline track
- 4 round tournament
- 정식 HUD 디자인
- 사운드/BGM polish

이 항목들은 **핵심 4-racer 레이스의 조작감이 재미있다고 판단된 뒤** 진행합니다.
