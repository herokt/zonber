# 출시 준비

> 2026-09-22 기준. 현재 버전 `1.3.6+136`(pubspec.yaml). 이번 업데이트(존 3종·존버 캐릭터·상점·일일 미션)는 **1.4.0** 으로 올려 내보낸다.

## 체크리스트

| # | 항목 | 상태 | 할 일 · 담당 |
|---|---|---|---|
| 1 | 밸런스 플레이테스트 | ⏳ | 스테이지별 10판 → 통계 화면 "플레이 기록 복사"로 CSV 전달 → 수치 조정(`lib/playtest_log.dart`) |
| 2 | Firestore 규칙 강화 | ✅ 준비 · ⏳ 배포 | `firestore.rules` 시험 28건 통과(`node scripts/test_rules.mjs`). 배포 전 기존 유저 문서 점검 → `firebase deploy --only firestore:rules` · docs/SECURITY.md |
| 3 | 백오피스 관리자 로그인 | ✅ 준비 · ⏳ 배포 | `AdminGate`(Google 로그인 + 허용 이메일). 백오피스 웹 다시 배포(`deploy_admin.bat`). Firebase 콘솔 → Authentication → Google 로그인 사용 설정 확인 |
| 4 | 이메일 비공개 문서로 이전 | ✅ 새 앱 · ⏳ 기존 문서 | 기존 `users/*.email` → `users/*/private/account` 옮기기는 옛 버전이 줄어든 뒤(데이터 이동이라 따로 확인받고) |
| 5 | 일일 미션 · 출석 | ✅ | docs/SHOP.md |
| 5-1 | 장비 능력치 · 캐릭터 코인 해금 | ✅ | docs/SHOP.md — 코인 쓸 곳 |
| 5-2 | 유저별 플레이 기록 | ✅ 앱 · ⏳ 규칙 배포 | `users/{uid}/runs`(lib/run_history.dart) — 판마다, 게스트 포함 |
| 5-3 | 백오피스 개편 | ✅ 코드 · ⏳ 배포 | 대시보드 · 유저(상세·플레이 기록·관리) · 랭킹 관리 · 플레이 기록 · 경제. `firebase deploy --only firestore:indexes` 필요(runs.timestamp) |
| 5-4 | 시즌 구조 | ✅ | `lib/season.dart` — 랭킹은 현재 시즌 시작 이후만, 기록에 `season` |
| 5-5 | 자동 테스트 | ✅ | `flutter test` — test/logic_test.dart 16개(코인·장비·미션·스테이지·시즌) |
| 6 | 개인정보처리방침 | ✅ 갱신 | `docs/privacy.html` 시행일 2026-09-22 — 게스트 통계·코인·외형 공개 반영. 게시 위치에 다시 올린다 |
| 7 | 인앱 결제(광고 제거) | ❌ | Play Console · App Store Connect 에 상품 `remove_ads`(iOS `com.zonber.game.remove_ads`) 등록 → `main.dart` 의 `IAPService().initialize()` 주석 해제 → 상점 "광고 제거 · 준비 중" 연결 |
| 8 | 스토어 등록 자료 | ❌ | 새 캐릭터·상점·3개 스테이지 스크린샷(폰 6.5"·태블릿), 설명 문구(ko/en), 그래픽 이미지(`store/feature_graphic.png` 교체 여부) |
| 9 | 버전 · 빌드 | ❌ | `version: 1.4.0+140` · `FORCE_TEST_ADS` 없이 릴리스 빌드 · 서명 확인 |
| 10 | 시즌 정책 | ✅ 채택 | 아래 정책대로. 1.4.0 출시일에 `Season.starts` 에 시즌 1 시작을 추가 |
| 11 | 중국어 · 일본어 | ✅ 번역 · ⏳ 검수 | 전체 번역(원어민 검수 전). 검수 뒤 `LanguageManager.showDraftLanguages` 를 켠다 |
| 12 | 아트 2차 | 보류 | 요청으로 보류 |
| 13 | 명패 → 뱃지 46종 | ✅ | docs/BADGES.md — 옛 명패는 로그인 시 랭킹 뱃지로 옮김 |

## 시즌 정책

난이도 수치를 바꿀 때마다 예전 기록과 새 기록이 같은 판에 섞인다. 제안:

- **랭킹 기간 필터(주·월·올해)는 그대로** 두고, 난이도가 크게 바뀌면 **시즌 번호**를 올린다.
- 기록 문서에 `season` 필드(정수)를 넣고, 랭킹은 **현재 시즌 기록만** 보여 준다. 이전 시즌 1~3위는 "명예의 전당"에 남긴다.
- 뱃지는 시즌이 바뀌어도 유지한다(명패는 2026-09-22 제거 → 뱃지).
- 시즌 1 = 1.4.0 출시일. 이번 골키퍼 속도 조정 전 기록은 시즌 0 으로 둔다.
- 사소한 조정(±5% 이내)은 시즌을 올리지 않는다.
