# 난이도별 맵 편집

Godot에서 아래 씬을 열어 수정합니다. 저장하면 보스전을 포함한 해당 난이도의 1~6레벨에 반영됩니다. 각 맵은 F6으로 바로 플레이할 수 있습니다.

| 난이도 | 편집할 씬 |
| --- | --- |
| EASY | `easy_map.tscn` |
| NORMAL | `normal_map.tscn` |
| HARD | `hard_map.tscn` |

- `TileMapLayer`: 바닥·벽을 칠합니다.
- `TileMapLayerFurniture`: 문·소품을 칠합니다. 닫힌 문은 기존 소스 2를 사용하면 클리어 시 소스 3의 열린 문으로 자동 교체됩니다.
- 횃불(`torch1`, 소스 5)·촛대(`candlestick1`, 소스 1)를 칠하면 실행할 때 불꽃 위치에 조명이 자동으로 붙습니다. `combat_level.tscn`의 `Ambient`로 전체 어두움을, `scenes/effects/torch_light.tscn`으로 빛의 색·범위를 조정합니다.
- `Player`: 시작 위치를 옮깁니다. 발밑이 연결된 바닥에 놓이도록 배치합니다.
- `TileMapLayerPits`: 통과할 수 없는 구덩이를 칠합니다. TileSet의 `tile_walls` 충돌 다각형이 설정된 타일은 자동으로 적의 이동 경로와 스폰 후보에서 제외됩니다. 각 난이도의 구덩이 배치는 보스전을 포함한 해당 1~6레벨에 반영됩니다.

타일 배치와 시작 위치는 난이도별로 독립입니다. TileSet의 타일 그림·충돌 설정은 세 맵이 공유합니다.

상속 구조는 `combat_level.tscn → 난이도별 map.tscn → level_01~06.tscn`입니다. 공통 전투·HUD·효과음은 `combat_level.tscn`에서 관리합니다. 공통 씬에는 타일 배치가 없으므로 플레이 확인은 위 맵 씬이나 개별 레벨에서 합니다. 개별 레벨은 `difficulty`, `level_number`, `mode` 설정을 유지합니다. 특정 레벨에서만 지형을 바꾸려는 경우에만 그 레벨 씬에 타일 배치를 덮어씁니다.

6레벨에는 `scripts/gameplay/boss_level.gd`가 연결되어 있습니다. 해당 난이도의 맵·소품·구덩이·플레이어 시작 위치와 추적 카메라를 그대로 사용합니다. 보스의 처음 위치는 맵 중앙에 가까운 이동 가능한 바닥이며, 격자·전맵 공격 범위는 기존 맵 경계에서 계산합니다. 난이도별 공격 타임·경고 시간은 `WINDOW_SECONDS`·`WARNING_SECONDS`에서 수정합니다. DEBUG는 NORMAL의 6레벨 보스전 하나만 사용합니다.

기존 `scenes/sandbox/test_scene.tscn`은 이동·제스처 테스트용입니다. 여기를 편집해도 실제 난이도별 맵은 바뀌지 않습니다.

보스 조정 값은 `boss_level.gd` 상단에 모았습니다. `MAX_BOSS_HEALTH`는 200, 기호 7개 성공 시 `WINDOW_DAMAGE`는 20입니다. 체력 66%·33% 이하에서 2·3페이즈로 넘어갑니다. 공격은 격자·부채꼴 화염·연속 폭발·돌진·회전 나선탄·꽃잎 탄막·대각선 연속 화염·조준 부채탄 8종을 섞어서 순환합니다. 기본 탄속 `BULLET_SPEED`는 EASY/NORMAL/HARD에서 240/260/290이며 페이즈마다 15씩 증가합니다. `ATTACKS_PER_CYCLE`은 기호 입력 전 공격 횟수, `FIRE_VOLUME_DB`는 불 효과음 크기입니다. 보스 탄의 곡선 이동은 `scripts/gameplay/boss_projectile.gd`, 외형은 `scenes/gameplay/enemies/boss_projectile.tscn`에서 수정합니다.

노말/하드의 DIFF 상한은 3/4이고, `level.gd`의 `DIFFICULTY_CAPS`에서도 제한합니다. 보스 대립 연출 뒤 `READY` 상태에서 2초간 이동한 후 공격을 시작합니다. 플레이어 공격 시간은 EASY/NORMAL/HARD 14/12/10초, 부채꼴 예고는 `SECTOR_WARNING_SECONDS`의 1.8/1.6/1.4초입니다. 조준 부채탄 간격은 페이즈별 0.70/0.65/0.60초입니다. 보스 배경음은 `boss_bgm.mp3`, 화염은 `explosion.wav`, 일반 적·보스 탄막은 `laser.wav`를 사용합니다.
