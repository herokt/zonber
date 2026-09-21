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

# 데이터 관리 스크립트 (Node.js, scripts/ 폴더)
node scripts/seed_rankings.mjs
node scripts/check_rankings.mjs
node scripts/cleanup_stages.mjs
```

## 아키텍처

### 진입점 & 네비게이션
`main.dart`:
- 앱 초기화 (Firebase, AdMob, GameSettings, AudioManager)
- `ZonberApp` 위젯에서 `_currentPage` 상태로 페이지 라우팅
- 페이지: Menu(=HomePage), Ranking, MyProfile(=ProfilePage) ← 하단 탭 3개 / Game, Result, HallOfFame, Editor, EditorVerify, Profile(최초 설정), CharacterSelect, Login, Shop, Statistics
- 월드 상태: `_currentWorldId` · `_bestTimes` · `_rankCache`. 랭킹 mapId는 `_currentWorld.rankingMapId`

### 게임 코어 (Flame 엔진)
`main.dart`의 `ZonberGame` 클래스:
- 고정 맵 크기: 480x768 (32px 타일 기준 15x24 그리드)
- World height: 800 (맵 하단 UI 영역 포함)
- 컴포넌트: `Player`(근접 회피 카운트, `keeperMode`면 공에 닿으면 세이브·`concedeGoal()`로 실점), `Bullet`(`ProjectileDef` 기반: 크기·색·straight/curve/bounce·벽 반응, 큰 공은 바닥 그림자, keeper면 골대 진입 시 실점), `BulletSpawner`(ring, keeper는 골대 기준 스폰·조준 / thrower → `_DodgeballThrower`: 피구 턴제 투구·단계별 패턴, `Bullet.splitAfter`로 분열 / shooter → `_KeeperShooter` + `KeeperGoal`: 페널티킥형 골문·슈터 1→5명·바나나킥). 진입 예고 표시 없음, `GoalZone`(keeper 골대), `Obstacle`, `MapArea`, `GridBackground`(스테이지 line 색 테두리 + `worlds/{id}_bg.png` 배경 슬롯)
- 목표선: `_loadTargets()`가 올해 TOP 100 시간을 읽어 `game.setTargets()` → HUD가 다음 TOP N 까지 진행바 표시 (10분 캐시)
- 터치 조작: 직접 드래그 (1:1 손가락 이동, 조이스틱 없음)
- 충돌 시스템: Flame의 `HasCollisionDetection` + 탄환 터널링 방지 수동 처리

### 주요 파일
| 파일 | 역할 |
|------|------|
| `world_config.dart` | **스테이지 3종, 항상 열림** (`WorldConfig`/`ProjectileDef`/`SpawnStrategy`/`WorldMode`) — 1 Cyber · 2 Dodgeball(sideline 스포너) · 3 Keeper(mode keeper: 골대 반지름·lives 5). 리더보드는 전부 신규 mapId. 기획 [docs/STAGES.md](docs/STAGES.md) |
| `game_config.dart` | 장애물 레이아웃 정의 (`zone_1_classic`/`zone_2_obstacles`/`zone_5_maze`) — 월드의 `layoutId`가 참조 |
| `progress_store.dart` | 월드별 최고 기록·순위 캐시·명패(`PlateData`). SharedPreferences + Firestore `users/{uid}.bestTimes/plates` |
| `pages/home_page.dart` | 홈 — 월드 캐러셀·캐릭터·START |
| `pages/ranking_page.dart` | 랭킹 탭 — 월드 탭 × 기간 × 세계/국가, 포디움, 내 행 고정 |
| `pages/result_page.dart` | 결과 — 기록 제출, 순위 카드(count 집계), TOP 100/국가 TOP 10 진입 시 Hall of Fame |
| `pages/hall_of_fame_page.dart` | 명패 의식 — 순위 카운트다운·각인·공유(share_plus) |
| `pages/profile_page.dart` | 프로필 탭 — 명패·월드별 기록·캐릭터·설정·계정 (구 `MyProfilePage` 대체) |
| `ranking_system.dart` | Firestore 리더보드: 기록 저장/조회, 국가별 랭킹, 3개 기간(주/월/올해) + count 집계 순위 |
| `achievement_manager.dart` | 9개 업적 (생존 티어, 국가/글로벌 랭킹); SharedPreferences + Firestore 이중 저장 |
| `statistics_page.dart` | 유저 통계 + 획득 타이틀 (일간/주간/월간 랭커, 전설적 생존자) |
| `translations.dart` | 200개+ 이중 언어 문자열 (EN/KO); `{placeholder}` 보간 지원 |
| `language_manager.dart` | 언어 전환; SharedPreferences에서 읽음 |
| `editor_game.dart` | 그리드 기반 맵 에디터 (15x24), 업로드 전 30초 생존 검증 필요 |
| `map_service.dart` | 커스텀 맵 Firestore CRUD |
| `maze_generator.dart` | 미로형 스테이지용 절차적 미로 생성 |
| `design_system.dart` | 디자인 시스템 v2 — 다크 무채색 + 월드 강조색 1개, Sora(Display)/Manrope(Body). `Neon*` 이름 유지 + `AppChip`/`AppSegmented`/`CountryChip`/`CharacterAvatar`/`NamePlate`/`RankRow`/`AppBottomNav`. gold는 명패 전용 |
| `audio_manager.dart` | BGM/SFX 싱글톤 (flame_audio) |
| `ad_manager.dart` / `ad_helper.dart` | AdMob 연동 (배너, 전면, 리워드); 광고 ID는 `kReleaseMode`로 자동 전환 |
| `iap_service.dart` | 인앱 결제 서비스 (in_app_purchase 패키지) |
| `shop_page.dart` | 상점/IAP UI (캐릭터 스킨 등) |
| `game_settings.dart` | SharedPreferences 기반 설정 저장 |
| `user_profile.dart` | 닉네임, 국가 국기, 프로필 관리 |
| `character_data.dart` | 캐릭터 정의 6종 + `CharacterStats`(체력/속도/기력 3축) |
| `game_guide_sheet.dart` | 게임 방법 가이드 바텀시트 (아이템 탭은 파워업 제거와 함께 삭제) |
| `services/analytics_service.dart` | Firebase Analytics 래퍼. **이벤트 이름·파라미터는 이 파일에만** 둔다 (모바일 외 no-op) |
| `login_page.dart` | Firebase 인증 UI (Google / Apple(iOS) / 게스트). **첫 실행에는 뜨지 않는다** — 게스트가 랭킹 등록을 시도하거나 프로필에서 로그인을 누를 때만 진입 |
| `services/auth_service.dart` | Firebase Auth 래퍼 (Google, Apple, 익명) |
| `services/invite_service.dart` | 크루 초대 기능 |

### 백오피스 (별도 관리자 앱)
`lib/backoffice/`에 위치. 진입점: `lib/backoffice/main_backoffice.dart`.
Firebase Hosting `/secret_admin/` 경로로 배포됨 (`firebase.json` 참고).
- `dashboard_page.dart` — 실시간 유저/플레이 지표 및 스테이지 성과
- `user_list_page.dart` — 유저 관리 UI
- `play_stats_page.dart` — 플레이 통계 대시보드
- `stage_stats_page.dart` — 스테이지별 성과 분석

### 디자인 시스템
모든 UI는 `design_system.dart`의 네온 테마 사용:
- 색상: `AppColors.primary` (시안), `AppColors.secondary` (빨강), `AppColors.background` (짙은 검정)
- 컴포넌트: `NeonScaffold`, `NeonAppBar`, `NeonCard`, `NeonButton`, `NeonDialog`

### 인증
**게스트 기본화(2026-09):** 앱 첫 실행은 `_ZonberAppState._enterAsGuest()`가 익명 로그인 + 게스트 프로필로 바로 메뉴에 들어간다. 로그아웃도 로그인 화면이 아니라 게스트로 복귀한다. 게스트는 **랭킹 등록 불가**(기록은 증발) — 로그인은 `ResultPage`의 점수 제출 시점에만 요구한다.

Firebase Auth 3가지 로그인 방식 (Google, Apple(iOS 전용 노출), 게스트/익명):
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
# 주간 종합 점검 (번역 키, 스테이지 키, 에셋 존재 여부, 버전 확인)
node scripts/weekly_check.mjs

# EN/KO 번역 키 누락만 검사
node scripts/check_translations.mjs

# Firestore 랭킹 데이터 정합성 검사
node scripts/check_rankings.mjs

# Firestore 오래된 스테이지 레코드 정리
node scripts/cleanup_stages.mjs
```

**자동 훅** (`.claude/settings.local.json`에 설정됨):
- `translations.dart` 수정 후 → `check_translations.mjs` 자동 실행
- `game_config.dart` 수정 후 → 스테이지 개발 체크리스트 표시
- `character_data.dart` 수정 후 → 캐릭터 개발 체크리스트 표시

## 기능 개발 체크리스트

### 새 월드 추가·활성화 시
1. `world_config.dart` — `WorldData.worlds`에 `WorldConfig` 추가(난이도 순). `rankingMapId`는 새 Firestore `maps/{id}`
2. `translations.dart` — `world_{id}`, `world_{id}_tagline`, `proj_*` 키 EN + KO
3. 스포너 전략은 `ring`(플레이어/골대 중심 원주)과 `sideline`(맵 4변 바깥) 두 가지. 새 전략은 `BulletSpawner._spawnBullet()`에 분기
5. 배경·히어로 이미지는 `assets/images/worlds/{id}_bg.png`, `{id}_hero.png` 슬롯에 넣으면 자동 반영(없으면 코드 드로잉). 더미 재생성 `node scripts/make_dummy_assets.mjs`
4. 홈 캐러셀·랭킹 탭·프로필 그리드는 `WorldData.worlds`를 그대로 순회하므로 UI 수정 불필요

### 새 스테이지(장애물 레이아웃) 추가 시
1. `game_config.dart` — `GameConfig.stages`에 `StageConfig` 추가
2. `translations.dart` — `nameKey`, `descKey` 키를 EN + KO 양쪽에 추가
3. `map_selection_page.dart` — 스테이지 카드 UI 확인
4. Firestore — `maps/{stageId}` 문서 생성 (스크립트 또는 콘솔)
5. `node scripts/weekly_check.mjs` — 키 누락 없는지 최종 확인

### 새 캐릭터 추가 시
1. `character_data.dart` — `CharacterData.availableCharacters`에 `Character` 추가 (`CharacterStats`의 체력/속도/기력 3축 밸런싱)
2. `assets/images/characters/{id}.png` — 에셋 파일 추가 (`pubspec.yaml`은 폴더 단위 등록이라 수정 불필요)
3. `character_selection_page.dart` — UI에 캐릭터 카드 표시 확인
4. `statistics_page.dart` — `_characterName()` / `_characterIcon()`에 분기 추가
5. `backoffice/play_stats_page.dart` — `_characterNames`에 추가
6. `translations.dart` — 이름/설명 키를 EN + KO 양쪽에 추가
7. `shop_page.dart` + `iap_service.dart` — 유료 캐릭터인 경우 IAP 항목 추가 (현재 IAP 비활성)

> ⚠️ `Player.render()` 수정은 **불필요**합니다. `Player`는 `SpriteComponent`라 `imagePath`만 있으면 자동 렌더링됩니다. 도형 분기 코드는 존재하지 않습니다.

### 파워업(아이템) 시스템
2026-09에 **제거됨**. `powerup_system.dart`·`PowerUpManager`·`PowerUpComponent`·HUD 오버레이·가이드 아이템 탭·`powerup_*` 문자열이 모두 삭제됐다. 월드별 기믹은 [docs/GAME_TYPES_DESIGN.md](docs/GAME_TYPES_DESIGN.md) 설계를 따른다. 다시 넣지 말 것.

### 새 업적 추가 시
1. `achievement_manager.dart` — `AchievementDef` 상수 추가 + `allAchievements` 리스트에 등록
2. `translations.dart` — `key`, `descKey` 번역을 EN + KO 양쪽에 추가
3. 체크 함수 — `bool Function(double survivalTime, int rank)` 형태로 구현

### 릴리즈 전 체크리스트
1. `node scripts/weekly_check.mjs` — 종합 점검 통과 확인
2. `pubspec.yaml` — 버전 번호 올리기 (`version: x.y.z+build`)
3. `flutter analyze` — 신규 warning 없는지 확인
4. `flutter build apk --release` / `flutter build appbundle --release`

> 광고 ID는 `AdHelper.isReleaseMode = kReleaseMode`로 자동 판별됩니다. 릴리즈 빌드는 실제 ID, 디버그는 Google 테스트 ID가 쓰이므로 **수동 토글이 필요 없습니다.**

## 맵 / 스테이지 시스템

### 공식 스테이지 (`game_config.dart`에 정의)
- `zone_1_classic` — 기본 난이도 **← 현재 유일한 출시 스테이지**
- `zone_2_obstacles` — 중앙 대칭 4기둥 + 탄환 반사 (미출시)
- `zone_5_maze` — 절차적 생성 미로 (`maze_generator.dart` 사용, 미출시)

> ⚠️ 메뉴에 스테이지 선택 화면이 없어 `_currentMapId`는 항상 `zone_1_classic`이다.
> 정의·장애물 로직·랭킹 구조는 3개 모두 살아 있으니, 선택 화면만 붙이면 다시 열 수 있다.

### 커스텀 맵 (UGC) — 미출시
- Firestore `custom_maps` 컬렉션에 저장, 그리드는 1D 배열
- 업로드 전 제작자가 30초 생존 검증 필요
- ⚠️ **에디터 진입점이 제거되어 있다.** 업로드된 맵을 플레이할 화면이 없기 때문
  (`getCustomMaps()`의 유일한 호출부는 에디터의 "불러오기" 다이얼로그).
  되살리려면 커스텀 맵 브라우저 화면이 먼저 필요하다.

### 에디터 제한
- 중앙 3x3 타일 (스폰 영역)에는 벽 배치 불가
- 외곽 테두리 타일은 수정 불가

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

custom_maps/
  └── {mapId}               # name, author, width, height, grid[], verified, createdAt
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
- 밸런싱 기준: `invulnBudget`(= maxEnergy × iframeDuration)이 **2.5 ~ 5.0** 범위
- 해금은 `unlockKey`로 판정. 이미 선택 중인 캐릭터는 조건과 무관하게 유지됨
- 렌더링은 `SpriteComponent` + `assets/images/characters/{id}.png`

## 뱃지 / 칭호 숨김

`achievement_manager.dart`의 `kShowAchievementBadges = false`가 리더보드 엠블럼·유저 팝업, 통계 페이지 칭호 섹션(+`getUserTitles` 4회 쿼리), 결과 화면의 순위 업적 계산(8회 쿼리)을 모두 끈다. 생존 업적은 캐릭터 해금에 쓰이므로 계속 계산·저장된다. 뱃지 구조 개편이 끝나면 플래그와 분기를 함께 제거한다.

## Analytics

`AnalyticsService()`(모바일 전용, 그 외 no-op). 퍼널: `session_ready`(유저 속성 `is_guest`/`login_provider`) → `game_start` → `game_over`(+표준 `post_score`) → `revive` | `score_submit` | `guest_ranking_blocked`. 화면은 `_navigateTo()`에서 `logScreen(page)`로 자동 기록. 새 이벤트는 반드시 `analytics_service.dart`에 메서드로 추가하고 호출부에서 문자열을 만들지 않는다.

## 오디오 에셋

`assets/audio/` 위치. **현재 파일은 전부 합성 플레이스홀더**(Node로 생성, 라이선스 무관)이며 정식 에셋으로 교체 대상:
- `bgm.mp3` — 배경 음악 (루프, 30초 128BPM)
- `hit.wav` — 피격(에너지 소모), `gameover.wav` — 게임 오버, `shoot.wav` — 슬롯만 확보(미사용: 초당 10발 스폰마다 재생하면 소음)
- 설정 › 사운드 토글(`MyProfilePage`)이 `GameSettings.setSound` + BGM 정지를 처리한다

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
