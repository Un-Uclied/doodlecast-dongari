# 플레이어와 맵 충돌

`scenes/test_scene.tscn`을 열어 F6, 또는 F5로 실행합니다.

- WASD: 이동. 대각선 이동 속도는 일정합니다.
- 캐릭터: `Free - Pixel Art Character 1`의 Blue Head. 32×32 프레임으로 상하좌우 Idle 5프레임, Walking 4프레임을 사용합니다. 애니메이션 리소스는 `resources/player/blue_head_frames.tres`입니다.
- Shift: 이동 방향으로 0.36초 대시. 정지 상태에서는 마지막으로 바라본 방향을 사용합니다. 재사용 간격은 시작 시점부터 0.55초입니다. 전용 대시 애니메이션 대신 이동 방향의 Walking을 재생합니다. 대시가 실제로 시작할 때만 `sounds/dash.wav`를 재생하고, 재사용 대기 중 눌렀을 때는 재생하지 않습니다.
- 대시 중에는 연보라색으로 반투명해지고 `take_damage()`를 무시합니다. 벽은 통과하지 않습니다.
- 대시 중 이동 반대 방향으로 보라·금빛 파티클을 남깁니다. 월드 좌표에 남는 입자는 0.25초에 걸쳐 사라지며, 대시 종료·사망·클리어 시 새 입자 방출을 멈춥니다. 일시정지 시 함께 정지합니다. 모양은 `scenes/effects/dash_particles.tscn`에서 조정합니다.
- 체력은 5이며 `take_damage()`가 성공할 때마다 1씩 줄어듭니다. 피격 직후 기본 1초 동안 추가 피해를 막고, 처음 붉은 피격 표시 뒤 반투명하게 깜빡입니다. Inspector의 `Hurt Invulnerability Duration`으로 시간을 바꿉니다. 일시정지 중에는 무적 시간도 멈춥니다. 0 HP이면 사망합니다. 접촉 잡몹은 실제 피해를 줬을 때만 사라집니다. 대시·피격 무적 중에는 적과 플레이어 모두 유지되며, 무적이 끝난 뒤에도 겹쳐 있으면 접촉 피해를 받습니다.
- 실제 피해에만 `sounds/player_hurt.wav`를 한 번 재생합니다. 무적 중의 접촉은 소리·피격 입자·흔들림을 추가하지 않습니다.
- 실제 전투 맵의 구덩이는 `TileMapLayerPits`의 충돌로 통과를 막습니다. 플레이어는 낙사하지 않고, 적은 구덩이를 피해 이동합니다. 맵 밖이나 빈 타일은 자동으로 낙사시키지 않습니다. 전투 레벨에서는 사망 후 결과 화면에서 메인 메뉴로 돌아가 새 게임을 시작합니다.
- 사망·낙사 전용 애니메이션은 사용하지 않습니다. 사망하면 이동과 현재 애니메이션을 정지합니다.
- Camera2D는 플레이어 자식으로 2.5배 확대하여 따라갑니다.
- Wand는 캐릭터 스프라이트의 실제 중심(Offset 포함)을 축으로 마우스 방향에 공전하고, 이미지의 +X 방향인 흰 끝을 마우스로 향합니다. 반경은 씬에서 배치한 Wand와 스프라이트 중심 사이 거리로 정해집니다(현재 약 17px). 위쪽으로 향할 때는 캐릭터 뒤에, 아래쪽에서는 앞에 그립니다.
- 기존 `Wand/Marker2D` 위치에서 0.14초 길이의 보라·금빛 잔상과 작은 마법 입자를 표시합니다. 잔상은 지나간 월드 위치에 남아 이동·회전해도 끌려가지 않으며, 순간이동 시 긴 선이 생기지 않도록 초기화합니다. 일시정지는 함께 멈추고, 사망·클리어 후에는 공전을 멈춘 뒤 남은 잔상만 짧게 사라집니다. 로직은 `scripts/wand.gd`, 모양은 플레이어 씬의 Marker2D 자식에서 조정합니다.

## 구덩이 배치

난이도별 맵 씬의 `TileMapLayerPits`에 구덩이 타일을 칠합니다. TileSet의 Physics Layer 0에서 Collision Layer를 **1: tile_walls**로 두고, 통과를 막을 타일에 충돌 다각형을 넣습니다. 레벨 초기화 시 다른 타일 레이어의 해당 충돌도 길찾기 격자와 적 생성 후보에 반영합니다.

`scenes/pit.tscn`과 `fall()`은 기존 낙사 회귀 테스트용으로 남아 있습니다. 현재 게임 맵은 충돌 타일을 사용합니다. 일반 피격은 `take_damage()`를 호출합니다.

## TileSet의 충돌 편집

현재 맵은 `resources/Dungeon/TileSets/dungeon_tileset.tres`의 Physics Layer 0을 사용합니다. Collision Layer는 **1: tile_walls**, 캐릭터는 **2: Player**, 캐릭터 Collision Mask는 **1: tile_walls**입니다.

던전 아틀라스(소스 ID 0)의 벽과 돌 테두리를 막습니다. 바닥, 열린 문 안쪽, 절벽 아래 장식, 소품은 막지 않습니다. 현재 맵의 플레이어 시작점은 `(0, 266)`입니다.

1. TileMapLayer를 선택하고 Inspector의 **Tile Set**을 클릭합니다.
2. TileSet 리소스의 **Physics Layers**를 펼쳐 레이어와 Collision Layer를 확인합니다.
3. 하단 **TileSet** 편집기에서 **Paint → Physics Layer 0**을 선택합니다.
4. 타일을 골라 충돌 다각형을 수정합니다. 통과할 문이나 장식 타일은 다각형을 지우세요.

같은 타일을 칠한 모든 위치에 그 충돌이 적용됩니다. 일부 위치만 통과시키려면 충돌이 없는 Alternative Tile을 만들어 그 위치에 칠합니다. 구덩이는 이동을 막는 다각형으로 판정합니다.

검증: `Godot.exe --headless --path <프로젝트 경로> --script res://tests/test_player.gd`

지팡이 검증: `Godot.exe --headless --path <프로젝트 경로> --script res://tests/test_wand.gd`
