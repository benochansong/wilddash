# WILD DASH 3D — Vertical Slice 01 Analysis

첫 번째 4-racer 3D gameplay slice의 실제 검증 결과입니다.

## 완료 범위

- Dog: 플레이어
- Rabbit / Elephant / Cat: AI
- 총 4 racers
- 테스트 트랙 1개
- CharacterBody3D 기반 실제 3D 이동/점프/collision
- smoothing chase camera
- 기본 장애물 + ramp
- FinishLine Area3D
- 실시간 rank / standings
- HUD speed / FPS 표시

## CI 성공 결과

Godot 4.7.1 stable에서 headless editor import와 실제 물리 경주를 실행했습니다.

최종 확인 run:

```text
RACE START racers=4
PLAYER FINISH rank=3 elapsed=12.51s
RACE COMPLETE order=Cat, Elephant, Dog (YOU), Rabbit
FPS SAMPLE min=1 avg=133.9 max=145
```

`min=1`은 headless 프로세스 초기화 구간이 포함된 값입니다. 또한 headless FPS는 GPU 렌더링 benchmark가 아니므로 Windows 실제 성능 수치로 사용하지 않습니다.

## FPS 분석

### 자동 검증으로 확인된 것

- 4개의 CharacterBody3D
- 3개의 AI controller
- CSG collision track
- camera/HUD logic
- physics race

를 한 Scene에서 문제없이 실행했습니다.

Headless 평균 FPS는 133.9로 기록됐지만 렌더러/GPU workload가 실제 Windows 실행과 다르므로 **성능 여유가 있다는 참고 신호** 정도로만 봅니다.

### Windows에서 확인할 목표

- 4 racers: 60 FPS 안정
- steering/jump 중 체감 frame hitch 없음
- camera smoothing 중 stutter 없음

정식 성능 판단은 Windows editor 또는 export build에서 직접 측정해야 합니다.

## 물리 안정성 분석

초기 검증에서 두 가지 실제 문제를 발견해 수정했습니다.

### 1. 바닥 collision을 장애물 collision으로 오인

처음에는 `get_slide_collision_count() > 0`를 장애물 충돌로 판단해 바닥 접촉까지 속도 감쇠가 적용됐습니다.

증상:

- Dog cruise 8.8 → 약 4.8
- AI도 목표 속도의 약 72% 수준으로 지속 감속

수정:

- collision normal의 Y 값을 검사
- floor / walkable ramp 접촉은 속도 penalty에서 제외
- side-facing wall/obstacle collision만 감속

수정 후 Dog는 headless에서 8.8 cruise를 정상 유지했습니다.

### 2. Ramp edge trap

초기 ramp 폭과 Capsule 반지름 조합 때문에 Elephant가 ramp 오른쪽 모서리 `x≈2.2 / z≈-24.7`에서 장시간 걸렸습니다.

수정:

- ramp 폭을 vertical slice 수준에 맞게 축소
- AI에 forward ray avoidance 추가
- 장애물 접근 시 AI jump 허용
- progress가 멈추면 avoidance 방향을 바꾸는 간단한 stuck recovery 추가

최종 CI에서는 네 racer 모두 결승선을 통과했습니다.

### 현재 판단

현재 임시 직선 트랙에서는:

- 바닥 관통 없음
- 결승선 trigger 정상
- 영구 obstacle trap 없음
- 네 racer 모두 완주
- finish order 중복 기록 없음

까지 확인됐습니다.

다만 실제 사람이 급격하게 A/D를 반복하거나 ramp를 비스듬히 밟는 상황은 Windows 수동 playtest가 필요합니다.

## AI 동작 분석

현재 AI는 완성형 racing AI가 아니라 vertical slice용입니다.

사용 중인 요소:

- 동물별 target speed
- preferred lane
- 작은 lane wander
- forward physics ray
- obstacle 감지 시 lateral avoidance
- obstacle 감지 시 jump
- stuck progress 감지 후 recovery 방향 변경

최종 CI finish order:

1. Cat
2. Elephant
3. Dog (player, no headless input)
4. Rabbit

따라서 현재 AI 3마리가 같은 물리 트랙에서 서로 다른 주행 성향을 가지며 완주할 수 있다는 최소 목표는 달성했습니다.

아직 없는 것:

- checkpoint racing line
- 전략적 overtaking
- player 공격/방해 판단
- 난이도별 AI 의사결정
- rubber banding
- 아이템/스킬 사용 AI

이 기능들은 4-racer 조작감이 재미있다는 판단 이후에 추가합니다.

## 조작감 분석

현재 수치:

```text
Dog cruise speed   8.8
Dog max speed     14.5
acceleration      24.0
turn speed         2.15
jump velocity      7.5
camera distance    9.5
camera height      5.2
camera smoothing   7.0
```

구조적으로는 arcade party racer 방향입니다.

- 입력이 없어도 cruise하므로 조향/점프에 집중 가능
- W/↑를 누르면 AI보다 빠른 max speed를 활용 가능
- A/D는 Y축 회전 기반 steering
- Space는 실제 CharacterBody3D jump
- camera는 즉시 고정되지 않고 smoothing follow

그러나 **"재미있는가"와 조작감은 CI가 판정할 수 없습니다.**

Windows에서 최소 3~5회 직접 플레이하며 다음을 판단합니다.

1. W 가속이 충분히 시원한가
2. neutral cruise가 너무 자동주행처럼 느껴지지 않는가
3. A/D가 너무 민감하거나 미끄럽지 않은가
4. 장애물을 보고 피할 시간이 충분한가
5. Space jump가 회피 선택지로 재미있는가
6. camera 회전이 편안한가
7. AI와 앞뒤 경쟁이 체감되는가
8. 10~15초 레이스를 다시 플레이하고 싶은가

## Vertical Slice 01 결론

기술적으로는 **첫 3D gameplay slice 성공**으로 판단합니다.

확인된 것:

- 실제 3D 물리 이동
- 4-racer race lifecycle
- AI 3마리 완주
- 장애물 회피/점프
- FinishLine
- live ranking
- camera/HUD
- Godot 4.7.1 import/runtime 안정성

다음 개발 전에 필요한 것은 기능 추가가 아니라 **Windows에서 직접 조작감 playtest**입니다.

그 결과가 긍정적일 때만 다음 단계인 checkpoint + Curve3D TrackProgress, 실제 GLB 동물 1종, 아이템 1종으로 진행합니다.
