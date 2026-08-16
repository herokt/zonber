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
- **파워업:** 맵에 랜덤 스폰 — 속도 증가 / 에너지 회복 / 탄막 소멸 / 시간 감속

## 콘텐츠

- **스테이지 3종** — Zone 1 (빈 아레나) / Zone 2 (4기둥) / Zone 3 Abyss (절차적 미로)
- **캐릭터 6종** — 체력·속도·기력 3축으로 밸런싱
- **업적 9종** — 생존 5단계 + 국가 랭킹 + 글로벌 랭킹 3단계
- **랭킹** — 스테이지별 리더보드, 일간/주간/월간/연간, 글로벌 + 국가별
- **맵 에디터 (UGC)** — 15×24 그리드. 업로드 전 제작자가 30초 생존 검증 필수

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
node scripts/weekly_check.mjs        # 종합 점검 (번역·스테이지·에셋·버전)
node scripts/check_translations.mjs  # EN/KO 번역 키 누락만 검사
node scripts/check_rankings.mjs      # Firestore 랭킹 정합성
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
├── main.dart              진입점 · 라우팅 · Flame 게임 코어 · HUD
├── game_config.dart       스테이지 정의 (단일 진실 공급원)
├── character_data.dart    캐릭터 6종 + 스탯
├── powerup_system.dart    파워업 타입/스펙
├── achievement_manager.dart
├── ranking_system.dart    Firestore 리더보드
├── user_profile.dart      프로필 · 통계
├── design_system.dart     네온 테마 컴포넌트
├── translations.dart      EN/KO 234키
├── services/              auth · invite
└── backoffice/            관리자 앱 (별도 진입점)

scripts/                   Node.js 운영 스크립트
assets/images/characters/  캐릭터 스프라이트
```

## 개발 시 주의

- 사용자 노출 문자열은 **반드시 `translations.dart`의 EN + KO 양쪽**에 추가
- 스테이지 추가·삭제는 `game_config.dart`가 기준. 관련 6개 지점 갱신 필요 (ARCHITECTURE.md §13)
- 광고 모드는 `kReleaseMode`로 자동 판별되므로 릴리즈 전 수동 토글 불필요
- 빌드가 `different roots` 오류로 실패하면 `android/gradle.properties`의 `kotlin.incremental=false` 확인
