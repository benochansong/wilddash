# WILD DASH Music Assets

RC7 통합 플레이 테스트용 실제 BGM은 이 폴더에 Ogg Vorbis로 저장합니다.

- `wild_dash_race_theme.ogg` → Wild World Grand Prix
- `wild_dash_fruit_collection_theme.ogg` → Fruit Collection
- `wild_dash_race_theme_alt.ogg` → Neon Harbor Night Race
- `wild_dash_arena_theme_alt.ogg` → Push Out
- `wild_dash_snowpeak_theme.ogg` → Snowpeak Winter Rally
- `wild_dash_result_theme.ogg` → Result 화면

모든 곡은 48 kHz stereo Ogg Vorbis runtime copy를 사용하며, 원본 lossless WAV는 runtime 저장소에 포함하지 않습니다.

`AudioManager`는 각 라운드별 theme slot을 로드하고 반복 재생합니다. 파일이 누락되거나 import/load에 실패하면 기존 procedural theme으로 fallback합니다.

메뉴 / Round Break / Floor Collapse Free Play은 현재 procedural BGM을 유지합니다.

Public release 전에 각 곡의 사용 권한, 루프 경계, Music-bus 볼륨, Godot import/playback을 최종 확인합니다.
