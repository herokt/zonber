# CLAUDE.md

이 파일은 Claude Code(claude.ai/code)가 이 저장소에서 작업할 때 참고하는 가이드입니다.

## 프로젝트 개요

ZONBER는 Flutter와 Flame 엔진으로 만든 하이퍼캐주얼 탄막 서바이벌 모바일 게임입니다. 플레이어는 좁은 존 안에서 끊임없이 날아오는 탄막을 피하며 최대한 오래 생존해야 합니다.

> 📐 **구조 전체를 파악해야 하는 작업이면 [ARCHITECTURE.md](ARCHITECTURE.md)를 먼저 읽으세요.**
> 아키텍처·데이터 모델·게임 코어 상세·알려진 이슈의 단일 진실 공급원입니다.
> 이 문서(CLAUDE.md)는 자주 쓰는 명령어와 작업 체크리스트만 다룹니다.

- **패키지명:** com.zonber.game
- **플랫폼:** Android, iOS (Firebase/AdMob은 모바일 전용)
- **백엔드:** Firebase Firestore (프로젝트: `stayzone-88364`)
- **게임 엔진:** Flame 1.34.0
- **다국어:** 영어 + 한국어 (`translations.dart`)

## 주요 명령어

```bash
# 앱 실행
flutter run

# 특정 기기에서 실행
flutter run -d <device_id>

# Android APK 빌드
flutter build apk

# iOS 빌드
flutter build ios

# 정적 분석
flutter analyze

# 테스트 실행
flutter test

# 의존성 설치
flutter pub get

# 백오피스 관리자 앱 실행
flutter run -t lib/backoffice/main_backoffice.dart

# 점검 스크립트 (Node.js, scripts/ 폴더 — npm 의존성 없음)
node scripts/check_translations.mjs   # 번역 키 EN/KO 일치
node scripts/test_rules.mjs           # firestore.rules 시험 (gcloud auth login 필요, 읽기 전용)
```

## 아키텍처

### 게임 코드 위치 (2026-09-22 main.dart 를 part 파일로 나눔)
- `lib/main.dart` — 앱 초기화 · `ZonberApp` 페이지 라우팅 · 판 종료 처리(`_handleGameOver`)
- `lib/game/` (`part of '../main.dart'`) — `game_screen.dart`(HUD) · `zonber_game.dart`(ZonberGame·맵) · `player.dart` · `projectiles.dart`(Bullet·스포너·피구 팀) · `keeper.dart` · `dodgeball.dart`
- 밸런스 수치 `lib/balance.dart` · 시즌 `lib/season.dart` · 일일 미션 `lib/daily_rewards.dart` · 판 기록 `lib/run_history.dart`(서버) · `lib/playtest_log.dart`(기기)
- 테스트 `flutter test`(test/logic_test.dart) · 규칙 시험 `node scripts/test_rules.mjs`
- 효과음 `assets/audio/*.wav` — `python scripts/make_sfx.py` 로 합성, 이름·연결은 `lib/audio_manager.dart`(Sfx) · 진동 `lib/haptics.dart`

### 진입점 & 네비게이션
`main.dart`:
- 앱 초기화 (Firebase, AdMob, GameSettings, AudioManager)
- `ZonberApp` 위젯에서 `_currentPage` 상태로 페이지 라우팅
- 페이지: Menu(=HomePage), Ranking, MyProfile(=ProfilePage) ← 하단 탭 3개 / Game, Result, Badges, Profile(최초 설정), Login, Shop, Statistics (캐릭터 고르기 = 상점 캐릭터 탭, CharacterSelect 페이지는 2026-09-22 제거). 맵 에디터·커스텀 맵·Hall of Fame 은 2026-09-22 코드째 제거
- 월드 상태: `_currentWorldId` · `_bestTimes` · `_rankCache`. 랭킹 mapId는 `_currentWorld.rankingMapId`

### 게임 코어 (Flame 엔진)
`main.dart`의 `ZonberGame` 클래스:
- 고정 맵 크기: 480x768 (32px 타일 기준 15x24 그리드)
- World height: 800 (맵 하단 UI 영역 포함)
- 컴포넌트: `Player`(근접 회피 카운트, `keeperMode`면 공에 닿으면 세이브·`concedeGoal()`로 실점), `Bullet`(`ProjectileDef` 기반: 크기·색·straight/curve/bounce, 큰 공은 바닥 그림자, keeper면 골대 진입 시 실점), `BulletSpawner`(ring, keeper는 골대 기준 스폰·조준 / thrower → `_DodgeballThrower`: 피구 턴제 투구·단계별 패턴, `Bullet.splitAfter`로 분열 / shooter → `_KeeperShooter` + `KeeperGoal`: 페널티킥형 골문·슈터 1→5명·바나나킥). 진입 예고 표시 없음, `GoalZone`(keeper 골대), `MapArea`, `GridBackground`(스테이지 line 색 테두리 + `worlds/{id}_bg.png` 배경 슬롯)
- 목표선: `_loadTargets()`가 올해 TOP 100 시간을 읽어 `game.setTargets()` → HUD가 다음 TOP N 까지 진행바 표시 (10분 캐시)
- 터치 조작: 직접 드래그 (1:1 손가락 이동, 조이스틱 없음)
- 충돌 시스템: Flame의 `HasCollisionDetection` + 탄환 터널링 방지 수동 처리

### 주요 파일
| 파일 | 역할 |
|------|------|
| `world_config.dart` | **스테이지 3종, 항상 열림** (`WorldConfig`/`ProjectileDef`/`SpawnStrategy`/`WorldMode`) — 1 Cyber · 2 Dodgeball(sideline 스포너) · 3 Keeper(mode keeper: 골대 반지름·lives 5). 리더보드는 전부 신규 mapId. 기획 [docs/STAGES.md](docs/STAGES.md) |
| `game_config.dart` | 레이아웃 기본값(`zone_1_classic`: 탄속·스폰 간격) — 월드의 `layoutId`가 참조. 모든 월드가 `zone_1_classic`(장애물 없음) |
| `progress_store.dart` | 월드별 최고 기록·순위 캐시. SharedPreferences + Firestore `users/{uid}.bestTimes` (옛 `plates` 는 로그인 때 뱃지로 옮김) |
| `pages/home_page.dart` | 홈 — 월드 캐러셀·캐릭터·START |
| `pages/ranking_page.dart` | 랭킹 탭 — 월드 탭 × 기간 × 세계/국가, 포디움, 내 행 고정 |
| `pages/result_page.dart` | 결과 — 기록 제출, 순위 카드(count 집계), 새로 얻은 뱃지 |
| `pages/profile_page.dart` | 프로필 탭 — 대표 뱃지·월드별 기록·캐릭터·설정·계정 (구 `MyProfilePage` 대체) |
| `ranking_system.dart` | Firestore 리더보드: 기록 저장/조회, 국가별 랭킹, 3개 기간(주/월/올해) + count 집계 순위 |
| `achievement_manager.dart` | 9개 업적 (생존 티어, 국가/글로벌 랭킹); SharedPreferences + Firestore 이중 저장 |
| `statistics_page.dart` | 유저 통계 + 획득 타이틀 (일간/주간/월간 랭커, 전설적 생존자) |
| `translations.dart` | 200개+ 이중 언어 문자열 (EN/KO); `{placeholder}` 보간 지원 |
| `language_manager.dart` | 언어 전환; SharedPreferences에서 읽음 |
| `design_system.dart` | 디자인 시스템 v2 — 다크 무채색 + 월드 강조색 1개, Sora(Display)/Manrope(Body). `Neon*` 이름 유지 + `AppChip`/`AppSegmented`/`CountryChip`/`NamePlate`/`RankRow`/`AppBottomNav`. gold는 1위·뱃지 강조 전용 |
| `avatar.dart` | **아바타 단일 출처** — `Avatar`(캐릭터·스킨·잔상·오라·존별 장비 한 벌) + `AvatarView`(동그란 아바타) + `AvatarStage`(큰 전신, 잔상·오라까지). 아바타를 그리는 곳은 전부 여기를 쓴다(홈·랭킹·가방·프로필·게임 `Player`) |
| `player_profile.dart` | **프로필 단일 출처** — `PlayerProfile`(닉네임·국가·아바타·가입일·최근 접속·뱃지·존별 기록·누적) + `PlayerProfileService.fetch(uid)`. 내 것과 남의 것이 같은 클래스 |
| `pages/player_profile_view.dart` | 프로필 표시 부품 — `ProfileIdentityCard`/`StageRecordRow`/`ProfileMetaLine`/`ProfileBadgeStrip` + `showPlayerCard(uid)`(랭킹에서 이름을 누르면 뜨는 남의 프로필 창) |
| `audio_manager.dart` | BGM/SFX 싱글톤 (flame_audio) |
| `ad_manager.dart` / `ad_helper.dart` | AdMob 연동 (배너, 전면, 리워드); 광고 ID는 `kReleaseMode`로 자동 전환 |
| `iap_service.dart` | 인앱 결제 서비스 (in_app_purchase 패키지) — 광고 제거 IAP 예정, 아직 초기화하지 않음 |
| `shop_page.dart` | 상점/IAP UI (캐릭터 스킨 등) |
| `game_settings.dart` | SharedPreferences 기반 설정 저장 |
| `user_profile.dart` | 닉네임, 국가 국기, 프로필 관리 |
| `character_data.dart` | 캐릭터 정의 8종 + `CharacterStats`(능력치는 전부 동일 — 캐릭터는 외형·표정만 다르다) |
| `game_guide_sheet.dart` | 게임 방법 가이드 바텀시트 (아이템 탭은 파워업 제거와 함께 삭제) |
| `services/analytics_service.dart` | Firebase Analytics 래퍼. **이벤트 이름·파라미터는 이 파일에만** 둔다 (모바일 외 no-op) |
| `login_page.dart` | Firebase 인증 UI (Google / Apple(iOS) · 게스트로 계속 = 로그인 없이 메뉴로). **첫 실행에는 뜨지 않는다** — 게스트가 랭킹 등록을 시도하거나 프로필에서 로그인을 누를 때만 진입 |
| `services/auth_service.dart` | Firebase Auth 래퍼 (Google, Apple) + `AuthService.isGuest`(게스트 판정 단일 출처) |

### 백오피스 (별도 관리자 앱)
`lib/backoffice/`에 위치. 진입점: `lib/backoffice/main_backoffice.dart`.
Firebase Hosting `/secret_admin/` 경로로 배포됨 (`firebase.json` 참고).
- `dashboard_page.dart` — 실시간 유저/플레이 지표 및 스테이지 성과
- `user_list_page.dart` — 유저 관리 UI
- `user_detail_page.dart` · `runs_page.dart` · `ranking_page.dart` · `economy_page.dart` — 유저 상세 · 판 기록 · 랭킹 · 경제
- 이름표(캐릭터·장비·뱃지 한글명)는 `bo_catalog.dart`

### 디자인 시스템
모든 UI는 `design_system.dart`의 네온 테마 사용:
- 색상: `AppColors.primary` (시안), `AppColors.secondary` (빨강), `AppColors.background` (짙은 검정)
- 컴포넌트: `NeonScaffold`, `NeonAppBar`, `NeonCard`, `NeonButton`, `NeonDialog`

### 인증
**게스트 = 로그인하지 않은 상태 · 게임 맛보기만(2026-09-22):** 앱 첫 실행은 `_ZonberAppState._enterAsGuest()`가 **로그인 없이**(익명 로그인도 하지 않는다) 바로 메뉴에 들어간다. 로그아웃도 게스트로 복귀한다. 게스트는 **기기·서버 어디에도 아무것도 저장하지 않는다** — 기록·코인·미션·뱃지·통계·프로필·플레이 수 모두. 화면(코인·상점·뱃지·미션·내 최고·통계)은 그대로 보이되 값은 초기값(0·—)이고, 구매·보상 받기는 로그인 안내(`guest_login_to_save`). 저장 차단은 각 store(`CoinStore`·`ProgressStore`·`DailyRewards`·`AchievementManager`·`BadgeStatsStore`·`UserProfileManager`·`PlaytestLog`)가 `AuthService.isGuest`로 직접 막고, `_handleGameOver`도 게스트는 결과만 보여 준다. 게스트 진입 때 기기의 유저 데이터를 지우고(`_clearLocalData`), 예전 버전의 익명 세션은 시작 시 로그아웃시킨다. 로그인 세션은 Firebase 가 기기에 저장하므로 다음 실행에 자동 로그인된다. 규칙도 회원(`isMember`)만 쓰기 허용. 예전 게스트 데이터 정리 = `scripts/delete_guest_data.mjs`.

Firebase Auth 로그인 방식 (Google, Apple(iOS 전용 노출)):
- `services/auth_service.dart`에서 Firebase Auth 호출 래핑
- `login_page.dart`가 UI 진입점
- Firebase/AdMob은 모바일에서만 초기화:
```dart
if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
  await Firebase.initializeApp();
  await AdManager().initialize();
}
```

### 다국어 처리
모든 사용자 노출 문자열은 `translations.dart`를 통해 처리:
- `LanguageManager`로 현재 로케일 get/set
- 구조: `Map<String, Map<String, String>>` — 외부 키는 로케일(`en`/`ko`), 내부 키는 문자열 ID
- 동적 값은 `{placeholder}` 문법으로 호출부에서 주입

## 유지보수 명령어

```bash
# EN/KO 번역 키 누락 검사
node scripts/check_translations.mjs

# firestore.rules 를 배포 없이 시험 (gcloud auth login, 읽기 전용)
node scripts/test_rules.mjs

# 효과음 합성 / 존 배경 생성
python scripts/make_sfx.py
python scripts/make_stage_bg.py
```

> 옛 익명 SDK 관리 스크립트(seed/check/cleanup·마이그레이션)는 2026-09-22 삭제했다. DB 를 고칠 일이 있으면 `test_rules.mjs` 처럼 gcloud 토큰 + REST 로 새로 만든다.

**자동 훅** (`.claude/settings.local.json`에 설정됨 — 개인 로컬 파일, git 추적 안 함):
- `translations.dart` 수정 후 → `check_translations.mjs` 자동 실행
- `game_config.dart` 수정 후 → 스테이지 개발 체크리스트 표시
- `character_data.dart` 수정 후 → 캐릭터 개발 체크리스트 표시

## 기능 개발 체크리스트

### 새 월드 추가·활성화 시
1. `world_config.dart` — `WorldData.worlds`에 `WorldConfig` 추가(난이도 순). `rankingMapId`는 새 Firestore `maps/{id}`
2. `translations.dart` — `world_{id}`, `world_{id}_tagline`, `proj_*` 키 EN + KO
3. 스포너 전략은 `ring`(플레이어/골대 중심 원주)과 `sideline`(맵 4변 바깥) 두 가지. 새 전략은 `BulletSpawner._spawnBullet()`에 분기
5. 배경·히어로 이미지는 `assets/images/worlds/{id}_bg.png`, `{id}_hero.png` 슬롯에 넣으면 자동 반영(없으면 코드 드로잉)
4. 홈 캐러셀·랭킹 탭·프로필 그리드는 `WorldData.worlds`를 그대로 순회하므로 UI 수정 불필요

### 장애물 레이아웃
2026-09-22 장애물 레이아웃(`zone_2_obstacles` 기둥·`zone_5_maze` 미로)과 `maze_generator.dart` 를 제거했다. 모든 월드가 `zone_1_classic`(장애물 없음)을 쓴다. 장애물 시스템(`Obstacle` 컴포넌트, 탄환 벽 반사 `WallBehavior`/`onWall`/`maxBounces`, 플레이어 밀어내기)도 함께 제거했다.

### 새 캐릭터 추가 시
1. `character_data.dart` — `CharacterData.availableCharacters`에 `Character` 추가 (`CharacterStats`의 체력/속도/기력 3축 밸런싱)
2. 그림 — 캐릭터는 코드 드로잉(`zonber_painter.dart`)이라 색만 정하면 된다 (2026-09-22 1차 AI 아트(`assets/images/game/`·`GameArt`)는 제거했다 — 캐릭터·장비·공·이펙트는 전부 코드 드로잉)
3. `shop_page.dart` 캐릭터 탭에 표시되는지 확인 (캐릭터 고르기 = 상점)
4. `backoffice/bo_catalog.dart` — `kCharNames`에 한글 이름 추가
6. `translations.dart` — 이름/설명 키를 EN + KO 양쪽에 추가
7. `shop_page.dart` + `iap_service.dart` — 유료 캐릭터인 경우 IAP 항목 추가 (현재 IAP 비활성)

### 파워업(아이템) 시스템
2026-09에 **제거됨**. `powerup_system.dart`·`PowerUpManager`·`PowerUpComponent`·HUD 오버레이·가이드 아이템 탭·`powerup_*` 문자열이 모두 삭제됐다. 월드별 기믹은 [docs/GAME_TYPES_DESIGN.md](docs/GAME_TYPES_DESIGN.md) 설계를 따른다. 다시 넣지 말 것.

### 새 업적 추가 시
1. `achievement_manager.dart` — `AchievementDef` 상수 추가 + `allAchievements` 리스트에 등록
2. `translations.dart` — `key`, `descKey` 번역을 EN + KO 양쪽에 추가
3. 체크 함수 — `bool Function(double survivalTime, int rank)` 형태로 구현

### 릴리즈 전 체크리스트
1. `node scripts/check_translations.mjs` · `flutter test` 통과 확인
2. `pubspec.yaml` — 버전 번호 올리기 (`version: x.y.z+build`)
3. `flutter analyze` — 신규 warning 없는지 확인
4. `flutter build apk --release` / `flutter build appbundle --release`

> 광고 ID는 `AdHelper.isReleaseMode = kReleaseMode`로 자동 판별됩니다. 릴리즈 빌드는 실제 ID, 디버그는 Google 테스트 ID가 쓰이므로 **수동 토글이 필요 없습니다.**

## 맵 / 스테이지 시스템

스테이지는 `world_config.dart`의 월드 3종(cyber · dodgeball · keeper)이고, 리더보드 mapId 는 월드의 `rankingMapId`다.
`game_config.dart`의 `zone_1_classic`은 탄속·스폰 간격 기본값만 준다(월드 값이 우선).

> 맵 에디터(UGC)·커스텀 맵(`editor_game.dart`·`map_service.dart`)은 2026-09-22 코드째 제거했다.
> Firestore `custom_maps` 컬렉션 규칙은 `firestore.rules`에 그대로 남아 있다.

## 싱글톤 서비스

앱 시작 시 초기화:
- `GameSettings()` — 사운드/진동 설정 (SharedPreferences)
- `AudioManager()` — BGM/SFX 재생 (flame_audio)
- `AdManager()` — AdMob 광고 (모바일 전용)

## Firestore 컬렉션

```
users/
  └── {userId}              # nickname, flag, country, characterId, stats

maps/
  └── {mapId}/
      └── records/          # 리더보드 항목
          └── {recordId}    # userId, nickname, flag, survivalTime, characterId, timestamp

custom_maps/                # (옛 UGC — 앱에서 더는 쓰지 않음, 규칙만 남음)
```

랭킹 기록은 3개 기간 지원: `weekly`, `monthly`, `allTime` (현재 연도). 일일은 2026-09-18 제거.
국가 랭킹은 `flag` 필드로 필터링하며, 쿼리당 상위 30개를 가져오고 `users` 컬렉션에서 30개씩 배치로 유저 데이터를 보강함.

## 업적

`achievement_manager.dart`에서 3개 카테고리, 9개 업적 관리:
- **생존** (5단계): 60초 → 120초 → 180초 → 240초 → 300초 생존
- **국가** (1단계): 국가 랭킹 1위 달성
- **글로벌** (3단계): 상위 30위, 상위 10위, 글로벌 1위

업적은 SharedPreferences(로컬)와 Firestore(원격) 양쪽에 저장되며 로그인 시 병합됨.

## SharedPreferences 키

| 키 | 역할 |
|----|------|
| `sound_enabled` | BGM/SFX 토글 |
| `vibration_enabled` | 햅틱 피드백 토글 |
| `drag_sensitivity` | 드래그 감도 (0.6 ~ 1.8, 기본 1.0) |
| `user_achievements` | 획득 업적 키 배열 (캐릭터 해금 판정에도 사용) |
| `user_nickname` | 플레이어 표시 이름 (최대 8자) |
| `user_flag_code` | 국가 국기 이모지 |
| `user_country_name` | 국가명 문자열 |
| `user_character_id` | 선택된 캐릭터 스킨 |
| `language` | 현재 로케일 (`en` / `ko`) |

## 캐릭터

스프라이트 기반 6종. **히트박스(22×22)와 시각 크기(42×42)는 전 캐릭터 동일**하며, `CharacterStats` 4축만 다름.

| ID | 체력 `maxEnergy` | 속도 `speedMultiplier` | 기력 `energyCooldown` | 회피 `iframeDuration` | 해금 |
|---|:-:|:-:|:-:|:-:|---|
| `neon_green` | 3 | 1.00 | 25s | 1.5s | 기본 |
| `electric_blue` | 2 | 1.40 | 50s | 1.6s | 60초 생존 |
| `plasma_purple` | 2 | 0.85 | 10s | 1.3s | 120초 생존 |
| `cyber_red` | 4 | 1.20 | 55s | 1.2s | 180초 생존 |
| `solar_gold` | 5 | 0.70 | 35s | 1.0s | 240초 생존 |
| `void_dark` (Wraith) | 1 | 1.25 | 18s | 2.5s | 300초 생존 |

- `energyCooldown` = 에너지 1칸 회복에 걸리는 초 (낮을수록 좋음)
- `iframeDuration` = 피격 후 무적 시간. **무적 중 닿는 탄환은 제거**되므로 방어이자 돌파 수단
- 밸런싱 기준: maxEnergy × iframeDuration(무적 시간 총합)이 **2.5 ~ 5.0** 범위
- 해금은 `unlockKey`로 판정. 이미 선택 중인 캐릭터는 조건과 무관하게 유지됨
- 렌더링은 코드 드로잉(`zonber_painter.dart`). 2026-09-22 1차 AI 아트(`assets/images/game/`·`GameArt`)는 제거했다 — 캐릭터·장비·공·이펙트는 전부 코드 드로잉

## 뱃지

2026-09-22 명패·칭호를 뱃지로 바꿨다 — 정의·조건 `lib/badges.dart`, 저장 `lib/achievement_manager.dart`(users/{uid}.achievements). 기획 [docs/BADGES.md](docs/BADGES.md).

## Analytics

`AnalyticsService()`(모바일 전용, 그 외 no-op). 퍼널: `session_ready`(유저 속성 `is_guest`/`login_provider`) → `game_start` → `game_over`(+표준 `post_score`) → `revive` | `score_submit` | `guest_ranking_blocked`. 화면은 `_navigateTo()`에서 `logScreen(page)`로 자동 기록. 새 이벤트는 반드시 `analytics_service.dart`에 메서드로 추가하고 호출부에서 문자열을 만들지 않는다.

## 오디오 에셋

`assets/audio/` 위치. **현재 파일은 전부 합성 플레이스홀더**(Node로 생성, 라이선스 무관)이며 정식 에셋으로 교체 대상:
- `bgm.mp3` — 배경 음악 (루프, 30초 128BPM)
- `hit.wav` — 피격(에너지 소모), `gameover.wav` — 게임 오버 (전체 목록은 `Sfx`)
- 설정 › 사운드 토글(`ProfilePage`)이 `GameSettings.setSound` + BGM 정지를 처리한다

## AdMob 설정

`ad_helper.dart`:
- `isReleaseMode = kReleaseMode` — 빌드 모드로 자동 판별, **수동 설정 불필요**
- 릴리즈 빌드 → 실제 광고 단위 ID / 디버그 빌드 → Google 공식 테스트 ID

`ad_manager.dart` 노출 정책:
- **배너** — 전역 (`AppScaffold` 하단), `ads_removed` 구매 시 숨김
- **전면** — 게임 오버 5회마다
- **리워드** — 결과 화면 부활, 세션당 1회, 게스트 포함 (사전 고지 다이얼로그 필수 — AdMob 정책)

## Android 설정 참고

`android/` 위치:
- 패키지 경로: `android/app/src/main/kotlin/com/zonber/game/`
- `google-services.json`은 패키지명 `com.zonber.game`과 일치해야 함
- Firebase 호환성을 위해 MultiDex 활성화
- 드라이브 간 빌드 오류 발생 시 `gradle.properties`의 `kotlin.incremental=false` 확인
