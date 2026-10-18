# DOODLECAST · 파이게임부 동아리 발표회

Godot 4.7.1 마법 액션 게임과 파이게임부 발표회 실시간 순위 사이트입니다.

- [게임 다운로드](https://github.com/Un-Uclied/doodlecast-dongari/releases/latest)
- [동아리 순위 사이트](https://un-uclied.github.io/doodlecast-dongari/)

Windows ZIP을 내려받아 압축을 풀고 `DOODLECAST.exe`를 실행하면 됩니다. 게임 데이터는 실행 파일에 포함되어 있습니다. Godot 설치, Firebase 설정, PC 등록은 필요 없습니다. WASD로 이동하고 Shift로 대시하며, 마우스 왼쪽 버튼으로 적 머리 위의 패턴을 그립니다. Esc로 일시정지합니다.

## 게임과 순위 연결

게임 오버 또는 여섯 레벨의 최종 클리어 때 한 판의 최종 기록을 Firestore `doodlecast_runs`에 저장합니다. 중간 레벨 클리어는 같은 판으로 이어지고, 일시정지에서 게임을 중단한 기록은 올리지 않습니다. 난이도·콤보·시간 감점을 포함한 게임의 총점을 사용합니다. 횟수 제한 없이 플레이하며 사이트에는 참가자별 최고 점수를 표시합니다. 동점이면 피격 횟수, 서버 저장 시각 순입니다.

최초 실행 시 Firebase 익명 계정을 자동 생성합니다. 계정과 전송 대기 기록은 Windows의 `%APPDATA%/Godot/app_userdata/DOODLECAST/leaderboard/`에 보관합니다. 네트워크 오류 때는 10초마다 재시도하고, 게임을 껐다 켜도 대기 기록을 이어서 전송합니다. 같은 판을 중복 전송해도 하나의 기록만 저장합니다. 결과 화면에 전송 상태를 표시합니다.

학번은 앞의 0을 포함한 5자리 전체를 표시하고, 이름은 `홍*동`처럼 가운데를 가립니다. 입력한 이름 원문은 서버로 보내지 않습니다. 참가자 구분에는 학번의 SHA-256을 사용하고, 공개 표시명은 `학번 11013 · 홍*동` 형식으로 저장합니다. 순위에는 난이도·도달 레벨/전체 클리어·처치 수·피격 수·플레이 시간과 점수를 보여줍니다.

누구나 실행할 수 있도록 익명 로그인 사용자의 신규 기록 작성을 허용합니다. 보안 규칙이 필드·범위·점수와 시간 감점의 일관성을 검사하고 기존 기록 변경·삭제는 차단합니다. 실제 플레이 여부를 검증하는 서버나 점수 변조 방지 기능은 없습니다. 관리자 계정·서비스 계정 키는 게임에 포함하지 않습니다.

Firebase 클라이언트 API 키는 공개 설정값입니다. 관리자 키와 달리 저장소·웹사이트·실행 파일에 포함되며, 실제 접근 권한은 인증과 Firestore 보안 규칙으로 검사합니다. Google API 허용 목록도 인증·Firestore 관련 항목으로 제한했습니다. [보안 설정과 공개 키 안내](docs/security.md)를 참고하세요.

## 사이트 수정

`docs/`의 사이트는 [기존 동아리 사이트](https://github.com/Un-Uclied/pygamebu-dongari/tree/main/docs)를 복사했습니다. 파랑·흰색 테마, 레이아웃, Pretendard 폰트, 상품과 부스 안내는 원본 그대로입니다. 대표 게임명·연결할 기록 컬렉션·게임 규칙 문구만 현재 데이터에 맞췄습니다.

- 상품과 부스 안내: `docs/site-content.json`
- 화면과 스타일: `docs/index.html`, `docs/style.css`
- Firebase 공개 앱 설정: `docs/firebase-config.json`, `resources/leaderboard.json`
- 원본 출처와 폰트 라이선스: `docs/SOURCE.md`, `docs/FONT-LICENSE.txt`

GitHub Pages는 `main` 브랜치의 `/docs`에서 배포합니다. 점수 갱신에는 사이트 재배포가 필요 없습니다. `?demo=1`은 실제 데이터에 기록하지 않는 예시 화면입니다.

## 개발과 검사

Godot 4.7.1에서 `project.godot`를 열면 게임을 편집할 수 있습니다. 난이도별 맵은 `scenes/maps/`에 있고 게임 구조는 `docs/combat.md`에 설명되어 있습니다.

```powershell
node tests/test_site.mjs
$env:DOODLECAST_OFFLINE = '1' # 자동 테스트가 실제 순위에 기록하지 않도록 합니다.
Godot.exe --headless --path . res://tests/test_leaderboard.tscn
Godot.exe --headless --path . res://tests/test_menu_polish.tscn
```

실제 플레이에서는 위 환경 변수를 제거합니다. Firebase 보안 규칙은 관리자 PC에서 `npx firebase-tools deploy --only firestore:rules --project pygame-bu-final`로 배포합니다. 다른 플레이어 PC에는 이 작업이 필요 없습니다.

Windows 빌드는 Godot의 `Windows Desktop` 내보내기 프리셋을 사용합니다. 편집기와 같은 버전의 Windows 내보내기 템플릿을 설치하거나 프리셋의 사용자 지정 템플릿 경로를 지정하세요. `tools/build_windows.ps1`로 실행 파일과 ZIP을 만듭니다.
