# Audio

WILD DASH의 실제 WAV/OGG SFX와 BGM을 배치합니다.

`AudioManager`가 음악 플레이어와 SFX 플레이어 풀을 중앙 관리합니다. Prototype V1의 oscillator/Web Audio 구현은 이식하지 않습니다.

## BGM slots

게임용 Ogg Vorbis 파일은 `godot/audio/music/` 아래에 둡니다.

- `wild_dash_race_theme.ogg` → Wild World Grand Prix
- `wild_dash_race_theme_alt.ogg` → Neon Harbor Night Race
- `wild_dash_snowpeak_theme.ogg` → Snowpeak Winter Rally
- `wild_dash_arena_theme_alt.ogg` → Push Out
- Fruit Collection / 메뉴 / 결과화면 → 현재 procedural BGM fallback 사용

외부 음악 파일이 없거나 로드되지 않으면 `AudioManager`가 기존 procedural BGM으로 안전하게 fallback합니다.

원본 WAV는 저장소에 넣지 않고, 배포용으로 변환한 OGG만 runtime asset으로 사용합니다. Suno 등 외부 생성 도구에서 만든 음악은 실제 배포 전에 해당 계정/플랜의 상업적 이용 권한을 별도로 확인합니다.

추가 트랙 음악은 `AudioManager`의 theme slot에 등록하고 `GameManager`의 round-to-theme mapping에 연결합니다.
