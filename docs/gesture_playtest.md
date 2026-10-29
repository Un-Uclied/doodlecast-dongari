# 패턴 입력 플레이 테스트

게임은 좌클릭을 누른 채 한 획으로 그리고 놓으면 판정한다. 우클릭·Escape·포커스 이탈·일시정지·사망은 진행 중인 획을 취소한다. 그리는 동안 WASD 이동과 SHIFT 대시를 사용할 수 있다.

| 문양 난이도 | 문양 |
| --- | --- |
| 1 | 세로 작대기, 가로 작대기 |
| 2 | 위로 볼록, 아래로 볼록, 소용돌이, 네모, 세모 |
| 3 | 별 |
| 회복 전용 | 하트 |

위·아래 볼록은 각진 꺾임과 완만한 곡선, 짧거나 긴 팔, 매우 좁거나 넓은 형태를 허용한다. 가로·세로의 방향은 구분한다. 네모·세모는 그리는 방향·시작점·기울기·찌그러짐을 허용한다. 직사각형과 마름모도 네모로 인식한다. 네모·세모는 기본 전투 문양 풀에서 각각 1/12의 비중으로 배정한다.

별은 교차하는 한붓별과 외곽선 별을 모두 받는다. 불규칙한 꼭짓점, 심한 비율 차이, 연결부의 겹침과 끝부분 돌출을 허용한다. 하트도 비대칭·둥근 바닥·얕은 홈·겹친 연결부를 받는다. 소용돌이는 약 1~3바퀴의 양방향·안팎 입력을 허용하되 단순한 원과 구분한다.

## 현재 인식 방식

`scripts/gestures/gesture_recognizer.gd`는 입력을 64점으로 정리한 뒤 교차·근접한 연결부에서 가장 큰 닫힌 몸체를 찾는다. 도형 밖으로 뻗은 시작·끝 꼬리는 몸체에서 분리한다. 몸체를 32점 점군으로 바꾸고, 회전·가로세로 비율을 맞춘 뒤 모든 후보를 같은 일대일 최소비용 대응(Hungarian assignment)으로 비교한다. 각 입력 점은 서로 다른 예시 점 하나와 대응하며, 하트에만 더 유리한 별도 점수를 주지 않는다. 방향·교차·감김·몸체의 홈은 후보를 구분하는 근거로 사용한다. 하트의 홈도 꼬리가 제거된 몸체에서 확인하므로, 선이 넘어간 네모·세모를 하트로 오인하지 않는다.

`resources/patterns/catalog.tres`에 9개 문양이 등록되어 있다. `PatternCatalog.TIER_1/TIER_2/TIER_3`를 적·보스가 공유하고 `pattern_badge.gd`가 적과 회복 아이템의 같은 10px 아이콘·배경·첫 문양 테두리·화살표를 그린다. 두 표시 모두 조명에 영향을 받지 않는다. 보스 HUD의 문양은 24px다. 하트는 회복 아이템 전용이며 적·보스·연습 적의 공격 문양에 배정하지 않는다. 하트 입력은 공격이나 콤보를 처리하지 않는다.

## 최소 크기와 리소스

`scenes/gestures/gesture_canvas.tscn`의 Canvas → **Min Stroke Size Percent** 기본값은 **2%**다. 그린 모양의 긴 변이 화면 짧은 변에서 차지하는 비율이며, 1280×720에서는 14.4px다. 올리면 더 크게 그려야 한다. 클릭·한 점·동일 점·잘못된 좌표는 거절한다.

각 `.tres`의 `id`, `display_name`, `samples`, `closed`, `rotation_invariant`, `max_error`는 기존 Inspector 편집을 유지한다. `closed`는 닫힌 샘플을 비교하는 설정이며 입력의 끝을 반드시 정확히 닫아야 한다는 뜻은 아니다. 같은 모양의 실제 입력을 예시로 더할 수 있지만, 템플릿을 변형한 테스트만으로 인식률을 평가하지 않는다.

## 검증

```powershell
& 'C:/Users/user/Desktop/Godot.exe' --headless --path . --script res://tests/test_gesture_body.gd
& 'C:/Users/user/Desktop/Godot.exe' --headless --path . --script res://tests/test_qa_patterns.gd
& 'C:/Users/user/Desktop/Godot.exe' --headless --path . --script res://tests/test_gesture_recognizer.gd
& 'C:/Users/user/Desktop/Godot.exe' --headless --path . --script res://tests/test_gesture_tolerance.gd
& 'C:/Users/user/Desktop/Godot.exe' --headless --path . --script res://tests/test_handdrawn_patterns.gd
& 'C:/Users/user/Desktop/Godot.exe' --headless --path . --script res://tests/test_gesture_input.gd
& 'C:/Users/user/Desktop/Godot.exe' --headless --audio-driver Dummy --path . res://tests/test_qa_update.tscn
```

`test_qa_patterns.gd`는 QA 이미지에서 따로 옮긴 15개 도형을 양방향으로 검사하고 기울어진 네모·세모를 검사한다. 첨부 PNG에는 실제 마우스 획의 시간·순서가 없으므로 이 좌표화 테스트와 별도로 사람의 새로운 입력으로 최종 QA를 해야 한다.

`test_qa_update.tscn`은 기존 Firestore 기록 조회·로컬 캐시, 예고 후 플레이어가 접근해도 유지되는 스폰, 폭탄 문양 제한, 하트의 회복 전용 처리, 대시 후 연습·6종 적/8종 공격 문양과 하트 아이템·선택 난이도 재시작과 세 난이도 보스전 전체 흐름을 검사한다. 실제 렌더러에서는 `.godot/qa-{onboarding,boss-intro,boss-grid,boss-window}.png`를 저장한다.

`test_pattern_adjustments.tscn`은 전체 난이도의 하트 제외, 네모·세모 빈도, 마름모 인식과 경고 필드의 중앙 채움·발동 시점을 검사한다. 실제 렌더러에서 가로·세로 필드의 중앙과 양 끝 픽셀도 확인하며 `.godot/warning-center-preview.png`를 저장한다. `test_debug_mode.tscn`은 코나미 입력으로 보스전 하나에 진입하고 회복·클리어·순위 미전송·일반 모드 복귀를 검사한다.

`test_gesture_body.gd`는 두 번째 QA 이미지의 꼬리가 교차한 네모·세모와 시작 꼭짓점·꼬리 길이·비율·회전·역방향·잡음을 바꾼 총 184개 입력을 검사한다. 원본 PNG에는 실제 획의 시간·순서가 없으므로 옮긴 경로와 별도로 실제 마우스 입력 QA가 필요하다.
