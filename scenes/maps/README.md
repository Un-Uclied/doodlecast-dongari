# 난이도별 맵 편집

Godot에서 아래 씬을 열어 수정합니다. 저장하면 해당 난이도의 1~6레벨에 모두 반영됩니다. 각 맵은 F6으로 바로 플레이할 수 있습니다.

| 난이도 | 편집할 씬 |
| --- | --- |
| EASY | `easy_map.tscn` |
| NORMAL | `normal_map.tscn` |
| HARD | `hard_map.tscn` |

- `TileMapLayer`: 바닥·벽을 칠합니다.
- `TileMapLayerFurniture`: 문·소품을 칠합니다. 닫힌 문은 기존 소스 2를 사용하면 클리어 시 소스 3의 열린 문으로 자동 교체됩니다.
- 횃불(`torch1`, 소스 5)·촛대(`candlestick1`, 소스 1)를 칠하면 실행할 때 불꽃 위치에 조명이 자동으로 붙습니다. `combat_level.tscn`의 `Ambient`로 전체 어두움을, `scenes/effects/torch_light.tscn`으로 빛의 색·범위를 조정합니다.
- `Player`: 시작 위치를 옮깁니다. 발밑이 연결된 바닥에 놓이도록 배치합니다.
- `TileMapLayerPits`: 통과할 수 없는 구덩이를 칠합니다. TileSet의 `tile_walls` 충돌 다각형이 설정된 타일은 자동으로 적의 이동 경로와 스폰 후보에서 제외됩니다. 각 난이도의 구덩이 배치는 해당 1~6레벨에 반영됩니다.

타일 배치와 시작 위치는 난이도별로 독립입니다. TileSet의 타일 그림·충돌 설정은 세 맵이 공유합니다.

상속 구조는 `combat_level.tscn → 난이도별 map.tscn → level_01~06.tscn`입니다. 공통 전투·HUD·효과음은 `combat_level.tscn`에서 관리합니다. 공통 씬에는 타일 배치가 없으므로 플레이 확인은 위 맵 씬이나 개별 레벨에서 합니다. 개별 레벨은 `difficulty`, `level_number`, `mode` 설정을 유지합니다. 특정 레벨에서만 지형을 바꾸려는 경우에만 그 레벨 씬에 타일 배치를 덮어씁니다.

기존 `scenes/test_scene.tscn`은 이동·제스처 테스트용입니다. 여기를 편집해도 실제 난이도별 맵은 바뀌지 않습니다.
