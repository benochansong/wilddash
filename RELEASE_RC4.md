# WILD DASH 3D RC4 — Windows Hardening + Gameplay Upgrade

Version: **0.9.0-rc4**

RC4 carries forward the RC3 gameplay upgrade and adds a hardened Windows release path for trusted code signing.

## Gameplay carried forward

- Expanded ~1.48 km Grand Prix
- 17 route points / 7 ordered checkpoints
- 21 Item Boxes across 7 stations
- Six items: Dash Berry, Bubble Shield, Sticky Fruit, Shockwave, Rocket Nut, Recovery Feather
- Dog / Rabbit / Elephant / Cat active skills
- AI item and skill decisions
- Rabbit shortcut routing
- Character Select + Chimera Lab
- Chimera HEAD skill / BODY passive / TAIL utility build system
- Grand Prix → Fruit Collection → Floor Collapse → Push Out
- Save v2, keyboard/gamepad, pause, settings

## RC4 Windows hardening

- Windows metadata/version bumped to RC4
- Dedicated code-signing helpers
- Trusted RSA Authenticode verification gate
- RFC3161 timestamp verification
- Signed executable post-signing smoke test
- Signed-only GitHub release gate
- Microsoft Artifact Signing path prepared
- Trusted CA + self-hosted Windows signing runner path prepared

## Current signing status

The initial RC4 candidate artifact is intentionally **UNSIGNED INTERNAL TEST ONLY** until a trusted code-signing identity is configured.

Do not describe the internal unsigned artifact as a public signed release.
The `v0.9.0-rc4` tag is reserved for the verified signed build.
