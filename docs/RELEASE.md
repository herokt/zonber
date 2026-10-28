# 출시 준비

## 버전 규칙 · 업데이트 안내 (2026-10-12)

- 버전은 `pubspec.yaml` 의 `version: 이름+빌드` 하나(예 `2.1.0+210`). 앱 화면(프로필 › 설정 › 앱 버전)에는 **v2.1.0 (210)** 으로 보이고, 로그인한 유저 문서에 `appVersion`·`appBuild` 로 남는다.
  - **이름**: 기능이 크게 늘면 가운데 자리(2.0.x → 2.1.0), 고친 것만이면 끝자리(2.1.0 → 2.1.1).
  - **빌드**: 스토어에 올릴 때마다 +1(Android·iOS 같은 번호). 한 번 올린 번호는 다시 못 쓴다 — 맥에서 따로 빌드했다면 그보다 크게.
- **업데이트 안내**: 스토어 심사가 끝나 실제로 받을 수 있게 되면 **백오피스 › 운영 › 앱 버전** 에서 그 플랫폼의 스토어 버전 이름(예 2.1.1)만 적고 저장한다. 빌드 번호는 백오피스가 채운다 — 이 백오피스와 같은 버전이면 그 빌드, 아니면 그 버전을 쓰는 회원 기록의 빌드(앱은 빌드로 견준다). 새 버전을 낼 때 백오피스도 같은 커밋으로 배포해 둔다(`deploy_admin.bat`).
  그보다 낮은 앱은 홈에서 "새 버전이 나왔어요" 창(나중에 → 3일 뒤 다시). **필수 버전**을 적으면 그보다 낮은 앱은 창을 닫을 수 없다(조심해서).
  Android·iOS 는 심사 시간이 달라 따로 올린다. 화면 아래 "유저 앱 버전"에서 안내를 받을 사람 수를 미리 본다.
  (lib/app_release.dart · lib/services/update_service.dart · Firestore `config/app_release` — 규칙 배포 필요: `deploy_admin.bat`)

## 출시 기록

### 2.3.0 (219) — 2026-10-28
- 내용: 명예의 전당 트로피 홀(`pages/hall_of_fame_page.dart`, Gemini 트로피) · 가방(상점) 다시 짬 · 홈 캐러셀 양쪽 무한 · 랭킹 좌우 스와이프로 존 전환 · 장비 코인 +% 가격 구간 규칙
- 체크: 번역 키 539 네 언어 · `flutter test` 92 · `flutter analyze lib test`(info 2 기존)
- 빌드: `flutter build appbundle --release` — Claude 의 Bash 샌드박스에서는 Gradle 데몬이 "Unable to establish loopback connection" 으로 실패한다 → 샌드박스 없이(PowerShell) 돌리면 된다. 결과 88MB, 복사본 `build/zonber-2.3.0-219.aab`
- **Android**: 2026-10-28 같은 번들로 **비공개 테스트 - Alpha**(테스터 미지정 경고) + **프로덕션 100%** 두 건을 게시 개요에서 검토 제출. 출시 노트 ko/en/ja/zh 4개 언어. 브라우저 도구는 10MB 넘는 파일을 못 올려 AAB 는 Play Console 에 사람이 끌어다 놓았다(Play API 서비스 계정은 없음)
- **iOS**: 2.3.0 (219) 2026-10-28 TestFlight 업로드(Admin 키 `xcodebuild -exportArchive`) → 같은 날 심사 제출(App Store Connect API), 승인 후 자동 출시. 새로운 기능 ko/en/ja/zh 4개 언어(`store/app_store_listing.md`). 설명·스크린샷은 2.2.0 그대로. 심사 메모 = 아동 대상 광고 · ATT 없음 · 개인정보 라벨 "기타 진단 데이터" 한 항목 설명
- 심사 통과 뒤 할 일: 백오피스 › 앱 버전 에 Android 2.3.0 · iOS 2.3.0 · App Store 개인정보 라벨 "기타 진단 데이터"를 추적 아니요로(`store/data_safety.md`)

### 2.2.0 (218) — 2026-10-27
- 내용: 시즌제 랭킹(주·월·올해 제거) + 명예의 전당 · 장비·꾸미기는 외형만(코인 +% 만) · 펫 → 오라 · 첫 판 안내 · 홈 ? 게임 방법 · 게스트 최고 기록·코인 기기 저장 · 210초 뒤 완만한 난이도 상승 · 닉네임 30일에 한 번 무료 · 뱃지 41종
- 체크: 번역 키 · `flutter test` 92 · `flutter analyze`(info 2 기존) · functions 9 · 규칙 시험 125 통과
- **서버 먼저** 2026-10-26 `deploy_admin.bat` — 규칙·색인(`config/season` · `hall_of_fame`) · 함수(`seasonTick` 새로 만듦) · 백오피스 · 호스팅
- **Android**: 프로덕션 100%(모든 국가) · 2026-10-27 검토 제출(게시 개요 13건 = 버전 + ko/en/ja/zh 자세한 설명 · 휴대전화 스크린샷 8장). Play Console 계정 = Chrome 의 mycrewdeveloper@ (개발자 계정 ToyDream)
- **iOS**: 2.2.0 (218) 2026-10-27 심사 제출(2026-10-28 확인: 출시됨) — 4개 언어 설명 · 새로운 기능 · 스크린샷(iPhone 6.9" · iPad 13" 각 10장), 승인 후 자동 출시. 제출 때 연령 등급 설문에 새 필수 질문(소셜 미디어 · 13세 미만 소셜 미디어 비활성화)이 생겨 둘 다 "아니요"로 답함(피드·게시물·채팅 없음, 등급 4+ 그대로)
- 스크린샷은 기기 없이 웹 빌드로 찍었다(`scripts/store_shots_web.mjs` — `store/play_store_listing.md` 머리). 시즌 칩은 `StoreShot.seasonNow`(시즌 1 안)
- 심사 통과 뒤 할 일: 백오피스 › 앱 버전 에 Android 2.2.0 (iOS 는 출시 뒤 따로)

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
| 7 | 인앱 결제(광고 제거) | 보류 | 2026-10-26 코드 제거(`iap_service.dart` · `in_app_purchase`). 다시 할 땐 패키지부터 새로 넣는다 |
| 8 | 스토어 등록 자료 | ✅ iOS · ✅ Android | App Store 스크린샷 4개 언어 × iPhone 6.9"·iPad 13" × 10장(`store/screenshots/`, 2.0.3 화면 — 결과·이 기록 깨러 가기·뱃지·이벤트 추가, `scripts/compose_ios_shots.mjs`) · 소개 문구 ko/en/ja/zh-Hans(`store/app_store_listing.md`). Play: 휴대전화 스크린샷 1080×1920 × 6장 × 4개 언어(`store/screenshots_play/`, 스크린샷 모드로 기기에서 찍어 합성) · 등록 문구 ko-KR/en-US/ja-JP/zh-CN · 512 아이콘(`store/play_store_listing.md`). Play 그래픽 이미지 1024×500 × 4개 언어(`store/feature_graphic/`) |
| 9 | 버전 · 빌드 | ❌ | `version: 1.4.0+140` · `FORCE_TEST_ADS` 없이 릴리스 빌드 · 서명 확인 |
| 10 | 시즌 정책 | ✅ 설정 | 백오피스 › 시즌(연간·분기·월간·N일) — 아래 §시즌 정책. 기본은 연간 · 시즌 1 = 2026-11-01 UTC. **배포 전** `deploy_admin.bat`(규칙 hall_of_fame · 함수 seasonTick) |
| 11 | 중국어 · 일본어 | ✅ 번역 · ⏳ 검수 | 전체 번역(원어민 검수 전). 검수 뒤 `LanguageManager.showDraftLanguages` 를 켠다 |
| 12 | 아트 2차 | 보류 | 요청으로 보류 |
| 13 | 명패 → 뱃지 46종 | ✅ | docs/BADGES.md — 옛 명패는 로그인 시 랭킹 뱃지로 옮김 |

## 시즌 정책 (2026-10-26 백오피스 설정으로)

- **랭킹은 시즌 하나뿐이다.** 주간·월간 랭킹은 2026-10-26 뺐다(사람이 적어 기간을 쪼개면 목록이 비었다).
- 시즌 단위는 **백오피스 › 시즌**에서 고른다(`config/season`, `lib/season.dart`): **연간**(1월 1일~12월 31일) · **분기** · **월간** · **N일마다**. 시즌 1 시작일 · 경계 시간대(UTC+h, 한국 9)도 거기서. 그 전 기록은 전부 프리시즌(S0).
- 기본값(문서가 없을 때): 연간, 시즌 1 = 2026-11-01 UTC.
- **시즌이 끝나면** 서버 함수(`functions/season.js`, 매시간)가 존별 TOP 3 를 `hall_of_fame/{시즌 id}` 에 남긴다 — 앱 랭킹 머리의 시즌 칩을 누르면 **명예의 전당**. 랭킹은 비어서 새로 시작한다.
- **마감 전 자동 푸시**: 마감 30·10·3일 전(백오피스에서 바꿀 수 있다) 그 시간대 18시에 "명예의 전당에 오를 기회가 얼마 안 남았어요" 문구가 알림을 켠 모든 기기에 간다(4개 언어, `logic.js SEASON_TEXTS`). 한 시즌·한 날짜에 한 번(`push_state/season_{id}_{n}`).
- 난이도를 크게 바꿀 때는 **시즌이 끝나는 때에 맞춘다**. 시즌 중간에 모드·시작일을 바꾸면 랭킹 범위가 바로 바뀌므로 하지 않는다.
- 뱃지는 시즌이 바뀌어도 유지한다. 기록 문서의 `season` 은 시즌 id(문자열 — '2026' · '2026Q4'), 옛 기록의 정수(0·1)는 그대로.
