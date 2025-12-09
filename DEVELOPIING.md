📂 [ZONBER] 개발 진행 상황 및 인수인계서
최종 업데이트: 2025.12.09 프로젝트 경로: d:\zonber 패키지 명: com.zonber.game

✅ 1. 개발 진행률 체크리스트
Phase 1: MVP (플레이어 & 탄막) - [완료]
[x] Flutter + Flame 프로젝트 세팅
[x] 플레이어 이동 (터치 드래그, 1:1 반응)
[x] 무한 탄막 생성 (Bullet Spawner)
[x] 충돌 판정 (HitBox) 및 Game Over 로직
[x] 생존 시간(점수) 타이머 UI

Phase 1.5: 플레이 경험 개선 - [완료]
[x] 광활한 맵 (480x800 고정) 구현
[x] 카메라 추적 (Camera Follow) 시스템 (고정 카메라로 변경됨)
[x] 배경 그리드(Grid) 및 이동 제한
[x] 맵 클리핑 (MapArea) 적용 - 탄 및 플레이어가 맵 밖으로 나가면 잘림

Phase 2: 데이터 & 랭킹 - [완료]
[x] Firebase 프로젝트 생성 및 연동 (com.zonber.game)
[x] 안드로이드 빌드 설정 (Gradle, Multidex, Permission)
[x] Firestore 데이터베이스 읽기/쓰기 로직 구현
[x] 게임 오버 후 닉네임 자동 저장 및 UI
[x] Top 10 리더보드 출력 UI
[x] 실기기 테스트 및 크래시 해결 완료

Phase 3: 맵 에디터 (UGC) - [진행 중]
[x] 그리드 기반 맵 에디터 UI 개발 (Main Menu & Editor Mode)
[ ] 유저 커스텀 맵 저장/불러오기 (grid_data)
[ ] 맵 제작 3대 원칙 검증 로직

Phase 4: 폴리싱 & 출시 - [대기 중]
[ ] 사운드 (BGM, SFX) 적용
[ ] 그래픽 리소스 교체 (네온 스프라이트 적용)
[ ] 수익화 (AdMob)

Phase 5: 개인화 및 확장 - [완료]
[x] 맵 별 기록 저장 (Firestore 구조 변경)
[x] 유저 닉네임 설정 페이지 (최초 실행 시 또는 설정 메뉴)
[x] 유저 국기(Flag) 선택 (모든 국가 지원)
[x] 맵 선택 페이지 (게임 시작 전 맵 고르기)
[x] Zone 3: Obstacles (장애물 맵) 추가 - 고정형 장애물, 도탄(Ricochet) 구현

Phase 6: 게임성 강화 및 콘텐츠 확장 (신규 요구사항) - [To Do]
[ ] **완벽한 충돌 처리 (Collision Robustness)**
    - [ ] 플레이어가 장애물 내부로 절대 침범하지 못하도록 물리 보완 (Tunnelling 방지)
    - [ ] 탄알이 장애물 내부로 뚫고 들어가는 현상 수정 (도탄 시점 보정)

[ ] **장애물 고도화**
    - [ ] 장애물 생성 시 서로 겹치지 않게 배치 (Non-overlapping Spawning)
    - [ ] 장애물 디자인 적용 (단색 박스 -> 스프라이트/디자인 입히기)

[ ] **캐릭터 시스템**
    - [ ] 플레이어 캐릭터 크기 축소 (히트박스 정밀화)
    - [ ] 캐릭터 선택 시스템 (Character Selection Page) 추가
    - [ ] 다양한 캐릭터(스킨) 추가

[ ] **랭킹 시스템 확장**
    - [ ] 랭킹 전용 페이지 생성 (맵 선택 화면 등에서 진입)
    - [ ] Top 30위까지 표시 확장
    - [ ] 내 순위가 30위 밖일 때도 내 등수/기록 표시 기능 추가

[ ] **UI/UX 통합**
    - [ ] 위의 기능(캐릭터 선택, 랭킹 보기)을 포함하는 메인 메뉴 및 페이지 네비게이션 재설계


🛠️ 2. 핵심 파일 및 설정 변경 내역 (중요)
다른 환경에서 개발을 이어갈 때, 이 설정들이 유지되어야 앱이 실행됩니다.

A. 안드로이드 필수 설정 (Android Native Config)
패키지 이름 변경: com.zonber.game
폴더 경로: android/app/src/main/kotlin/com/zonber/game/ (폴더명 game으로 변경됨)
MainActivity.kt: 상단에 package com.zonber.game 선언.
build.gradle.kts: applicationId = "com.zonber.game" 설정.
Firebase 키 파일: android/app/google-services.json 파일이 com.zonber.game 패키지명과 일치해야 함.
권한 및 안정성:
AndroidManifest.xml: <uses-permission android:name="android.permission.INTERNET"/> 추가됨.
build.gradle.kts: multiDexEnabled = true 및 implementation("androidx.multidex:multidex:2.0.1") 추가됨.

B. 주요 소스 코드 구조 (lib/)
main.dart: 게임의 진입점. FlameGame 루프, 플레이어/탄막/UI 로직이 모두 포함됨.
ranking_system.dart: Firebase Firestore와 통신하는 전담 파일. saveRecord()와 getTopRecords() 함수 포함.
editor_game.dart: 맵 에디터 로직 (MapEditorGame) 및 UI (EditorUI).
user_profile.dart: 유저 프로필(닉네임, 국기) 관리.
map_selection_page.dart: 맵 선택 및 잠금 해제 UI.

⚠️ 3. 개발 환경 주의사항 (Troubleshooting)
혹시 개발 PC를 옮기거나 포맷했을 때 발생하는 에러 대처법입니다.
빌드 캐시 오류 (different roots Error):
C드라이브와 D드라이브가 섞여서 빌드가 안 될 경우, android/gradle.properties 파일에 아래 설정을 꼭 확인하세요.
kotlin.incremental=false

ClassNotFoundException 크래시:
앱이 켜자마자 죽는다면, MainActivity.kt의 패키지 선언과 실제 폴더 경로(com/zonber/game)가 일치하는지 확인하세요.

📝 4. 다음 개발 단계 (Next Step)
Phase 6의 항목들을 순차적으로 구현하여 게임의 완성도를 높이시면 됩니다.
특히 '캐릭터 선택'과 '장애물 디자인'은 게임의 비주얼 퀄리티를 크게 높일 수 있습니다.

고생 많으셨습니다! ZONBER 대박 나세요! 🚀