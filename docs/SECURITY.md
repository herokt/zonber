# 보안 · Firestore 규칙

> 2026-09-22 강화. 규칙 원본: [`firestore.rules`](../firestore.rules). 시험: `node scripts/test_rules.mjs`(배포 없이 Rules API 로 허용·거부 경우들 확인).

## 누가 무엇을 쓰나

| 경로 | 읽기 | 쓰기 |
|---|---|---|
| `maps/{mapId}` | 누구나 | 앱: `playCount` +1 만 · 관리자: 전부 |
| `maps/{mapId}/records/*` | 누구나 | 회원(게스트 제외) 본인 uid · 서버 시각 · 생존 0~3600초로 생성만. 삭제는 본인(부활·탈퇴)·관리자. 수정은 관리자 |
| `users/{uid}` | 로그인한 누구나(랭킹 표시) | 회원 본인(익명 제외) · 관리자. 코인 0~1천만 정수, 변경권 0~999, 닉네임 40자 이하 |
| `users/{uid}/private/account` | 본인 · 관리자 | 본인 · 관리자 — **이메일은 여기** |
| `users/{uid}/runs/*` | 본인 · 관리자(collection group 포함) | 본인이 추가만(서버 시각, 0~3600초). 수정 불가, 삭제는 본인(탈퇴)·관리자 |
| `custom_maps/*` | 누구나 | 로그인하면 생성, 삭제는 작성자(`authorUid`)·관리자 — 옛 UGC, 앱은 2026-09-22부터 쓰지 않음(규칙만 남음) |

- **관리자** = Google 로그인 + 인증된 이메일 `herokt851103@gmail.com`. 목록은 `firestore.rules` 의 `isAdmin()` 과 `lib/backoffice/admin_gate.dart` 의 `kAdminEmails` 두 곳 — 같이 고친다.
- 백오피스(`/secret_admin`, `lib/backoffice/main_backoffice.dart`)는 `AdminGate` 로 관리자만 들어간다(예전엔 익명 로그인으로 누구나).
- 색인: `firestore.indexes.json` — 백오피스가 모든 유저의 runs 를 시간순으로 읽는 collection group 색인. 규칙과 함께 `firebase deploy --only firestore` 로 배포.
- 옛 버전 앱이 막히지 않게 필드 목록(`hasOnly`)은 강제하지 않는다. 옛 앱은 유저 문서에 `email` 을 계속 쓸 수 있다 → 옛 버전이 충분히 줄면 규칙에서 `email` 쓰기를 막고, 기존 문서의 `email` 을 비공개 문서로 옮긴다.

## 남은 한계

- 코인·기록 값은 앱이 계산한다 — 규칙은 범위만 막는다. 완전한 검증은 Cloud Functions(기록 제출 서버 검증, 코인 적립 서버 처리)가 필요하다.
- 익명 클라이언트 SDK 로 쓰던 관리 스크립트는 새 규칙에서 막혀 2026-09-22 삭제했다. DB 를 고칠 일이 있으면 gcloud 토큰 REST 방식(`scripts/test_rules.mjs` 처럼)으로 새로 만든다.
