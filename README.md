# ZONBER — Survive the Zone

좁은 존 안에서 사방에서 날아오는 탄막을 피해 최대한 오래 버티는 하이퍼캐주얼 탄막 생존 게임.

| | |
|---|---|
| **장르** | 하이퍼캐주얼 / 탄막 생존 (Bullet Hell Survival) |
| **스택** | Flutter (Dart) + Flame 1.34 |
| **백엔드** | Firebase — Auth · Firestore · Hosting (`stayzone-88364`) |
| **플랫폼** | Android / iOS (웹은 백오피스 전용) |
| **패키지명** | `com.zonber.game` |
| **버전** | 1.3.0+130 |

---

## 핵심 규칙

- **목표:** 생존 시간(초, 소수점 3자리)이 곧 점수. 승리 조건 없음
- **조작:** 화면 어디든 드래그 (1:1 손가락 이동)
- **에너지:** 캐릭터별 1~5칸. 피격 시 1 소모 + 무적 1.5초. 0에서 맞으면 게임 오버
- **난이도:** 30초마다 1레벨씩 탄막 간격 −10%, 속도 +15, 동시 탄환 상한 +10
- **아이템 없음:** 파워업 시스템은 2026-09 제거. 실력 표현은 이동·무적 프레임뿐 (월드 기믹은 [docs/GAME_TYPES_DESIGN.md](docs/GAME_TYPES_DESIGN.md))

## 콘텐츠

- **스테이지 3종, 항상 열림** — 1 Cyber(현행 네온 탄막) / 2 Dodgeball(상대 코트에서 한 턴에 한 번 조준 투구, 분열·세트 패턴으로 극악까지) / 3 Keeper(페널티킥형 — 위쪽 슈터 1→5명의 슛을 골라인 앞에서 막기, 5골이면 게임 오버). 진입 예고 표시 없음. 상세 [docs/STAGES.md](docs/STAGES.md), 리소스 [docs/RESOURCES.md](docs/RESOURCES.md)(현재 더미)
- **캐릭터 6종** — 체력·속도·기력 3축으로 밸런싱
- **뱃지** — 생존·스테이지·기술·경력·랭킹·수집·출석·특별 카테고리, 4등급. 2026-09-22 명패·칭호를 대체 ([docs/BADGES.md](docs/BADGES.md))
- **랭킹** — 월드별 완전 분리 **신규** 리더보드(`maps/dodgeball|keeper|cyber|zombie`, 기존 zone_1_classic 미계승), 주간/월간/연간(일일 없음), 글로벌 + 국가별. **계정(Google/Apple) 전용** — 게스트 기록은 등록되지 않는다
- **목표선·순위 카드** — 게임 HUD엔 TOP 100/30/10/1 목표선, 결과 화면엔 순위 카드(게스트는 '잃어버린 순위')
- **게스트 기본** — 첫 실행은 로그인 없이 바로 게스트로 플레이. 로그인은 랭킹 등록 시점에만 요구

---

## 시작하기

```bash
flutter pub get
flutter run
```

```bash
# 백오피스 관리자 앱
flutter run -t lib/backoffice/main_backoffice.dart

# 정적 분석 / 테스트
flutter analyze
flutter test

# 릴리즈 빌드
flutter build appbundle --release
flutter build ios --release
```

### 운영 점검

```bash
node scripts/check_translations.mjs  # EN/KO 번역 키 누락 검사
node scripts/test_rules.mjs          # firestore.rules 시험 (gcloud auth login, 읽기 전용)
flutter test                         # 로직 테스트 (test/logic_test.dart)
```

---

## 문서

| 문서 | 용도 |
|---|---|
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | **시스템 설계문서 (SSOT)** — 아키텍처, 게임 코어, 데이터 모델, 알려진 이슈 |
| [CLAUDE.md](CLAUDE.md) | Claude Code 에이전트용 작업 가이드 |

구조를 파악하거나 기능을 추가하기 전에 **ARCHITECTURE.md를 먼저 읽으세요.**

---

## 디렉터리

```
lib/
├── main.dart              진입점 · 라우팅 · Flame 게임 코어 · 게임 HUD
├── world_config.dart      월드 5종 정의 (투사체·스포너·테마·해금) — 월드 목록의 단일 진실 공급원
├── game_config.dart       레이아웃 기본값 zone_1_classic (탄속·스폰 간격, 월드가 참조)
├── progress_store.dart    월드별 최고 기록 · 순위 캐시 (로컬+Firestore)
├── pages/                 home · ranking · result · badges · profile · daily_sheet
├── character_data.dart    캐릭터 6종 + 스탯
├── achievement_manager.dart
├── ranking_system.dart    Firestore 리더보드
├── user_profile.dart      프로필 · 통계
├── design_system.dart     디자인 시스템 v2 (다크 + 월드 강조색, Sora/Manrope, 랭크행·하단탭)
├── translations.dart      EN/KO 이중 언어 문자열
├── services/              auth · analytics (Firebase Analytics 이벤트 단일 출처)
└── backoffice/            관리자 앱 (별도 진입점)

scripts/                   점검·생성 스크립트 (check_translations · test_rules · make_sfx · make_stage_bg)
assets/images/worlds/      존 배경·홈 히어로 아트
assets/audio/              BGM·SFX — 현재 **합성 플레이스홀더**(`scripts/make_sfx.py`로 생성, 라이선스 무관). 정식 에셋으로 교체 예정
```

## 개발 시 주의

- 사용자 노출 문자열은 **반드시 `translations.dart`의 EN + KO 양쪽**에 추가
- 스테이지 추가·삭제는 `game_config.dart`가 기준. 관련 6개 지점 갱신 필요 (ARCHITECTURE.md §13)
- 광고 모드는 `kReleaseMode`로 자동 판별되므로 릴리즈 전 수동 토글 불필요
- 빌드가 `different roots` 오류로 실패하면 `android/gradle.properties`의 `kotlin.incremental=false` 확인
