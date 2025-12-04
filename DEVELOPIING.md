📂 [ZONBER] 개발 진행 상황 및 인수인계서
최종 업데이트: 2025.12.05 프로젝트 경로: C:\zonber (D드라이브 빌드 오류로 이동함) 패키지 명: com.zonber.game

✅ 1. 개발 진행률 체크리스트
Phase 1: MVP (플레이어 & 탄막) - [완료]
[x] Flutter + Flame 프로젝트 세팅

[x] 플레이어 이동 (터치 드래그, 1:1 반응)

[x] 무한 탄막 생성 (Bullet Spawner)

[x] 충돌 판정 (HitBox) 및 Game Over 로직

[x] 생존 시간(점수) 타이머 UI

Phase 1.5: 플레이 경험 개선 - [완료]
[x] 광활한 맵 (2000x2000) 구현

[x] 카메라 추적 (Camera Follow) 시스템

[x] 배경 그리드(Grid) 및 이동 제한 (투명 벽)

[x] 외곽 벽 제거 (무한한 어둠 컨셉)

Phase 2: 데이터 & 랭킹 - [완료]
[x] Firebase 프로젝트 생성 및 연동 (com.zonber.game)

[x] 안드로이드 빌드 설정 (Gradle, Multidex, Permission)

[x] Firestore 데이터베이스 읽기/쓰기 로직 구현

[x] 게임 오버 후 이니셜 입력 UI

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

🛠️ 2. 핵심 파일 및 설정 변경 내역 (중요)
다른 환경에서 개발을 이어갈 때, 이 설정들이 유지되어야 앱이 실행됩니다.

A. 안드로이드 필수 설정 (Android Native Config)
패키지 이름 변경: com.zonber.game

폴더 경로: android/app/src/main/kotlin/com/zonber/game/ (폴더명 game으로 변경됨)

MainActivity.kt: 상단에 package com.zonber.game 선언.

build.gradle.kts: applicationId = "com.zonber.game" 설정.

Firebase 키 파일:

android/app/google-services.json 파일이 com.zonber.game 패키지명과 일치해야 함.

권한 및 안정성:

AndroidManifest.xml: <uses-permission android:name="android.permission.INTERNET"/> 추가됨.

build.gradle.kts: multiDexEnabled = true 및 implementation("androidx.multidex:multidex:2.0.1") 추가됨.

B. 주요 소스 코드 구조 (lib/)
main.dart: 게임의 진입점. FlameGame 루프, 플레이어/탄막/UI 로직이 모두 포함됨. (웹 지원 코드는 안정성을 위해 제거됨)

ranking_system.dart: Firebase Firestore와 통신하는 전담 파일. saveRecord()와 getTopRecords() 함수 포함.

editor_game.dart: 맵 에디터 로직 (MapEditorGame) 및 UI (EditorUI).

⚠️ 3. 개발 환경 주의사항 (Troubleshooting)
혹시 개발 PC를 옮기거나 포맷했을 때 발생하는 에러 대처법입니다.

빌드 캐시 오류 (different roots Error):

C드라이브와 D드라이브가 섞여서 빌드가 안 될 경우, android/gradle.properties 파일에 아래 설정을 꼭 확인하세요.

Properties

kotlin.incremental=false
ClassNotFoundException 크래시:

앱이 켜자마자 죽는다면, MainActivity.kt의 패키지 선언과 실제 폴더 경로(com/zonber/game)가 일치하는지 확인하세요.

📝 4. 다음 개발 단계 (Next Step)
개발을 다시 시작하실 때, Phase 3. 맵 에디터부터 진행하시면 됩니다.

맵 데이터 구조 정의: 20x20 배열(List<List<int>>)을 사용하여 벽(1)과 빈 공간(0)을 저장하는 로직 구상.

UI 모드 전환: 게임 모드(ZonberGame)와 에디터 모드(EditorGame)를 분리하거나, 오버레이 UI로 타일 설치 기능 구현.

고생 많으셨습니다! 핵심 난관인 서버 연동과 안드로이드 빌드를 뚫었으니, 이제부터는 콘텐츠를 채워 넣는 재미있는 개발만 남았습니다.

새로운 환경에서도 건승을 빕니다! ZONBER 대박 나세요! 🚀