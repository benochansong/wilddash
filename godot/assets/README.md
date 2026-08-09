# Assets

WILD DASH 3D의 runtime asset과 DCC 원본을 분리합니다.

```text
assets/
  source/                     Blender/Maya 원본. `.gdignore`로 Godot import 제외
    characters/
    tracks/

  characters/                 Godot가 실제 import하는 GLB/glTF
  tracks/                     실제 트랙 GLB/glTF
  props/
  items/
  textures/
```

기본 제작 흐름:

```text
Blender / Maya source
→ GLB 또는 glTF 2.0 export
→ assets/characters 또는 assets/tracks
→ Godot import
→ wrapper scene
→ gameplay scene
```

캐릭터는 imported GLB를 `CharacterController`에 직접 연결하지 않습니다.
`characters/visuals/*_visual.tscn` wrapper가 모델/Skeleton/Animation을 담당하고,
`CharacterRoot`는 물리/충돌/게임플레이만 담당합니다.

자세한 캐릭터 제작 규칙, 애니메이션 이름, LOD/폴리곤 예산, Export/Import 체크리스트는
[`CHARACTER_PIPELINE.md`](./CHARACTER_PIPELINE.md)를 참고하세요.
