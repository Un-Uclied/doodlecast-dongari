# Firebase 공개 클라이언트 키

`docs/firebase-config.json`과 `resources/leaderboard.json`의 `apiKey`는 Firebase 프로젝트를 식별하는 공개 클라이언트 설정입니다. 브라우저와 Windows 게임이 Firebase에 직접 연결하므로 클라이언트에서 숨길 수 있는 비밀 값이 아닙니다. Google Cloud 또는 GitHub가 Google API 키 공개 알림을 보낼 수 있습니다.

[Firebase 공식 안내](https://firebase.google.com/docs/projects/api-keys)에 따라 공개 키의 Google API 사용 범위를 제한하고, 데이터 접근은 Firebase 인증 및 보안 규칙으로 검사합니다.

2026-10-18 확인 및 적용:

- 클라이언트 키의 허용 API: Identity Toolkit, Token Service, Firestore, Cloud Datastore, Firebase Rules, Firebase Management, Cloud Logging.
- SQL Admin·AI 등 사용하지 않는 API는 허용 목록에서 제외합니다.
- 관리자 OAuth 토큰·익명 계정의 갱신 토큰·서비스 계정 비밀 키는 저장소에 포함하지 않습니다. 로그인 및 미전송 기록은 플레이어 PC의 Godot 사용자 데이터 폴더에만 저장합니다.
- 웹에서 기록을 읽을 수 있습니다. 기록 생성에는 Firebase 익명 로그인이 필요하며, 보안 규칙이 필드와 점수의 일관성을 검사합니다. 기존 기록의 변경·삭제는 일반 클라이언트에 허용하지 않습니다.

PC 설치 없이 실행하는 요구에 따라 특정 PC·웹사이트로 클라이언트를 제한하거나 별도 PC 등록을 요구하지 않습니다. 따라서 익명 클라이언트가 계산한 점수의 실제 플레이 여부까지 보증하지는 않으며, 변조 방지 서버나 App Check 검증은 구현하지 않았습니다.
