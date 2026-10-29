# UI 파일 안내

`combat_hud.tscn`은 아래 다섯 씬을 인스턴스로 배치하는 진입점입니다. 화면의 노드·크기·문구·색상은 해당 씬을 열어서 수정합니다.

| 수정할 대상 | 씬 | 동작 스크립트 |
| --- | --- | --- |
| 플레이어 체력·진행도·남은 적·점수·콤보 | `hud/status_bar.tscn` | `scripts/ui/hud/status_bar.gd` |
| 시전·적중·처치·피격·회복 비네트와 상태 문구 | `hud/combat_feedback.tscn` | `scripts/ui/hud/combat_feedback.gd` |
| 게임 오버·레벨 클리어·올 클리어, 승리 이미지와 콘페티 | `screens/results_screen.tscn` | `scripts/ui/screens/results_screen.gd` |
| 일시정지, 계속하기·메인 메뉴 버튼 | `screens/pause_screen.tscn` | `scripts/ui/combat_hud.gd` |
| 메인 메뉴로 나가기 확인, 취소·포커스 복원 | `dialogs/exit_confirmation.tscn` | `scripts/ui/dialogs/exit_confirmation.gd` |
| 메인 메뉴와 학번·이름 입력 | `main_menu.tscn` | `scripts/ui/main_menu.gd` |
| 씬 전환 페이드 | `transitions/scene_transition.tscn` | `scripts/ui/transitions/scene_transition.gd` |
| 보스전 초상화·결전 인장·입장 사운드 | `screens/boss_intro.tscn` | `scripts/ui/screens/boss_intro.gd` |
| 보스 체력·페이즈·공격 사운드 | `hud/boss_hud.tscn` | `scripts/gameplay/boss_level.gd` |
| 보스 공격 기호·남은 시간 | `hud/boss_window.tscn` | `scripts/gameplay/boss_level.gd` |

씬 경로는 프로젝트의 `scenes/ui/` 기준이고, 스크립트 경로는 프로젝트 루트 기준입니다. 결과·일시정지·확인창은 단독 편집할 때 보이도록 저장하고, 조합 씬에서 시작 시 숨깁니다.

## 공통 디자인

- 버튼·입력창·기본 글꼴: `resources/ui/menu_theme.tres`
- 공통 창 테두리와 여백: `resources/ui/styles/menu_card.tres`
- 결과 세부 기록 배경: `resources/ui/styles/result_stats.tres`
- 배경 색과 움직이는 무늬: `resources/ui/backgrounds/`
- 비네트 셰이더: `resources/ui/shaders/combat_feedback.gdshader`
- 카드의 금빛 모서리 장식: `scripts/ui/arcane_frame.gd`
- 점수·시간 표기: `scripts/ui/formatting.gd`

## 게임 코드와 연결

`scripts/ui/combat_hud.gd`가 결과 표시, 일시정지, 전투 피드백, 콤보 갱신을 각 컴포넌트에 전달합니다. 기존 `set_results()`, `show_results()`, `set_paused()`, `feedback()`, `update_combo()`, `pulse_remaining()`, `confirm_menu()` 호출은 그대로 사용합니다.

씬을 분리했으므로 `%노드이름`은 해당 하위 씬의 범위에서 접근합니다. HUD 바깥에서 결과 화면 버튼을 찾을 때는 `hud.get_node("Root/Results/%Continue")`, 전투 점수는 `hud.get_node("Root/Top/%Score")`처럼 컴포넌트를 먼저 지정합니다. 입력 포커스·일시정지 복원은 확인창 스크립트가 담당합니다.

레벨·플레이어·적·아이템 씬은 `scenes/gameplay/`, 게임 동작은 `scripts/gameplay/`, 전역 상태·음악·순위는 `scripts/autoload/`에 있습니다. 원본 이미지 팩과 맵 데이터는 이동하지 않았습니다.

보스 UI는 보스 레벨에서만 인스턴스화합니다. 체력바는 상단 HBox 안에 들어가고, 공격 기호는 별도 하단 카드에 배치됩니다. 불바닥·잔불·폭발은 `scenes/effects/boss_attack.tscn`, `boss_embers.tscn`, `boss_explosion.tscn`에서 수정합니다. 불길과 충격파 셰이더는 `resources/effects/boss_fire.gdshader`, `boss_shockwave.gdshader`입니다.

보스전에서도 `GestureCanvas/Canvas/Panel`의 조작 안내를 표시합니다. 입장 중에는 숨기고, 2초 대기·전투 중에는 표시합니다. 보스 체력 카드는 상단 HBox의 고정 폭 300, 플레이어 체력은 120입니다. 점수/시간 라벨은 고정 최소 폭의 슬롯 안에서 표시하므로 숫자 길이가 체력 카드의 폭·위치를 바꾸지 않습니다. 입장 배경 스크롤은 `resources/ui/backgrounds/boss_intro.gdshader`, 초상화와 실제 보스의 아우라는 `scenes/effects/boss_aura.tscn`에서 수정합니다.
