# WILD DASH 3D Character Asset Pipeline

WILD DASH의 캐릭터 제작 표준입니다.

```text
Blender / Maya
    ↓
GLB (default) / glTF 2.0
    ↓
Godot import
    ↓
VisualModel wrapper scene
    ↓
CharacterRoot gameplay scene
```

핵심 원칙은 **게임 로직과 3D 모델을 분리하는 것**입니다.

`CharacterController`는 GLB 내부의 Mesh, Skeleton, Bone, AnimationPlayer 이름을 직접 참조하지 않습니다.
모델 교체는 `VisualModel` wrapper scene에서만 처리합니다.

---

## 1. Runtime scene contract

```text
CharacterRoot (CharacterBody3D)
├─ CollisionShape3D
├─ VisualModel                 ← replaceable wrapper
│  └─ ImportedModel            ← GLB/glTF instance
│     ├─ Skeleton3D
│     ├─ skinned MeshInstance3D
│     └─ AnimationPlayer and/or AnimationTree
└─ CameraRig / gameplay helpers
```

Responsibilities:

### CharacterRoot

게임플레이 전용입니다.

- movement
- gravity / jump
- physics collision
- skill cooldown
- held item
- AI/player ownership
- race registration

### VisualModel

표현 전용입니다.

- imported GLB/glTF scene
- Skeleton3D
- skinned mesh
- materials
- animation playback
- optional VFX attachment sockets
- visual-only LOD decisions

### CollisionShape3D

GLB의 외형 메시와 분리합니다.

캐릭터 귀, 꼬리, 뿔 등의 모양이 바뀌어도 기본 race collision은 가능한 한 동일하게 유지합니다.
이렇게 해야 키메라/스킨 교체가 gameplay balance를 바꾸지 않습니다.

---

## 2. Canonical animation contract

모든 playable animal은 아래 animation clip 이름을 기본 표준으로 사용합니다.

```text
Idle
Run
Jump
Hit
Skill
Win
Lose
```

대소문자까지 맞추는 것을 권장합니다.

추가 애니메이션은 허용하지만 위 7개 이름은 공통 계약으로 유지합니다.

예:

```text
Idle
Run
Jump
Hit
Skill
Win
Lose
RunFast
TurnLeft
TurnRight
```

`character_visual.gd`는 이 표준 이름만 gameplay 쪽에 노출합니다.
모델마다 Skeleton/AnimationPlayer의 내부 구조가 달라도 `CharacterController`는 수정하지 않습니다.

---

## 3. DCC source rules

Blender/Maya 원본 파일은 runtime import 폴더와 구분합니다.

권장 구조:

```text
assets/
  source/                     ← .blend / .ma / working files, Godot import 제외
    characters/
      dog/
      rabbit/
      elephant/
      cat/

  characters/                 ← Godot runtime imports
    dog/
      dog.glb
    rabbit/
      rabbit.glb
    elephant/
      elephant.glb
    cat/
      cat.glb
```

`assets/source/`에는 `.gdignore`를 둡니다.

### 모델링 기본 규칙

- 캐릭터 origin은 발바닥 중앙 기준으로 유지
- transform은 export 전에 정리
- skeleton은 rest pose/T-pose에서 검증
- mesh는 export 전에 안정적으로 triangulate
- 캐릭터 실제 게임 크기는 서로 비슷한 범위로 통일
- gameplay collision 크기는 DCC mesh가 아니라 Godot CharacterRoot에서 결정
- 과도한 투명 재질과 작은 별도 material slot을 피함

---

## 4. Performance budget for up to 50 racers

WILD DASH는 한 화면에 플레이어 포함 최대 50마리의 캐릭터가 존재할 수 있으므로 모바일급 초저사양까지 목표로 하지는 않더라도 **고사양 hero character 방식으로 제작하지 않습니다.**

초기 제작 목표값이며 실제 수치는 profiler 결과에 따라 조정합니다.

### Mesh budget per racer

| Level | Initial target |
| --- | ---: |
| LOD0 / near | 8k–12k triangles |
| LOD1 / middle | 4k–6k triangles |
| LOD2 / far | 1.5k–3k triangles |

Godot automatic mesh LOD를 우선 사용하고, 필요할 경우 수동 LOD/HLOD를 추가합니다.

### Rig budget

- deform bones: 대략 40–60 이내를 우선 목표
- 얼굴 전용 bone rig는 최소화
- 꼬리/귀 등 silhouette에 중요한 bone에 우선 배분
- 50개 캐릭터가 동시에 Animation을 평가한다는 전제로 설계

### Materials

- 가능하면 캐릭터당 1 material
- 복잡한 캐릭터도 2 materials 이내 우선
- 작은 장식마다 material slot을 분리하지 않음
- 같은 캐릭터 변형은 texture/parameter 공유를 우선 검토

### Textures

기본 시작점:

```text
BaseColor : 1024x1024
Normal    : 1024x1024 when needed
ORM       : 1024x1024 when needed
```

2K texture는 화면에서 실제 차이가 확인되고 GPU memory budget이 허용될 때만 사용합니다.
멀리 보이는 49 AI에는 얼굴의 미세 디테일보다 silhouette와 색 구분이 중요합니다.

---

## 5. Animation production

각 애니메이션은 가능하면 제자리(in-place) 이동을 기본으로 합니다.
실제 race 이동 거리는 `CharacterController`가 결정합니다.

필수 clip:

### Idle
- loop
- neutral gameplay pose

### Run
- loop
- forward locomotion
- root translation 최소화

### Jump
- short jump pose sequence
- gameplay vertical motion은 CharacterBody3D가 담당

### Hit
- 짧은 피격 반응
- physics knockback과 animation을 분리

### Skill
- 캐릭터 고유 연출
- 실제 skill effect/cooldown은 gameplay system에서 결정

### Win / Lose
- result presentation
- gameplay state를 변경하지 않음

---

## 6. Export from Blender / Maya

기본 runtime format은 **GLB**입니다.
텍스처 파일을 별도 관리해야 하거나 diff 가능한 scene description이 필요한 경우 `.gltf + .bin + textures`를 사용할 수 있습니다.

### Export checklist

1. 필요한 character mesh와 armature/skeleton만 선택
2. rest pose 확인
3. transforms 확인
4. triangulation 확인
5. skin weights 확인
6. animation clip 이름 확인
7. `Idle / Run / Jump / Hit / Skill / Win / Lose` export 확인
8. unused cameras/lights/helpers 제거
9. GLB 또는 glTF 2.0 export
10. 새 파일을 Godot runtime assets 폴더에 복사

예:

```text
res://assets/characters/dog/dog.glb
```

DCC별 exporter UI는 버전에 따라 다를 수 있으므로 옵션 이름보다 아래 결과 계약을 우선합니다.

```text
GLB/glTF contains:
- mesh
- skin
- skeleton
- PBR material data
- required animation clips
```

---

## 7. Godot import

GLB를 `godot/assets/characters/...`에 넣으면 Godot importer가 scene으로 가져옵니다.

Import 검토 항목:

1. Skeleton3D가 정상 생성되는가
2. mesh가 skeleton에 정상 skinning 되는가
3. scale이 테스트 capsule/track과 맞는가
4. material이 깨지지 않았는가
5. 7개 기본 animation이 존재하는가
6. animation loop 설정이 맞는가
7. mesh LOD generation이 활성화되어 있는가
8. 필요 없는 animation/material/mesh가 들어오지 않았는가

원본 GLB 노드 자체에 gameplay script를 직접 붙이지 않습니다.

---

## 8. Create the VisualModel wrapper

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
   └─ AnimationPlayer
```

`character_visual.gd`가 animation playback을 담당합니다.

모델의 pivot/rotation/scale 보정이 필요하다면 `VisualModel` 또는 `ImportedModel` wrapper에서 처리합니다.
`CharacterRoot` physics transform을 모델 보정에 사용하지 않습니다.

---

## 9. Attach visual to CharacterRoot

게임플레이 scene:

```text
CharacterRoot (CharacterBody3D + character_controller.gd)
├─ CollisionShape3D
├─ VisualModel (dog_visual.tscn instance)
└─ CameraRig
```

나중에 dog model을 새 버전으로 교체할 때:

```text
old dog.glb
→ new dog.glb
```

또는:

```text
dog_visual.tscn
→ dog_skin_b_visual.tscn
```

만 교체합니다.

`character_controller.gd`, `RaceManager`, `ItemSystem`, `AIController`는 수정하지 않는 것을 목표로 합니다.

---

## 10. Validation before accepting an asset

캐릭터 하나를 runtime에 넣기 전에 아래를 확인합니다.

- [ ] Godot import error 없음
- [ ] CharacterRoot collision이 mesh와 독립적임
- [ ] Idle
- [ ] Run
- [ ] Jump
- [ ] Hit
- [ ] Skill
- [ ] Win
- [ ] Lose
- [ ] 1 material 우선 / 최대 2 material 목표
- [ ] LOD 생성 확인
- [ ] 가까운 거리 silhouette 확인
- [ ] 먼 거리 readability 확인
- [ ] 10 racers test
- [ ] 25 racers test
- [ ] 50 racers profiler test

50 racer에서 문제가 발생하면 shader/material/animation/mesh complexity를 먼저 줄이고, 그 다음 시각 품질을 다시 조정합니다.
