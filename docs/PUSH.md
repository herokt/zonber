# ZONBER 푸시 — v1.0 (2026-09-30)

> 백오피스에서 **이벤트·소식 알림**을 앱 사용자에게 보낸다. 주간 알림(일주일 안 들어오면 한 번, 기기 안에서만 도는 것)과는 별개다.
> 친구 기록 알림은 친구 기능을 만든 뒤에 붙인다(아직 없음).

## 1. 어떻게 도나

```
백오피스 [푸시] ──(push_campaigns/{id} 생성, status: pending)──▶ Firestore
                                                              │ 트리거
                                              functions/index.js sendPushCampaign
                                              언어마다 FCM 토픽 조건으로 발송 → status: sent/failed · results
앱(PushService) ── 토픽 구독: lang_{ko|en|ja|zh} 하나 + member|guest 하나 + (관리자 계정이면) tester
```

- **기기 토큰은 저장하지 않는다.** 토픽만 쓰므로 정확한 받는 수는 모른다 — 효과는 분석의 `push_open`(campaign = 문서 id)으로 본다.
- 언어는 **앱 언어**를 따른다. 문구를 비운 언어(ja·zh)는 영어로 간다. ko·en 은 필수(규칙이 막는다).
- 설정 › **이벤트·소식 알림**을 끄면 토픽을 전부 해제한다. OS 알림 권한은 주간 알림과 같은 권한이다.

| 대상 | 조건 |
|---|---|
| 전체 | `'lang_xx' in topics` |
| 회원만 | `… && 'member' in topics` |
| 게스트만 | `… && 'guest' in topics` |
| 테스트(관리자 기기) | `… && 'tester' in topics` — 관리자 계정으로 로그인한 기기 |

## 2. 보내는 법 (운영자)

1. 백오피스 → **푸시**
2. 템플릿을 고르거나 직접 쓴다(한국어·영어 필수). 미리보기로 언어별 모습을 본다
3. 받는 사람 **테스트(관리자 기기)** 로 먼저 보내서 내 폰에 오는지 본다
4. 전체(또는 회원만·게스트만)로 보낸다 — 숫자 확인을 거친다. **보내면 되돌릴 수 없다**
5. 오른쪽 기록에서 상태가 `보냄`, 언어별 결과가 `성공`인지 본다(몇 초 걸린다)

**템플릿**(`lib/push.dart` `PushTemplates`): 새 이벤트 · 주간 선물 · 주간 랭킹 마감 · 복귀 유도 · 이벤트 코드 공개 · 업데이트 안내 · 게스트 로그인 유도 · 점검 안내.
템플릿을 늘리려면 이 목록에 한 줄(4개 언어) — 백오피스에 바로 나온다(백오피스 재배포 필요).

**보내는 빈도**: 주 1~2회를 넘기지 않는다. 너무 자주 오면 알림을 끄거나 앱을 지운다.

## 3. 처음 한 번 해 둘 것

| 할 일 | 어디서 |
|---|---|
| iOS: APNs 인증 키(.p8) 올리기 | Firebase 콘솔 › 프로젝트 설정 › 클라우드 메시징 › Apple 앱 구성 |
| iOS: App ID 에 Push Notifications 켜기 | Apple Developer › Identifiers › com.zonber.game (Xcode 자동 서명이면 프로필은 저절로) |
| 서버 함수 배포 | `deploy_admin.bat` (functions 포함) — Blaze 요금제, 첫 배포 때 Cloud Functions·Build·Eventarc API 가 켜진다 |

Android 는 추가 설정이 없다(`google-services.json` 그대로). iOS 는 위 두 가지가 없으면 iPhone 에 오지 않는다(Android 는 온다).

## 4. 구조 (개발자)

```
lib/push.dart                    토픽 · 대상 · PushCampaign(문서) · PushTemplates  ← 정본
lib/services/push_service.dart   앱 — 토픽 구독(sync) · 켜 둔 채 오면 Android 는 직접 띄움 · push_open
lib/services/reminder_service.dart  알림 권한 · news 채널(Android)
lib/backoffice/push_page.dart    백오피스 화면
functions/index.js               sendPushCampaign (push_campaigns 생성 트리거, us-central1)
firestore.rules                  push_campaigns — 관리자만 만들기(pending · 보낸 사람 = 본인 · ko/en 필수), 고치기 불가
```

- `PushService.sync()` 는 앱 시작·돌아올 때·언어 변경·로그인/로그아웃 때 부른다. 구독 중인 토픽을 기기에 적어 두고 차이만 고친다.
- iOS 는 APNs 토큰이 생긴 뒤에야 구독된다 — 아직이면 다음 sync 때 한다.
- 관리자 이메일은 `lib/admin_emails.dart` · `firestore.rules isAdmin()` · `functions/index.js ADMIN_EMAILS` 세 곳이 같아야 한다.
