# WILD DASH RC9 — Racing Polish + Multiplayer Prototype

RC9 is an experimental branch based on RC8. It keeps the 12-racer single-player game intact while validating three player-facing improvements: reliable acceleration, continuous track-edge readability, and a first LAN party architecture.

## 1. W acceleration regression

Root cause addressed: older saved keyboard bindings can replace all keyboard events for an action with one stored key. Because InputManager installs defaults first and SettingsManager applies the saved map afterward, a stale save can erase the canonical `W` / `Up` acceleration aliases.

RC9 protections:

- `W` and `Up` are reinstalled as acceleration safety aliases.
- `S` and `Down` are reinstalled as brake safety aliases.
- `A/D` and Left/Right receive the same movement-safety treatment.
- throttle reads have a physical-key fallback for W/Up and S/Down.
- `InputManager.get_input_debug_snapshot()` exposes action and physical-key state without permanent production spam.
- `WildDashRacerInputState` provides a transport-friendly input packet for multiplayer work.

Expected feel remains:

- neutral input tends toward the animal's cruise speed;
- W/Up tends toward max speed;
- S/Down tends toward the low brake target;
- individual animal acceleration/max-speed tuning remains intact.

## 2. Continuous visual guardrails

`track_production_dressing.gd` now builds two continuous visual rail bands on both sides of each route segment using MultiMesh batches.

These rails are presentation only. Existing hidden collision barriers, tunnel shells, route containment, checkpoints and AI paths are unchanged.

Track identity:

- Grand Prix: teal/orange painted natural-race rail.
- Neon Harbor: cyan/magenta emissive rail.
- Snowpeak: orange/white winter safety rail.

Manual validation should check curves, bridges, tunnel approaches and narrow sections for readability and ensure the visual rail does not appear to cut through the drivable lane.

## 3. LAN party prototype

New files under `godot/network/` provide the first multiplayer layer:

- `network_manager.gd` — ENet Host/Join, 2–8 player roster, ready state, 12-racer selection and party start.
- `multiplayer_lobby.gd/.tscn` — Create Party / Join Party / Ready / Character / Start UI.
- `network_race_sync.gd` — Grand Prix-only prototype that sends client input intent to the host, host-simulates remote human racers, and broadcasts authoritative transform/speed corrections.

`NetworkManager` is an Autoload on this RC9 branch only.

### Current target

- 2–8 connected human roster: implemented at lobby/session layer.
- duplicate animal selection: allowed.
- LAN IP join: implemented.
- AI mix: party start targets 10 total racers for 2–4 humans and 12 total racers for 5–8 humans, with a minimum of four AI due to existing GameManager limits.
- Grand Prix input/transform prototype: implemented for first validation.
- Suno BGM: remains local on every client; audio is not streamed over network.

### Not complete yet

The following are deliberately NOT release-ready in this milestone:

- authoritative item pickup/result persistence across every client;
- synchronized Fruit Collection;
- synchronized Push Out;
- synchronized Neon Harbor;
- synchronized Snowpeak;
- Steam lobby / Steam Networking;
- room codes / internet relay / NAT traversal;
- host migration;
- final disconnect AI takeover;
- lag compensation / rollback;
- final multiplayer result UI and multiplayer save records.

After Grand Prix, the existing campaign can continue locally, but those later rounds are not yet network-authoritative. Do not advertise RC9 as complete online multiplayer.

## 4. Manual validation order

1. Start RC9 in single-player mode and verify RC8's 12-character selection still works.
2. Grand Prix: compare no-W cruise speed versus held-W max speed for Dog, Wolf and Elephant.
3. Confirm W still works after opening Settings and after restarting with an existing save.
4. Inspect Grand Prix continuous rails at curves, bridge and tunnel approach.
5. Inspect Neon Harbor rails for cyan/magenta emissive readability.
6. Inspect Snowpeak rails for orange/white winter readability.
7. Run two game instances on one PC/LAN: Host on one, Join `127.0.0.1` or host LAN IP on the other.
8. Pick two different animals, set both Ready, and start Party Grand Prix.
9. Verify the host sees the remote human racer respond to steer/throttle input.
10. Verify the client sees host/remote movement and receives correction rather than unrestricted result authority.
11. Test client disconnect and host disconnect from the party lobby.

RC9 must remain Draft until these manual checks pass.
