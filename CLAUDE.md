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
- 밸런스 수치 `lib/balance.dart` · 시즌 `lib/season.dart`(**랭킹 = 시즌 하나**, 주간·월간 없음 — 백오피스 › 시즌에서 연간·분기·월간·N일 선택, `config/season`. 끝나면 `hall_of_fame/{id}` 명예의 전당 · 마감 30·10·3일 전 자동 푸시 `functions/season.js`) · 일일 미션 `lib/daily_rewards.dart` · 판 기록 `lib/run_history.dart`(서버 — 백오피스 대시보드 [상세보기] 의 "존별 끝난 레벨 분포"가 읽는다)
- 테스트 `flutter test`(test/logic_test.dart) · 규칙 시험 `node scripts/test_rules.mjs`
- 효과음 `assets/audio/*.wav` — `python scripts/make_sfx.py` 로 합성, 이름·연결은 `lib/audio_manager.dart`(Sfx) · 존별 배경음악 `bgm_{존 id}.mp3` — `python scripts/make_bgm.py` (공용 DSP `scripts/audio_dsp.py`) · 진동 `lib/haptics.dart`

### 진입점 & 네비게이션
`main.dart`:
- 앱 초기화 (Firebase, AdMob, GameSettings, AudioManager)
- `ZonberApp` 위젯에서 `_currentPage` 상태로 페이지 라우팅
- 페이지: Menu(=HomePage), Ranking, MyProfile(=ProfilePage) ← 하단 탭 3개 / Game, Result, Badges, Profile(최초 설정), Login, Shop, Promo(이벤트 — 홈 이벤트 배너로 진입) (캐릭터 고르기 = 상점 캐릭터 탭, CharacterSelect 페이지는 2026-09-22 제거). 맵 에디터·커스텀 맵·Hall of Fame 은 2026-09-22 코드째 제거
- 월드 상태: `_currentWorldId` · `_bestTimes` · `_rankCache`. 랭킹 mapId는 `_currentWorld.rankingMapId`

### 게임 코어 (Flame 엔진)
`main.dart`의 `ZonberGame` 클래스:
- 고정 맵 크기: 480x768 (32px 타일 기준 15x24 그리드)
- World height: 800 (맵 하단 UI 영역 포함)
- 컴포넌트: `Player`(근접 회피 카운트, `keeperMode`면 공에 닿으면 세이브·`concedeGoal()`로 실점), `Bullet`(`ProjectileDef` 기반: 크기·색·straight/curve/bounce, 큰 공은 바닥 그림자, keeper면 골대 진입 시 실점), `BulletSpawner`(ring, keeper는 골대 기준 스폰·조준 / thrower → `_DodgeballThrower`: 피구 턴제 투구·단계별 패턴, `Bullet.splitAfter`로 분열 / shooter → `_KeeperShooter` + `KeeperGoal`: 페널티킥형 골문·슈터 1→5명·바나나킥). 진입 예고 표시 없음, `GoalZone`(keeper 골대), `MapArea`, `GridBackground`(스테이지 line 색 테두리 + `worlds/{id}_bg.png` 배경 슬롯)
- 목표선: `_loadTargets()`가 올해 TOP 100 시간을 읽어 `game.setTargets()` → HUD가 다음 TOP N 까지 진행바 표시 (10분 캐시)
- 터치 조작: 직접 드래그 (1:1 손가락 이동, 조이스틱 없음)
- 충돌 시스템: Flame의 `HasCollisionDetection` + 탄환 터널링 방지 수동 처리
- 게임 오버: 엔진을 멈추지 않고 KO 연출 `koDuration` 1.4초(탄 0.3배 슬로) + `_GameOverOverlay` → 그 뒤 `onGameOver` 한 번

### 주요 파일
| 파일 | 역할 |
|------|------|
| `world_config.dart` | **스테이지 3종, 항상 열림** (`WorldConfig`/`ProjectileDef`/`SpawnStrategy`/`WorldMode`) — 1 Cyber · 2 Dodgeball(sideline 스포너) · 3 Keeper(mode keeper: 골대 반지름·lives 5). 리더보드는 전부 신규 mapId. 기획 [docs/STAGES.md](docs/STAGES.md) |
| `progress_store.dart` | 월드별 최고 기록·순위 캐시. SharedPreferences + Firestore `users/{uid}.bestTimes` (옛 `plates` 는 로그인 때 뱃지로 옮김) |
| `pages/home_page.dart` | 홈 — 월드 캐러셀·캐릭터·START. 캐러셀은 **양쪽으로 끝없이 돈다**(2026-10-28 — 페이지를 존 수 × 400 으로 이어 붙이고 존 = 페이지 % 존 수, 탭·점은 가까운 쪽으로) |
| `pages/ranking_page.dart` | 랭킹 탭 — 월드 탭 × 세계/국가/친구, 포디움, 내 행 고정. 목록을 **좌우로 쓸면 존이 바뀐다**(끝에서는 처음으로, 2026-10-28 `_swipe`). 기간은 **시즌 하나**(머리의 시즌 칩 = 이름 · 마감 D-day → `pages/hall_of_fame_page.dart` 명예의 전당) |
| `pages/hall_of_fame_page.dart` | **명예의 전당**(2026-10-28 트로피 홀로 다시 그림 — [docs/UI_DESIGN.md](docs/UI_DESIGN.md) §4.9) — `hall_of_fame/{시즌 id}`(끝난 시즌의 존별 TOP 3, 서버 함수가 쓴다)를 시즌별 칩 · 존 상패 3장으로. 머리는 트로피(`assets/images/hall/trophy.png` 슬롯, 없으면 코드 드로잉) + 도는 빛줄기 + 금가루, 1위는 금 메달리온(`AvatarStage` 전신 + 3.6초마다 빛 쓸기, 기록 Display 28 gold), 2·3위는 은·동 줄. 끝난 시즌이 없으면 빈 포디움. 움직임은 `disableAnimations` 면 멈춤. 문구 `hall_*` 4개 언어 · 스크린샷 모드 가짜 시즌 `StoreShot.hallOfFame()` |
| `pages/result_page.dart` | 결과 — 기록 제출, 순위 카드(사람 단위 — 랭킹 탭과 같은 목록), 새로 얻은 뱃지 |
| `pages/profile_page.dart` | 프로필 탭 — 대표 뱃지·월드별 기록·캐릭터·설정·계정 (구 `MyProfilePage` 대체) |
| `ranking_system.dart` | Firestore 리더보드: 기록 저장/조회, 국가별 랭킹, 기간은 **이번 시즌**(`Season.now` 시작~끝, 2026-10-26 주·월·올해 제거). 랭킹·결과 화면 순위·목표선 모두 **사람 단위**(한 사람 = 가장 좋은 기록, `_bestPlayers` 30초 캐시, 순위는 나를 빼고 센다) |
| `achievement_manager.dart` | 9개 업적 (생존 티어, 국가/글로벌 랭킹); SharedPreferences + Firestore 이중 저장 |
| `translations.dart` | 200개+ 이중 언어 문자열 (EN/KO); `{placeholder}` 보간 지원 |
| `language_manager.dart` | 언어 전환; SharedPreferences에서 읽음 |
| `design_system.dart` | 디자인 시스템 v2 — 다크 무채색 + 월드 강조색 1개, Sora(Display)/Manrope(Body). `Neon*` 이름 유지 + `AppChip`/`AppSegmented`/`CountryChip`/`NamePlate`/`RankRow`/`AppBottomNav`. gold는 1위·뱃지 강조 전용 |
| `loadout.dart` | **착용 보너스 단일 출처** — `Loadout.bonusOf(zone, equipped)` = 존 장비(`gear.dart`) + 꾸미기(`cosmetics.dart`)의 **코인 +%** 합계. **전투 능력치(속도·무적·회복·에너지·막는 범위)는 2026-10-26 전부 제거** — 장비·꾸미기·펫은 외형이고 랭킹은 순수 실력 경쟁. 코인 +% 는 **가격 구간 규칙 하나**(`GearBonus.forPrice` — 600↑ +5% · 1000↑ +10% · 뱃지 보상 +10%, 2026-10-28, 목록에 수치를 따로 적지 않는다). 코인 정산·가방 표시가 쓴다(게임 `Player` 는 더는 안 본다). 장비 카탈로그는 63 → 39종(`GearItem.retired` = 상점에서 숨김, 가진 사람만 봄) |
| `pets.dart` | **펫 오라 그림**(2026-10-26 펫을 주위를 도는 오라로 합침 — `Cosmetic.pet`, 오라 칸에서 고른다. 펫 슬롯·탭·"도는 오라와 같이 못 쓴다" 규칙 없음). id·가격은 예전 펫 그대로라 산 기록이 이어지고, 예전 착용 슬롯 `pet` 은 읽을 때 오라로 옮긴다(`Cosmetics.migrateEquipped` · 남의 문서는 `auraFrom`). 그림은 시안 아트(`PetArt` · `paintPet`), `paintAura` → `paintPetAura`. 탄·공에 영향 없음. 기획 [docs/SHOP.md](docs/SHOP.md) §펫 오라 |
| `game/sprites.dart` | **시안 아트**(2026-10-12, Gemini) — `GameSprites`: 운석 4종 · 피구공·축구공 · 피구 상대 선수 그림(`assets/images/sprites/`)을 기다리지 않고 읽고, 없으면 코드 드로잉. `ProjectileDef.sprite`/`tintSprite`. `--dart-define=ART=code` = 코드 드로잉만. 자르기 `python scripts/cut_sprites.py`(원본 `assets/images/gemini/`). [docs/RESOURCES.md](docs/RESOURCES.md) §시안 아트 |
| `avatar.dart` | **아바타 단일 출처** — `Avatar`(캐릭터·스킨·잔상·오라(펫 포함)·존별 장비 한 벌) + `AvatarView`(동그란 아바타) + `AvatarStage`(큰 전신, 잔상·오라까지). 아바타를 그리는 곳은 전부 여기를 쓴다(홈·랭킹·가방·프로필·게임 `Player`) |
| `player_profile.dart` | **프로필 단일 출처** — `PlayerProfile`(닉네임·국가·아바타·가입일·최근 접속·뱃지·존별 기록·누적) + `PlayerProfileService.fetch(uid)`. 내 것과 남의 것이 같은 클래스 |
| `pages/player_profile_view.dart` | 프로필 표시 부품 — `ProfileIdentityCard`/`StageRecordRow`/`ProfileMetaLine`/`ProfileBadgeStrip` + `showPlayerCard(uid)`(랭킹에서 이름을 누르면 뜨는 남의 프로필 창) |
| `audio_manager.dart` | BGM/SFX 싱글톤 (flame_audio) |
| `ad_manager.dart` / `ad_helper.dart` | AdMob 연동 (배너, 전면, 리워드); 광고 ID는 `kReleaseMode`로 자동 전환 |
| `services/new_user_service.dart` | `NewUser` — 설치 시각(OS `installTime`)으로 **첫 24시간 전면 광고 없음** + `engaged_user`(기기당 한 번: 첫날 3판 · 24~48시간 복귀) — 유료 유입 테스트 [store/paid_ua_test.md](store/paid_ua_test.md) |
| `shop_page.dart` | 상점(가방, 2026-10-28 다시 짬 — [docs/SHOP.md](docs/SHOP.md) §상점 화면) — 위에서 아래로 **미리보기 · 탭 한 줄(캐릭터·스킨·잔상·오라·장비) · 3열 그리드(싼 것부터 자리 고정)**, 장비 탭에만 존 고르기, 안 가진 것을 누르면 아래 **구매 바 하나**. 카드 상태는 장착 중(존 색 + 체크)·입어 보는 중(흰 테두리 + 눈) 둘뿐. 홈에서 고른 존을 `zoneId` 로 받는다. 인앱 결제는 없다(2026-10-26 `iap_service.dart`·`in_app_purchase` 제거 — 광고 제거 IAP 를 다시 할 땐 새로 넣는다) |
| `game_settings.dart` | SharedPreferences 기반 설정 저장 |
| `user_profile.dart` | 닉네임, 국가 국기, 프로필 관리 |
| `character_data.dart` | 캐릭터 정의 8종 + `CharacterStats`(능력치는 전부 동일 — 캐릭터는 외형·표정만 다르다) |
| `game_guide_sheet.dart` | 게임 방법 바텀시트 — 홈 위 **?** 아이콘(2026-10-26 연결 — 그전엔 어디서도 열리지 않았다). 공통 3줄 + 존 3곳 규칙 |
| `services/analytics_service.dart` | Firebase Analytics 래퍼. **이벤트 이름·파라미터는 이 파일에만** 둔다 (모바일 외 no-op) |
| `services/share_service.dart` | **공유 단일 출처** — `ShareLinks.url(lang, src, code)`(공유용 페이지 `/get/{lang}/?src=&c=` 주소 — `c` = 내 친구 코드) + `ShareService.share`(OS 공유 창 · 안 되면 복사 · `share` 이벤트). 공유 문구에 스토어 주소를 직접 쓰지 않는다 |
| `services/reminder_service.dart` | **주간 알림**(로컬 알림, 서버 없음) — 앱을 켜거나 돌아올 때마다 `reschedule()` 이 날짜를 박은 한 번짜리 알림을 7·14·21·28일 뒤로 다시 건다(반복 예약 periodicallyShow 는 켜자마자 뜨는 플러그인 버그가 있어 쓰지 않는다 — 한 달 넘게 안 오면 더 보내지 않는다). 켤 때 트레이의 지난 알림도 비운다(`clearShown`) → **일주일 동안 안 들어온 사람에게만** 간다. 권한은 첫 판 뒤 홈으로 나갈 때 한 번(`maybeAsk`, 리뷰 창과 겹치지 않게), 끄기는 프로필 › 설정 › **알림**(토글 하나가 주간 알림·이벤트 소식·친구 알림을 같이 켜고 끈다, 2026-10-26). Android 는 desugaring·수신기·`ic_notification`(+ `res/raw/keep.xml`) 필요 |
| `push.dart` | **푸시 단일 출처** — 토픽(`lang_{ko|en|ja|zh}` + `member`/`guest` + 관리자 기기 `tester`) · 대상(`PushAudience`) · 발송 문서(`PushCampaign` = `push_campaigns/{id}`) · 템플릿 문구 8종(`PushTemplates`, 4개 언어). `functions/index.js` 와 약속이 같아야 한다. 운영법 [docs/PUSH.md](docs/PUSH.md) |
| `services/push_service.dart` | 이벤트·소식 푸시(FCM) 받기 — `sync()` 가 언어·로그인·설정에 맞게 토픽 구독(앱 시작·복귀·언어 변경·로그인/로그아웃). 앱을 켜 둔 채 온 푸시는 띄우지 않는다(종 아이콘 점만). 기기 토큰은 저장하지 않는다. 끄기는 프로필 › 설정 › 이벤트·소식 알림 |
| `app_release.dart` · `services/update_service.dart` | **앱 버전 · 업데이트 안내**(2026-10-12) — `AppVersion`(pubspec `이름+빌드` → "v2.1.0 (210)", 유저 문서 `appVersion`·`appBuild`) · `AppRelease`(Firestore `config/app_release` = 백오피스 › 앱 버전 에 적은 스토어 버전). 이 앱 빌드가 그보다 낮으면 홈에서 안내 창(나중에 → 3일), 필수 버전보다 낮으면 닫을 수 없다. 백오피스에는 버전 이름만 적고 빌드는 백오피스가 채운다(`PlatformRelease.buildFor`). 첫 홈 · 앱 복귀 때만(판 끝나고 돌아올 때는 안 띄움). [업데이트] = 스토어 페이지(`in_app_review openStoreListing`). 규칙·버전 규칙 [docs/RELEASE.md](docs/RELEASE.md) |
| `admin_emails.dart` | 관리자 이메일 — 백오피스 로그인 · 푸시 tester 토픽. `firestore.rules isAdmin()` · `functions/index.js ADMIN_EMAILS` 와 같게 |
| `friends.dart` | **친구 단일 출처**(docs/FRIENDS.md) — 읽기는 앱이 직접(`users/{me}/friends` · `friend_requests`), 쓰기는 서버 함수(`addByCode` · `request` · `answer` · `remove` → `functions/friends.js`). `FriendResult` 코드는 서버와 같다. 친구 코드는 바로 친구, 랭킹·프로필 카드에서는 요청→수락. 최대 100명 · 대기 요청 50 · 요청 7일 |
| `pages/friends_page.dart` | 친구 화면(프로필 탭 › 친구) — 내 코드(복사·공유) · 코드로 추가 · 받은 요청 · 친구 랭킹(존별 최고 기록) |
| `inbox.dart` · `pages/inbox_page.dart` | **알림 페이지**(홈 위 종 아이콘) — 친구 알림 `users/{uid}/inbox`(서버 함수가 쓴다) + 이벤트 소식 `news/{id}`(푸시를 보내면 남는다) 최근 순, 읽음/안 읽음. 푸시를 누르면 여기로 온다 |
| `services/review_service.dart` | `ReviewPrompt` — 신기록·새 뱃지가 있었던 회원이 홈으로 나갈 때, 5판 이상 · 120일에 한 번 앱 리뷰 창(`in_app_review`) |
| `login_page.dart` | Firebase 인증 UI (Google / Apple(iOS) · 게스트로 계속 = 로그인 없이 메뉴로). **첫 실행에는 뜨지 않는다** — 프로필·랭킹에서 로그인을 누를 때 진입. `signInWith`(로그인 단일 출처) + **판 끝 로그인 창** `showLoginPrompt`(2026-10-17) — 게스트가 판을 끝낼 때마다 결과 화면 위에(1.2초 뒤, 이 기록 순위·로그인 선물을 싣는다) 구글·애플 버튼 + 작은 닫기. 로그인하면 가입(닉네임·국가) 화면이나 홈으로, 그리고 **방금 판을 회원 기록으로 이어서 올린다**(`main.dart` `_guestRun` → `_claimGuestRun`: 랭킹 기록·존 최고·판 기록 한 번, 코인·미션·뱃지는 소급 안 함, 다음 판을 시작하면 버림) |
| `services/auth_service.dart` | Firebase Auth 래퍼 (Google, Apple) + `AuthService.isGuest`(게스트 판정 단일 출처) |
| `promotions.dart` | **이벤트(프로모션) 단일 출처** — `Promotion` 모델 · `Promotions.builtIn`(앱 기본 7종, 4개 언어) · `PromoCode`/`PromoCodes`(이벤트 코드: 정리·형식·자동 생성) · `PromoService`(서버 목록 병합·받기·중복 차단·`redeem` 코드 사용). 새 이벤트는 백오피스에서 `promos/{id}` 추가 = 앱 업데이트 없이 반영. 기획·운영법은 [docs/PROMOTIONS.md](docs/PROMOTIONS.md) |
| `pages/promo_page.dart` | 홈 이벤트 배너 + 이벤트 페이지 `'Promo'`(한 줄 = 제목 · 설명 한 줄 · 버튼 / 받기 · 이벤트·친구 코드 입력 · 공유하기 = 내 친구 코드(4~5자)를 실은 OS 공유 창, `share_plus`) |

### 백오피스 (별도 관리자 앱)
`lib/backoffice/`에 위치. 진입점: `lib/backoffice/main_backoffice.dart`.
Firebase Hosting `/secret_admin/` 경로로 배포됨 (`firebase.json` 참고) — 주소 `https://stayzone-88364.web.app/secret_admin/`.
배포는 `deploy_admin.bat` 하나로: 백오피스 웹 번들 + **Firestore 규칙·색인** + **서버 함수**(`functions/` — 푸시 발송 `sendPushCampaign` · 친구 `friends.js` · 탈퇴 정리 · 시즌 `season.js`(매시간 — 마감 전 푸시·명예의 전당), us-central1. `cd functions && npm test`)까지 같이 올린다.
규칙·색인을 빼먹으면 플레이 기록(`users/{uid}/runs` 쓰기 · collection group 읽기)이 조용히 막힌다.
백오피스 Firestore 는 **롱 폴링으로만** 붙는다(2026-10-29 `main_backoffice.dart` — 회사망·보안 프로그램이 스트리밍 응답을 붙잡으면 "Could not reach Cloud Firestore backend" 로 오프라인이 되어 화면이 빈다).
백오피스 카탈로그(`bo_catalog.dart`)는 캐릭터·장비·꾸미기 목록을 **게임 파일에서 그대로 읽는다** — 목록을 베껴 두지 않는다(아이템이 늘면 저절로 따라온다).
**처음엔 요약, 자세한 건 눌러서**(2026-10-27): 화면을 열 때 users 전체·긴 기간 runs 를 읽지 않는다. 숫자는 서버 집계(`usersCount` · `runsCount` — count, 문서를 읽지 않음), 목록은 최근 N개(`latestUsers` · `latestRuns`), 이름표는 `BoData.lookup`(보이는 사람만 한 건씩). users 전체(`BoData.users()`, 캐시)는 대시보드 [상세보기] · 유저 검색·정렬 · 경제 · 앱 버전 · 유저 ID 없는 기록처럼 꼭 필요한 곳에서만. 로딩 표시는 `BoLoading`/`BoSpinner`(= 디자인 시스템 `AppSpinner`) · 오래 걸리는 동작은 `runBusy`.
- `dashboard_page.dart` — **요약**: 전체 회원 · 신규 가입(오늘·7일) · 오늘/7일 판 수 + 신규 가입자 최근 8명 + 최근 플레이 10판. **[상세보기]** 를 눌러야 회원 전체 + 7일 판(최대 5,000)을 읽어 DAU/WAU · 일별 플레이 · 스테이지별 비교 · 존별 끝난 레벨 분포 · 신규 가입 추이 · 캐릭터 사용 · 보유 코인을 보여 준다(접으면 사라짐)
- `user_list_page.dart` — 유저 관리 UI — 처음엔 최근 활동 50명 + 회원 수(집계)만, 검색·정렬·[전체 불러오기] 때 회원 전체를 읽어 화면에서 거른다. 왼쪽 칸으로 여러 명을 골라 **일괄 코인·아이템·국가·삭제**. 삭제는 서버 함수 `adminDeleteUsers`(로그인 계정·랭킹 기록·하위 문서·친구까지 — `functions/admin.js`, 관리자만). 위 전환 [유저 ID 없는 기록](`legacy_records_panel.dart`) = userId 없는 옛 기록 · 유저 문서 없는(탈퇴) 기록을 사람별로 묶어 **회원에 연결**(uid 붙이기 + 더 좋으면 프로필 최고 기록 올림) · **기록 삭제**
- `user_detail_page.dart` · `runs_page.dart` · `ranking_page.dart` · `economy_page.dart` — 유저 상세(탭은 열 때 읽는다) · 판 기록(100판씩 더 보기) · 랭킹 · 경제(회원 전체 분석)
- `promo_page.dart` · `promo_codes_page.dart` — 이벤트 · 이벤트 코드(만들기·검증·사용한 사람)
- `push_page.dart` — 푸시 보내기(템플릿 · 4개 언어 문구 · 대상 · 미리보기 · 테스트 발송) + 보낸 기록
- `season_page.dart` — **시즌**: 연간·분기·월간·N일 · 시즌 1 시작 · 경계 시간대 · 마감 전 자동 푸시(며칠 전·몇 시) · 미리보기(지금·다음 시즌, 푸시 시각) · 명예의 전당 목록
- `app_release_page.dart` — **앱 버전**: 스토어에 나가 있는 버전 이름(Android·iOS 따로, 필수 버전 선택 — 빌드 칸 없음. 빌드는 이 백오피스와 같은 버전이면 그 빌드, 아니면 회원 기록에서 채운다 → 새 버전은 백오피스도 같이 배포) 저장 → 그보다 낮은 앱에 업데이트 안내. 유저 앱 버전 분포 · 안내 받을 사람 수. 유저 상세에도 앱 버전
- 유저 상세 개요 탭 아래 **친구** 카드(`users/{uid}/friends`)
- 이름표(캐릭터·장비·뱃지 한글명)는 `bo_catalog.dart`

### 디자인 시스템
모든 UI는 `design_system.dart`의 네온 테마 사용:
- 색상: `AppColors.primary` (시안), `AppColors.secondary` (빨강), `AppColors.background` (짙은 검정)
- 컴포넌트: `NeonScaffold`, `NeonAppBar`, `NeonCard`, `NeonButton`, `NeonDialog`
- **로딩은 전부 도는 스피너**(2026-10-12): `AppSpinner`(작은 링) · `AppLoading`(빈 칸 가운데) · `runBusy(context, () async {...})`(누른 동작 — 끝날 때까지 화면을 덮는 스피너). 새 화면에 `CircularProgressIndicator` 를 직접 쓰지 않는다

### 인증
**게스트 = 로그인하지 않은 상태 · 게임 맛보기만(2026-09-22):** 앱 첫 실행은 `_ZonberAppState._enterAsGuest()`가 **로그인 없이**(익명 로그인도 하지 않는다) 바로 메뉴에 들어간다. 로그아웃도 게스트로 복귀한다. 게스트는 **서버에는 아무것도 저장하지 않는다**. 기기에는 **존별 최고 기록과 판 코인만** 남긴다(2026-10-26 — 다음 날 돌아와도 어제 기록이 보이게. `ProgressStore` · `CoinStore` `coins_guest`). 로그인하면 최고 기록은 더 좋은 쪽으로 합치고 게스트 코인은 잔액에 더한다(`mergeFromRemote`). 미션·뱃지·통계·프로필·플레이 수는 여전히 없고, 구매·보상 받기는 로그인 안내(`guest_login_to_save`). 저장 차단은 각 store(`CoinStore`·`ProgressStore`·`DailyRewards`·`AchievementManager`·`BadgeStatsStore`·`UserProfileManager`·`PlaytestLog`)가 `AuthService.isGuest`로 직접 막고, `_handleGameOver`도 게스트는 결과만 보여 준다(방금 판 하나만 메모리 `_guestRun` 에 두었다가 로그인하면 `_claimGuestRun` 이 올린다). 로그아웃·가입 취소 때만 기기의 유저 데이터를 지우고(`_enterAsGuest(clear: true)` → `_clearLocalData` — 앱을 켤 때는 지우지 않아 게스트 기록이 남는다), 예전 버전의 익명 세션은 시작 시 로그아웃시킨다. 로그인 세션은 Firebase 가 기기에 저장하므로 다음 실행에 자동 로그인된다. 규칙도 회원(`isMember`)만 쓰기 허용. 예전 게스트 데이터 정리 = `scripts/delete_guest_data.mjs`.

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

# 효과음 · 존별 배경음악 합성(pip install numpy scipy imageio-ffmpeg) / 존 배경 생성
python scripts/make_sfx.py
python scripts/make_bgm.py            # 셋 다 · python scripts/make_bgm.py keeper = 하나만 (약 1분씩 걸린다)
python scripts/make_stage_bg.py

# 시안 아트 — Gemini 시트(assets/images/gemini/src_*.png) → assets/images/sprites/ (배경·워터마크 지우기)
python scripts/cut_sprites.py
# 명예의 전당 트로피 — assets/images/gemini/src_hall_trophy.png(한 장) → assets/images/hall/trophy.png
python scripts/cut_hall.py
# 갤럭시 배경 — 원본에서 별만 옮겨 깔끔한 그라데이션으로(assets/images/worlds/cyber_bg.png)
python scripts/clean_cyber_bg.py

# 광고 동영상(Google Ads 앱 캠페인) — 광고 영상 모드(lib/ad_video.dart) 웹 빌드를 자동 플레이(game/autopilot.dart)로 돌려 한 프레임씩 캡처 → 문구·끝 화면·효과음을 입혀 9:16·16:9·1:1 mp4. ffmpeg 필요(PATH 또는 pip install imageio-ffmpeg)
flutter build web --release --dart-define=STORE_SHOT=true --dart-define=AD_VIDEO=true --output build/web_advideo
node scripts/ad_video_capture.mjs --lang ko   # → build/ad_video/ko/ (장면당 10초, 약 8분 · 언어 ko|en — 게임 화면 글자도 그 언어) · --dry = 찍지 않고 맞은 수·캐릭터 위치만
python scripts/make_ad_video.py --lang ko     # → store/ad_videos/ko/zonber_{portrait_9x16,landscape_16x9,square_1x1}[_15s].mp4 (22초 · 15초)

# 앱 아이콘 — 원본 assets/images/app_icon.png 에서 Android(모서리 투명)·iOS·Play 512 그림을 만든 뒤 플랫폼 아이콘 생성
dart run scripts/make_app_icons.dart
dart run flutter_launcher_icons

# 스토어 스크린샷 — 스크린샷 모드(lib/store_shot.dart) 빌드를 기기에 깔고 캡처 → 합성. 화면 10장, 문구는 scripts/store_shot_captions.mjs
flutter build apk --release --dart-define=STORE_SHOT=true
bash scripts/store_shots.sh <기기 시리얼>                                # 휴대폰 화면 → build/store_shots/
bash scripts/store_shots.sh <기기 시리얼> build/store_shots_ipad --ipad  # 기기 화면을 잠깐 4:3 으로(끝나면 되돌림) → iPad 원본
node scripts/compose_store_shots.mjs   # Play 휴대전화 8장 → store/screenshots_play/
node scripts/compose_ios_shots.mjs     # App Store iPhone 6.9"·iPad 13" 10장 → store/screenshots/
# 기기 잠금을 풀고 화면을 켜 둔다 — 캡처 직전마다 잠금·화면 꺼짐을 보고, 그러면 찍지 않고 멈춘다(잠금 화면 사진이 이미지에 들어가지 않게)
```

> 옛 익명 SDK 관리 스크립트(seed/check/cleanup·마이그레이션)는 2026-09-22 삭제했다. DB 를 고칠 일이 있으면 `test_rules.mjs` 처럼 gcloud 토큰 + REST 로 새로 만든다.

**자동 훅** (`.claude/settings.local.json`에 설정됨 — 개인 로컬 파일, git 추적 안 함):
- `translations.dart` 수정 후 → `check_translations.mjs` 자동 실행
- `character_data.dart` 수정 후 → 캐릭터 개발 체크리스트 표시

## 기능 개발 체크리스트

### 새 월드 추가·활성화 시
1. `world_config.dart` — `WorldData.worlds`에 `WorldConfig` 추가(난이도 순). `rankingMapId`는 새 Firestore `maps/{id}`
2. `translations.dart` — `world_{id}`, `world_{id}_tagline`, `proj_*` 키 EN + KO
3. 스포너 전략은 `ring`(플레이어/골대 중심 원주)과 `sideline`(맵 4변 바깥) 두 가지. 새 전략은 `BulletSpawner._spawnBullet()`에 분기
5. 배경·히어로 이미지는 `assets/images/worlds/{id}_bg.png`, `{id}_hero.png` 슬롯에 넣으면 자동 반영(없으면 코드 드로잉)
6. 배경음악 `assets/audio/bgm_{id}.mp3` — `scripts/make_bgm.py` 의 `SONGS` 에 곡을 더한다(없으면 그 존은 무음)
4. 홈 캐러셀·랭킹 탭·프로필 그리드는 `WorldData.worlds`를 그대로 순회하므로 UI 수정 불필요

### 장애물 레이아웃
2026-09-22 장애물 레이아웃(`zone_2_obstacles` 기둥·`zone_5_maze` 미로)과 `maze_generator.dart` 를 제거했다. 모든 월드가 `zone_1_classic`(장애물 없음)을 쓴다. 장애물 시스템(`Obstacle` 컴포넌트, 탄환 벽 반사 `WallBehavior`/`onWall`/`maxBounces`, 플레이어 밀어내기)도 함께 제거했다.

### 새 캐릭터 추가 시
1. `character_data.dart` — `CharacterData.availableCharacters`에 `Character` 추가 (`CharacterStats`의 체력/속도/기력 3축 밸런싱)
2. 그림 — 캐릭터는 코드 드로잉(`zonber_painter.dart`)이라 색만 정하면 된다 (2026-09-22 1차 AI 아트(`assets/images/game/`·`GameArt`)는 제거했다 — 캐릭터·장비·공·이펙트는 전부 코드 드로잉)
3. `shop_page.dart` 캐릭터 탭에 표시되는지 확인 (캐릭터 고르기 = 상점)
4. `backoffice/bo_catalog.dart` — `kCharNames`에 한글 이름 추가
6. `translations.dart` — 이름/설명 키를 EN + KO 양쪽에 추가

### 파워업(아이템) 시스템
2026-09에 **제거됨**. `powerup_system.dart`·`PowerUpManager`·`PowerUpComponent`·HUD 오버레이·가이드 아이템 탭·`powerup_*` 문자열이 모두 삭제됐다. 월드별 기믹은 [docs/GAME_TYPES_DESIGN.md](docs/GAME_TYPES_DESIGN.md) 설계를 따른다. 다시 넣지 말 것.

### 새 업적 추가 시
1. `achievement_manager.dart` — `AchievementDef` 상수 추가 + `allAchievements` 리스트에 등록
2. `translations.dart` — `key`, `descKey` 번역을 EN + KO 양쪽에 추가
3. 체크 함수 — `bool Function(double survivalTime, int rank)` 형태로 구현

### 릴리즈 전 체크리스트
1. `node scripts/check_translations.mjs` · `flutter test` 통과 확인
2. `pubspec.yaml` — 버전 번호 올리기 (`version: x.y.z+build`, 규칙은 [docs/RELEASE.md](docs/RELEASE.md) 맨 위). 스토어 심사가 끝나면 **백오피스 › 앱 버전** 을 올려 옛 앱에 업데이트 안내
3. `flutter analyze` — 신규 warning 없는지 확인
4. `flutter build apk --release` / `flutter build appbundle --release`

> 광고 ID는 `AdHelper.isReleaseMode = kReleaseMode`로 자동 판별됩니다. 릴리즈 빌드는 실제 ID, 디버그는 Google 테스트 ID가 쓰이므로 **수동 토글이 필요 없습니다.**

## 맵 / 스테이지 시스템

스테이지는 `world_config.dart`의 월드 3종(cyber · dodgeball · keeper)이고, 리더보드 mapId 는 월드의 `rankingMapId`다.
난이도는 **세 존 공통 레벨**(`balance.dart` — 15초마다 1, 최고 15에서 멈춤)로 정한다. 최고 레벨 뒤로는 `Balance.lateGrowth` 가 30초마다 2%씩(최대 1.5배) 빈도·속도를 아주 천천히 올린다(2026-10-26 — 상위권이 집중력 싸움으로만 갈리지 않게). 레벨마다 같은 폭으로 오르고, 존별 값(갤럭시 초당 탄 수·탄속, 피구·골키퍼 턴 간격·속도·패턴 단계)은 `Balance.byLevel`로 레벨 1 ↔ 최고 레벨 사이를 잇는다(2026-09-26, `game_config.dart` 삭제).

> 맵 에디터(UGC)·커스텀 맵(`editor_game.dart`·`map_service.dart`)은 2026-09-22 코드째 제거했다.
> Firestore `custom_maps` 규칙도 2026-10-26 지웠다.

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

promos/{promoId}            # 이벤트 정의(백오피스) + claims(받은 수). 누구나 읽음
promo_codes/{CODE}          # 이벤트 코드 — 보상·campaign·maxUses·uses·기간. 회원은 한 건 get 만(list 는 관리자)
users/{uid}/codes/{CODE}    # 내가 쓴 코드(1인 1회 — 규칙이 promo_codes.uses +1 과 함께만 생성 허용)
friend_codes/{CODE}         # 친구 코드(회원마다 하나, 영문·숫자 4~5자) → {uid}. users/{uid}.friendCode 에도 적는다
friend_invites/{uid}        # 친구 코드 입력 기록(계정당 한 번) {code, inviter, rewarded} — 코드 주인이 보상받으면 rewarded=true

push_campaigns/             # 백오피스 푸시 발송 기록 — 만들면 서버 함수가 보낸다(status · results)
friend_requests/            # 친구 요청 {from, to, status, expiresAt} — 쓰기는 서버 함수만
push_state/                 # 친구 기록 알림 하루 횟수 · 시즌 마감 푸시 보낸 표시 season_{id}_{n}(서버만)
config/season               # 시즌 설정 {mode, firstStart, offsetHours, periodDays, pushDays, pushHour} — 백오피스 › 시즌(공개 읽기)
hall_of_fame/{시즌 id}       # 끝난 시즌의 존별 TOP 3(서버 함수가 쓴다, 공개 읽기)
config/app_release          # 스토어에 나가 있는 버전 {android|ios: {version, build, minBuild, minVersion}} — 백오피스가 쓰고 앱이 읽는다(공개 읽기)
news/                       # 보낸 이벤트·소식(앱 알림 페이지, 공개 읽기) — users/{uid}/inbox(친구 알림) · users/{uid}/inbox_state/news(읽은 소식)
# users/{uid}/friends/{친구uid} · users/{uid}/devices/{기기 id}(친구 알림 토큰, 본인만)
```

랭킹 기간은 **이번 시즌** 하나(2026-10-26 주간·월간·올해 제거 — `config/season` 설정, `hall_of_fame/{시즌 id}` 명예의 전당).
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
| `reminder_enabled` | 주간 알림 (기본 켬) — 설정의 **알림** 토글 하나가 `push_enabled`·`friend_push_enabled` 와 같이 바꾼다 |
| `reminder_asked` | 주간 알림 권한을 이미 물었나 (기기 설정 — 로그아웃에도 지우지 않음) |
| `install_day_runs` · `engaged_logged` | 설치 첫 24시간 안에 끝낸 판 수 · `engaged_user` 를 남겼나 (기기 설정 — 로그아웃에도 지우지 않음, `NewUser`) |
| `push_enabled` | 이벤트·소식 푸시 토글 (기본 켬) |
| `push_topics` | 지금 구독 중인 푸시 토픽 (차이만 고치려고 적어 둔다) |
| `friend_push_enabled` | 친구 알림 토글 (기본 켬 — 기기 문서 friend 값) |
| `push_device_id` · `push_device_sig` | 친구 알림 기기 문서 id · 마지막으로 서버에 쓴 값 |
| `drag_sensitivity` | 드래그 감도 (0.6 ~ 1.8, 기본 1.0) |
| `first_run_done` | 이 기기에서 한 판이라도 끝냈나 — 첫 판에만 튜토리얼(`ZonberGame.tutorial`: 10초 동안 공 반만 + "끌어서 움직여요"). 로그아웃에도 안 지움 |
| `nickname_changed_at` | 닉네임을 마지막으로 바꾼 때(ISO) — 처음은 바로, 그 뒤 30일에 한 번(변경권은 2026-10-26 제거) |
| `coins_guest` | 게스트가 이 기기에서 모은 코인 — 로그인하면 잔액에 합치고 지운다 |
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

2026-09-22 명패·칭호를 뱃지로 바꿨다(41종 — 2026-10-26 장기 경력 5종 제거) — 정의·조건 `lib/badges.dart`, 저장 `lib/achievement_manager.dart`(users/{uid}.achievements). 기획 [docs/BADGES.md](docs/BADGES.md).

## Analytics

`AnalyticsService()`(모바일 전용, 그 외 no-op). 퍼널: `session_ready`(유저 속성 `is_guest`/`login_provider`) → `game_start` → `game_over`(+표준 `post_score`) → `revive` | `score_submit` | `guest_ranking_blocked` → `login_prompt`(action = shown · close — 판 끝 로그인 창) → `guest_run_claim`(로그인 뒤 방금 판을 회원 기록으로).
성장 지표(2026-09-29): 표준 `sign_up`(새 계정)/`login`(재로그인) · `share`(content_type = result·promo) · `promo_claim` · `promo_code_redeem`(실패 포함, 캠페인만) · `earn_virtual_currency`(source)/`spend_virtual_currency`(`CoinStore.add/spend` 가 직접 남긴다) · `unlock_achievement`(뱃지) · `review_prompt`.
유료 유입(2026-10-12): `engaged_user`(reason = runs_3 · day2_return, 기기당 한 번 — `NewUser`) — Firebase 에서 주요 이벤트로 표시해 Google Ads 인앱 전환으로 가져간다.
공유 링크는 `https://stayzone-88364.web.app/get/{lang}/?src=&c=` — `node scripts/make_share_page.mjs` 가 `hosting_root/get/` 에 만들고(OS별 스토어 이동 · Play `referrer` UTM · og 미리보기 · `c`(친구 코드)가 있으면 바로 넘기지 않고 코드 카드를 보여 주고 설치 버튼을 누를 때 복사, Play 에는 `utm_content=코드`. iOS 캠페인은 스크립트의 `APPLE_PT` 를 채워야 잡힌다) `deploy_admin.bat` 이 같이 올린다. 화면은 `_navigateTo()`에서 `logScreen(page)`로 자동 기록. 새 이벤트는 반드시 `analytics_service.dart`에 메서드로 추가하고 호출부에서 문자열을 만들지 않는다.

## 오디오 에셋

`assets/audio/` 위치. **전부 코드로 합성**(녹음·외부 음원 없음, 라이선스 무관 — 2026-10-13 다시 만듦). 정식 음원이 생기면 같은 이름으로 바꾼다:
- `bgm_cyber.mp3` · `bgm_dodgeball.mp3` · `bgm_keeper.mp3` — 존별 배경음악(32마디 약 1분 루프, `scripts/make_bgm.py`). 게임에 들어갈 때 `AudioManager.startBgm(존 id)`
  - 처음 4마디 멜로디(훅)를 곡 내내 되풀이하고 악기는 끝까지 같다 — 갤럭시 128BPM D단조(버티는 신스) · 피구 116BPM C장조(놀리는 "솔-미-라-솔-미" 실로폰) · 골키퍼 124BPM F장조(3+3+2 당김 스틸드럼 · 삼바 타악기)
  - mp3 는 루프 이음매에 아주 짧은 틈이 생길 수 있다(인코더 여백) — 곡 자체는 끝과 처음이 이어지게 만들었다
- 효과음 15개(`Sfx`) — `scripts/make_sfx.py`(v3, 2026-10-13). `hit.wav` 피격, `gameover.wav` 게임 오버 …
  - 휴대폰 스피커 기준 — 200Hz 아래는 줄이고 배음으로 무게를 낸다 · 스테레오 작은 방 잔향
  - 크기는 귀로 듣는 크기(LUFS 근사)로 맞춘다 — 소리별 목표는 스크립트의 `LOUD` 표(배경음악보다 조금 위, 자주 나는 소리는 더 작게), 꼭대기 -3dBFS
  - 자주 나는 소리(`Sfx.busy` — 피격·선방·추가 기록·킥·던지기·코인)는 조금씩 다른 4벌(`hit.wav` · `hit_2.wav` …)을 플레이어마다 하나씩 실어 번갈아 낸다. 벌 수 = `Sfx.busyPlayers` = 스크립트 `VARIANTS`
- 설정 › 사운드 토글(`ProfilePage`)이 `GameSettings.setSound` + BGM 정지를 처리한다

## AdMob 설정

`ad_helper.dart`:
- `isReleaseMode = kReleaseMode` — 빌드 모드로 자동 판별, **수동 설정 불필요**
- 릴리즈 빌드 → 실제 광고 단위 ID / 디버그 빌드 → Google 공식 테스트 ID

`ad_manager.dart` 노출 정책:
- **배너** — 전역 (`AppScaffold` 하단), `ads_removed` 구매 시 숨김
- **전면** — 게임 오버 5회마다. **설치 첫 24시간은 없음**(`NewUser.isFirstDay` — 새 유저 다음 날 재방문을 지킨다)
- **리워드** — 결과 화면 부활, 세션당 1회, 게스트 포함 (사전 고지 다이얼로그 필수 — AdMob 정책)
- **광고 등급 상한 G**(`RequestConfiguration.maxAdContentRating`) — 성인·폭력·공포 광고를 막는다(2026-10-12)
- **앱 전체 아동 대상**(`tagForChildDirectedTreatment: yes`, 2026-10-17) — 초등학생도 하므로 맞춤 광고·광고 ID 추적 없이 아동에게 맞는 광고만. 맞춤 광고가 빠져 광고 수익은 더 준다. `tagForUnderAgeOfConsent` 는 같이 켜지 않는다
  - 그래서 **iOS 추적 허용(ATT) 창을 띄우지 않는다**(2.1.2, `app_tracking_transparency` 패키지 제거). App Store 개인정보 라벨도 추적 전부 "아니요" — 라벨에 추적이 남으면 5.1.2 거절([store/data_safety.md](store/data_safety.md)). Info.plist 의 `NSUserTrackingUsageDescription` 도 뺐다(2.1.2(217)) — 이 키가 바이너리에 있으면 App Store Connect 가 라벨을 "추적 안 함"으로 게시하지 못하게 막는다. 다시 넣지 말 것. AdMob UMP 의 IDFA 안내 메시지(iOS)도 켜지 않는다(키 없이 ATT 창을 띄우려 한다)
- AdMob 콘솔 › 차단 관리(계정 전체 — 같은 계정의 다른 앱에도 적용, 2026-10-12): 광고 콘텐츠 등급 **G** · 민감한 카테고리 차단 = 데이트 · 선정성 · 성·임신 및 출산 관련 건강 · 성에 대한 언급 · 성형수술 및 체형 변형 · 소셜 카지노 게임(도박·주류는 원래 차단). MA→G 전환 시 AdMob 추정 노출 −35% · 수익 −34%

## 스토어 운영 문서 (`store/`)

- `data_safety.md` — Play 데이터 보안 · App Store 개인정보 답안(SDK 를 넣고 빼면 다시 맞춘다)
- `app_store_events.md` — App Store 인앱 이벤트(4개 언어) · 피처링 추천. 이벤트 딥 링크 `zonber://open/events`(Info.plist URL 스킴 + `main.dart` didPushRouteInformation → 이벤트 화면). 그림은 `node scripts/make_event_media.mjs`
- `paid_ua_test.md` — 소액 유료 테스트(Apple Ads · Google 앱 캠페인) 계획

## Android 설정 참고

`android/` 위치:
- 패키지 경로: `android/app/src/main/kotlin/com/zonber/game/`
- `google-services.json`은 패키지명 `com.zonber.game`과 일치해야 함
- Firebase 호환성을 위해 MultiDex 활성화
- 드라이브 간 빌드 오류 발생 시 `gradle.properties`의 `kotlin.incremental=false` 확인
