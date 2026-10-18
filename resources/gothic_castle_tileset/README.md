# Gothic Castle: Godot 리소스

원본 PNG 102개는 수정하지 않고 참조합니다. Aseprite 원본은 편집용으로 보존했습니다.

- `asset_gallery.tscn`: 열고 **F6**으로 전체 애셋과 애니메이션을 확인합니다. 아래로 스크롤합니다.
- `TileSets/castle_tiles.tscn`: TileMapLayer를 레벨로 드래그하고 타일을 칠합니다. 직접 TileMapLayer를 만들었다면 `castle_tileset.tres`를 Tile Set에 지정합니다.
- `Characters/noble_knight.tscn`: AnimatedSprite2D. `idle_*`, `walk_*`, `push_*`, `attack_*`, `roll`, `fall`, `death`, `static` 애니메이션입니다. `*_side`는 `flip_h`로 좌우를 전환합니다.
- `Characters/block.tscn`: `idle`, `north`, `south`, `east`, `west` 애니메이션입니다.
- `Props/Animated/*.tscn`: 촛불과 등불은 자동 반복됩니다. 문·상자는 `open`/`close`, 스위치는 `activate`/`deactivate`, 가시는 `extend`/`retract`를 재생합니다. 상호작용 소품은 초기 상태에서 멈춰 있습니다.
- `Props/Static/*.tscn`: 단일 이미지 소품 48개. 레벨로 드래그합니다.
- `*_frames.tres`: 기존 AnimatedSprite2D의 Sprite Frames에 직접 지정해도 됩니다.

모든 스프라이트의 원점은 아래쪽 중앙입니다. 16×16 타일 기준이며, 소품 아틀라스의 16×32·32×32 오브젝트는 한 타일로 유지했습니다. 타일 소스 ID: 0 바닥, 1 벽, 2 계단, 3 16×16 소품, 4 16×32 소품, 5 32×32 소품. 완전히 투명한 칸은 제외했습니다.

프레임 속도는 게임용 시작값(6~12 FPS)입니다. 원본에는 타이밍 메타데이터가 없습니다. 충돌, 자동 타일 연결 규칙, 캐릭터 이동, 문 잠금 같은 게임 로직은 레벨과 게임 규칙에 맞춰 추가합니다.

검증: `Godot.exe --headless --path <프로젝트 경로> --script res://Resources/GothicCastle/validate_assets.gd`

라이선스: 원본 팩은 비상업용이며 제작자 크레딧을 요구합니다. 공개 전 원본 다운로드 페이지에서 제작자 이름을 확인하여 게임 크레딧에 넣어야 합니다. 상세 조건은 원본 폴더의 `Gothic Castle Tileset - Non-Commercial License Agreement.txt`를 확인하세요.
