# WILD DASH 3D — Windows Release Candidate

이 폴더는 기존 React/Electron **Prototype V1을 덮어쓰지 않고 보존한 채** 개발하는 Godot 기반 차세대 3D 버전입니다.
현재 release 브랜치의 게임 버전은 `0.9.0-rc1`입니다.

## 현재 게임

- Windows PC
- 오프라인 싱글플레이
- Godot 4.7.1
- 실제 `CharacterBody3D` 이동/물리 충돌
- Dog / Rabbit / Elephant / Cat 선택
- Wild / Chaos / Nightmare 난이도 선택
- AI 4~10마리 캠페인 안정화
- 별도 성능 Scene에서 10 → 25 → 50 Racer 단계 벤치마크
- 로컬 JSON Save v2
- 키보드 + 게임패드
- Pause / Settings / Result / Lobby 흐름

## 게임 흐름

```text
Launch
→ Lobby
→ Character Select
→ Round 1: Wild World Grand Prix
→ Round 2: Fruit Collection
→ Round 3: Floor Collapse Survival
→ Final: Push-Out Arena
→ Result
→ Save
→ Lobby / Replay / Quit
```

CI에서는 위 흐름을 Headless로 완료한 뒤 프로세스를 다시 실행해 Save Load까지 확인합니다.

## 조작

### Keyboard 기본값

- W / ↑ : 가속 / 앞으로
- S / ↓ : 감속 / 뒤로
- A / ← : 왼쪽
- D / → : 오른쪽
- Space : 점프
- E : 스킬
- Q : 아이템
- Esc / P : Pause

Settings 화면에서 Keyboard binding을 변경할 수 있으며 변경값은 Save에 저장됩니다.

### Gamepad 기본값

- Left Stick / D-Pad : 이동 / 조향
- A : 점프
- X : 스킬
- B : 아이템
- Start : Pause

Keyboard와 Gamepad는 같은 Godot InputMap action을 사용하므로 게임 로직이 입력 장치별로 분기되지 않습니다.

## Settings

### Audio

- Master Volume
- Music Volume
- SFX Volume
- Mute
- `Master / Music / SFX` Audio Bus

현재 RC는 외부 음원 라이선스에 의존하지 않도록 가벼운 procedural placeholder BGM/SFX를 사용합니다. 최종 사운드 리소스가 준비되면 AudioManager의 theme/SFX 리소스만 교체할 수 있습니다.

### Graphics

- 1280×720
- 1600×900
- 1920×1080
- Windowed / Fullscreen
- 30 / 60 / 120 / Unlimited FPS

기본값은 1600×900, Windowed, 60 FPS입니다.

### Accessibility

- Reduced Motion
- High Contrast

Reduced Motion은 추적 카메라의 움직임을 더 안정적으로 만들고, High Contrast는 메뉴/HUD의 명도 대비와 그림자를 강화합니다.

## Save System

저장 위치:

```text
user://wild_dash_save.json
```

Save version: `2`

저장 항목:

- profile: fans / wins / best rank / launches / campaigns / last character
- audio settings
- graphics settings
- accessibility settings
- keyboard bindings
- records
- unlocks

v1 Save의 `sound / reduced_motion / high_contrast` 값을 v2 구조로 migration합니다.
더 새로운 버전의 Save가 발견되면 RC1은 해당 파일을 덮어쓰지 않습니다.

## Pause

게임 플레이 중:

```text
Esc / P / Gamepad Start
```

으로 일시정지할 수 있습니다.

Pause 메뉴:

- Resume
- Return to Lobby
- Quit Game

## 4 Round Scene 구조

각 라운드는 독립 Scene + ModeController입니다.

```text
res://modes/grand_prix/grand_prix.tscn
res://modes/fruit_collection/fruit_collection.tscn
res://modes/floor_collapse/floor_collapse.tscn
res://modes/push_out/push_out.tscn
```

공유 시스템:

```text
GameManager
RaceManager
InputManager
SettingsManager
AudioManager
SaveManager
ResultManager
PauseManager
CharacterController
AIController
ItemSystem
```

라운드별 규칙은 해당 ModeController가 소유합니다.

## 3D Character Asset Pipeline

```text
Blender / Maya
→ GLB 또는 glTF 2.0
→ Godot Import
→ VisualModel wrapper
→ CharacterRoot
```

캐릭터 외형과 게임 로직을 분리하여 모델을 교체해도 `CharacterController`는 수정하지 않는 것을 원칙으로 합니다.

기본 animation contract:

```text
Idle
Run
Jump
Hit
Skill
Win
Lose
```

자세한 내용은 `assets/CHARACTER_PIPELINE.md`를 참고합니다.

## 50 Racer 성능 게이트

일반 캠페인은 아직 AI 최대 10으로 유지합니다.
50 Racer는 별도 benchmark에서만 단계 검증합니다.

```text
10 racers
→ 25 racers
→ 50 racers
```

Headless CI에서는 AI LOD, update frequency 조절, animation LOD, collision 단순화 효과를 비교합니다.
실제 50 Racer를 일반 플레이 설정으로 승격하기 전에는 Windows rendered benchmark에서 FPS / CPU / GPU / Physics / AI / Draw Calls / Memory를 다시 확인해야 합니다.

성능 결과는 `docs/RACER_SCALING_BENCHMARK.md`에 기록되어 있습니다.

## Windows Export

저장소에는 `export_presets.cfg`의 `Windows Desktop` preset이 포함되어 있습니다.
Godot 4.7.1 Editor와 동일 버전의 Export Templates가 설치되어 있으면 다음처럼 Release export가 가능합니다.

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path godot --export-release "Windows Desktop" "build/windows/WILD_DASH_3D.exe"
```

GitHub Actions의 Windows runner도 동일한 방식으로 `.exe`를 생성하고 실제 smoke launch 후 artifact로 업로드합니다.

## CI Release Gate

현재 workflow가 검사하는 항목:

1. Godot 프로젝트 import
2. Keyboard / Gamepad InputMap
3. Keyboard remapping
4. Master / Music / SFX Audio Bus
5. Graphics / Accessibility / FPS Settings
6. Pause / Resume
7. Save write
8. Launch → Lobby → Character Select → 4 Rounds → Result → Save
9. Restart → Save Load
10. 10 AI campaign regression
11. 10 / 25 / 50 racer performance benchmark
12. Windows x86_64 release export
13. Exported `.exe` smoke launch
14. Windows artifact upload

## Steam

Steam SDK는 현재 프로젝트에 포함하지 않습니다.
Steam 배포는 별도 단계이며 Steamworks/achievement/cloud 같은 플랫폼 기능은 핵심 GameManager, RaceManager, SaveManager와 직접 결합하지 않는 것을 원칙으로 합니다.

## 아직 RC 제한 사항

- 실제 production 동물 GLB/Animation은 아직 placeholder 단계
- BGM/SFX는 procedural placeholder
- Windows executable code signing은 아직 하지 않음
- 50 Racer는 headless CPU/Physics gate는 통과했지만 실제 production mesh를 사용한 Windows GPU gate는 아직 별도 확인 필요
- Steam 통합 없음

최종 RC 판정은 `docs/RELEASE_CANDIDATE_CHECKLIST.md`를 참고합니다.
