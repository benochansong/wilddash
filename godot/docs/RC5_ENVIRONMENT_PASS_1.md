# RC5 Grand Prix Environment Pass 1

## Scope

This pass upgrades only the Grand Prix road, forest, canyon/cliff, bridge, and tunnel foundations. Track length, route points, checkpoints, finish logic, item-box stations, shortcuts, racer balance, character collision, skills, and race flow remain unchanged.

## Baseline findings

- Road surfaces were visible collision-enabled `CSGBox3D` nodes with one flat gray material.
- Road shoulders and edge language did not distinguish meadow, forest, canyon, bridge, or tunnel zones.
- Forest dressing contained twelve tapered cylinders but no separate foliage crowns or ground dressing.
- Canyon dressing used fourteen identical `BoxMesh` instances, producing a stacked-block silhouette.
- Bridge dressing contained water planes but no deck beams, supports, posts, braces, or warning structure.
- Tunnel visuals were the same collision-enabled wall and roof boxes used by gameplay.
- Visual and gameplay collision geometry were coupled for generated road segments, guardrails, and tunnel shells.
- No dedicated `WorldEnvironment` exists. Lighting is intentionally deferred to environment pass 3.

## Implementation

### Materials and road

- Added one lightweight reusable spatial shader with local UV-style color variation, roughness breakup, and center-path wear.
- Added a shared material palette for Asphalt, Dirt, Grass, Rock, Bridge, and Tunnel surfaces.
- Split the 29 road visuals into four material-grouped `MultiMeshInstance3D` batches.
- Kept the original simple CSG road collision dimensions and transforms as hidden gameplay collision.
- Added grass shoulders, light and warning curbs, center dashes, bridge/tunnel approach markings, guardrail posts, and forest wooden fence posts as collision-free MultiMeshes.

### Forest

- Replaced the trunk-only forest with varied tapered trunks and three-cluster low-poly crowns per tree.
- Added deterministic height, thickness, crown scale, and rotation variation.
- Added collision-free bushes, ground rocks, and fallen logs outside the primary road readability zone.

### Canyon and cliff

- Replaced box stacks with six-sided tapered rock columns.
- Added irregularly scaled outcrops and loose edge stones using a second low-poly MultiMesh.
- Positioned rock dressing in the track's local frame so curves remain readable.
- Preserved existing hidden rail collision as the only gameplay boundary.

### Bridge

- Added edge beams, longitudinal support beams, vertical supports, cross braces, rail posts, and warning markings.
- Batched structural parts into two collision-free MultiMeshes.
- Preserved road and rail gameplay collision without changing bridge width or AI route geometry.

### Tunnel

- Hid the original wall and roof gameplay collision meshes.
- Added segmented wall and ceiling visuals, structural entrance/exit frames, ceiling supports, emissive guide lights, edge markings, and a bright exit band.
- Used emissive material only; no heavy dynamic tunnel light system was added.

## Performance and validation

- First visual/collision split reached 232 runtime nodes and failed the 180-node track budget.
- Road and rail visuals were rebatch-optimized, reducing the final track to 176 runtime nodes.
- Decorative vegetation, rocks, bridge structure, road details, and tunnel panels have no collision and no process callbacks.
- Godot 4.7.1 project import passed.
- Grand Prix validation passed at 2467.7 m, 30 route points, 11 checkpoints, and unchanged shortcut savings.
- Character Select, Chimera, 12-item, 4-skill, and RC5 gameplay challenge smoke tests passed.
- Normal 15-racer Grand Prix completed with all 15 racers and the four-round campaign reached its result scene.
- Hard 18-racer Grand Prix probe completed with all 18 racers in 73.49 seconds.
- Baseline and optimized 10/25/50-racer benchmarks completed. Optimized 50-racer average was 59.75 FPS in headless benchmark conditions.

## Remaining work

- The 18-racer full four-round campaign exceeded a 260-second local timeout after Grand Prix; the isolated 18-racer Grand Prix completed successfully, so no environment collision or AI-route regression was found. The later-round duration remains a separate follow-up.
- Lighting, fog, color grading, camera composition, and full LOD/MultiMesh tuning remain for passes 2 and 3.
- The runtime track node budget has four nodes of remaining headroom; additional pass-2 detail should extend existing batches rather than add many standalone nodes.
