# Dungeon TileSet

`image_assets/dungeon_tileset/`의 원본 PNG를 참조하는 Godot TileSet입니다.

- `TileSets/dungeon_tileset.tres`: TileMapLayer의 **Tile Set**에 지정합니다.
- `TileSets/dungeon_tiles.tscn`: 빈 TileMapLayer입니다. 레벨에 드래그한 뒤 하단 **TileMap**에서 타일을 칠합니다.

기준 격자는 **16×16**이며, 픽셀 필터는 Nearest입니다. 소스 0은 `tileset.png`를 16×16으로 나눈 948개 타일입니다. 완전히 투명한 칸은 제외했습니다. 원본이 던전 예제 배치 이미지여서 같은 모양이 여러 위치에 있을 수 있습니다. 여러 칸을 함께 선택하면 벽이나 통로를 묶어 칠할 수 있습니다.

소품은 자르지 않고 이미지 전체를 하나의 타일로 등록했습니다. 세로로 긴 소품은 셀 아래쪽에 정렬합니다.

`door1-1`·`door1-4`는 문이 차지할 두 칸 중 **왼쪽 아래 칸**에 칠합니다. 문 중심은 두 칸 사이 경계에 맞고, 아래쪽은 해당 칸의 바닥선에 맞습니다.

| 소스 ID | 이미지 |
| --- | --- |
| 0 | tileset.png: 바닥·벽·통로 |
| 1 | candlestick1.png: 촛대 |
| 2 | door1-1.png: 닫힌 문 |
| 3 | door1-4.png: 열린 문 |
| 4 | objects_03.png: 나무 상자 |
| 5 | torch1.png: 횃불 |
| 6 | treasure-static_03-1.png: 열린 보물 상자 |
| 7 | treasure-static_03.png: 닫힌 보물 상자 |
| 8 | treasure-static_04.png: 열쇠 |
| 9 | treasure-static_09.png: 동전 |

Physics Layer 0은 **1: tile_walls**에 속하며 **2: Player**와 충돌합니다. 소스 0의 벽과 돌 테두리에 충돌 다각형을 넣었습니다. 바닥, 열린 문 안쪽, 절벽 아래 장식, 소품에는 충돌을 넣지 않았습니다. 같은 타일을 칠한 기존 맵에도 자동으로 적용됩니다.

충돌 수정은 하단 **TileSet → Paint → Physics Layer 0**에서 합니다. 테스트 맵의 플레이어는 하단 테두리를 피해 바닥 `(40, 40)`에서 시작합니다.

자동 연결 Terrain 규칙, 소품 애니메이션·상호작용, barbarian·eyebat 캐릭터는 이 TileSet 범위에 포함하지 않았습니다.

검증: `Godot.exe --headless --path <프로젝트 경로> --script res://tests/test_dungeon_tileset.gd`
