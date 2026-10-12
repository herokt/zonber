# ZONBER — App Store 인앱 이벤트 · 피처링 추천 신청

> 2026-10-12 작성. App Store Connect 에 붙여 넣는다. 이벤트는 **앱 업데이트 없이** 따로 심사받는다.
> 그림: `store/event_media/{이벤트}_card.png`(16:9, 1920×1080) · `{이벤트}_detail.png`(9:16, 1080×1920) — `node scripts/make_event_media.mjs`.
> 그림에 글자가 없어서 **네 언어 모두 같은 그림**을 쓴다.

## Apple 규칙 (반려를 피하려면)

[In-App Events 안내](https://developer.apple.com/app-store/in-app-events/) 요약:

- **기간이 정해진 일**만 이벤트가 된다(대회·도전·한정 콘텐츠). 최대 31일, 시작 14일 전부터 스토어에 보일 수 있다.
- **안 되는 것:** 매일 하는 일·매일 보상, 새 콘텐츠 없는 가격 할인, 앱을 알리기만 하는 홍보.
  → 그래서 **환영 선물(늘 받음)·주간 선물·공유하기·SNS 코드는 이벤트로 올리지 않는다.** 기간이 있는 **월간 랭킹 · 할로윈 · 연말**만 올린다.
- 이름 30자(영어는 단어 첫 글자 대문자, "event" 같은 말 넣지 않기) · 짧은 설명 50자 · 긴 설명 120자. 가격(₩·$)을 쓰지 않는다. "최고·1위" 같은 확인할 수 없는 말을 쓰지 않는다. 느낌표를 여러 개 쓰지 않는다.
- 그림에 글자·로고·테두리를 넣지 않는다 — 카드 아래쪽은 이벤트 이름이 덮는다.
- 한 번에 승인 15개 · 스토어 게시 10개까지.

## 일정

시간은 한국(KST). 앱 안 할로윈·연말 이벤트는 UTC 0시에 열리고 닫혀서 KST 로는 오전 9시다(`lib/promotions.dart`).

2026-10-12 App Store Connect 에 아래 값으로 **초안 4개를 만들어 두었다**(4개 언어 · 그림 · 배지 · 날짜 · 우선순위 · 딥 링크).
**딥 링크가 필수**라 2.0.6 에는 열 주소가 없다 → **2.0.7(딥 링크 들어간 빌드)을 올릴 때 이벤트 4개를 같은 심사에 넣어 제출**한다(각 이벤트 › "심사에 추가" → 앱 버전과 함께 제출).
날짜 칸은 30분 단위라 끝 시각은 :30 으로 둔다(앱 안 이벤트는 :59 에 닫히니 마지막 30분은 스토어 카드만 먼저 내려간다).

| 이벤트 | 배지 | 이벤트 기간 (KST) | 스토어 게시 시작 | 우선순위 |
|---|---|---|---|---|
| 10월 랭킹 레이스 | 대회(Competition) | 10/13 00:00 ~ 10/31 23:30 | 10/13 00:00 (늦게 승인되면 승인 즉시) | 보통 |
| 할로윈 파티 | 특별 이벤트(Special Event) | 10/24 09:00 ~ 11/3 08:30 | 10/14 00:00 | 높음 |
| 11월 랭킹 레이스 | 대회(Competition) | 11/1 00:00 ~ 11/30 23:30 | 10/18 00:00 | 보통 |
| 연말 선물 | 특별 이벤트(Special Event) | 12/20 09:00 ~ 2027/1/5 08:30 | 12/7 00:00 | 높음 |

- 게시 시작은 **시작 시각 기준 14일 이내**여야 저장된다 — 연말을 12/6 00:00(시작 12/20 09:00 의 14일 9시간 전)으로 두면 저장 버튼이 빨간 ⓘ 로 바뀌며 저장이 안 된다.
- 새 이벤트는 **한 번 저장한 뒤에** 그림을 올린다("새로운 로케일을 저장해야 합니다" 오류). 현지화는 영어 그림을 그대로 쓴다(언어별 그림 불필요).
- 12월 랭킹 레이스부터는 11월 것을 **복제**(⋯ › Duplicate)해서 이름·날짜만 바꾼다.

## 모든 이벤트 공통 설정

App Store Connect › 앱 › (사이드바) **인앱 이벤트** › ＋

| 칸 | 값 |
|---|---|
| 기본 언어 | 한국어 (나머지 English · 日本語 · 简体中文 을 현지화로 추가) |
| 이벤트 딥 링크 | **`zonber://open/events`** (필수 칸) — 이벤트 화면이 열린다. 앱 2.0.7 부터 받는다(Info.plist URL 스킴 `zonber` · `main.dart` didPushRouteInformation) |
| 인앱 구입 필요 | 아니요 |
| 국가 또는 지역 | 전체 |
| 이벤트 카드 미디어 | `store/event_media/{이벤트}_card.png` |
| 이벤트 상세 페이지 미디어 | `store/event_media/{이벤트}_detail.png` |

---

## 1. 10월 랭킹 레이스

| 칸 | 값 |
|---|---|
| 참조 이름 | Leaderboard 2026-10 |
| 배지 | 경쟁 (Competition) |
| 이벤트 목적 | 신규 사용자 유치 |
| 우선순위 | 보통 |
| 그림 | `leaderboard_card.png` · `leaderboard_detail.png` |

**한국어**
- 이름: 10월 랭킹 레이스
- 짧은 설명: 이번 달 세계 순위, 어디까지 올라갈 수 있을까요
- 긴 설명: 월간 랭킹은 10월 31일에 마감돼요. 갤럭시·피구·프리킥에서 버틴 시간으로 세계·국가 순위를 겨뤄 보세요. 로그인하면 기록이 올라가요.

**English**
- 이름: October Leaderboard Climb
- 짧은 설명: Climb this month's world rankings in three zones
- 긴 설명: Monthly rankings close on Oct 31. Survive longer in Galaxy, Dodgeball and FreeKick to rise worldwide and at home.

**日本語**
- 이름: 10月ランキングレース
- 짧은 설명: 今月の世界ランキング、どこまで上がれる？
- 긴 설명: 月間ランキングは10月31日に締め切り。ギャラクシー・ドッジボール・フリーキックで耐えた時間で、世界と国別の順位を競おう。

**简体中文**
- 이름: 10月排行榜冲刺
- 짧은 설명: 本月世界排行榜，你能冲到第几名？
- 긴 설명: 月度排行榜于10月31日截止。在银河、躲避球、任意球中坚持更久，冲击世界和国家排名。

## 2. 할로윈 파티

| 칸 | 값 |
|---|---|
| 참조 이름 | Halloween 2026 |
| 배지 | 특별 이벤트 (Special Event) |
| 이벤트 목적 | 모든 사용자에게 적합 |
| 우선순위 | **높음** (기간 중 맨 앞) |
| 그림 | `halloween_card.png` · `halloween_detail.png` |

**한국어**
- 이름: 할로윈 파티
- 짧은 설명: 할로윈 선물로 코인 300과 불꽃 잔상을 받아 가세요
- 긴 설명: 10월 24일부터 11월 2일까지 이벤트 화면에서 할로윈 선물을 받으세요. 불꽃 잔상을 달고 탄막 사이를 누벼 보세요. 로그인하면 받을 수 있어요.

**English**
- 이름: Halloween Party
- 짧은 설명: Get 300 coins and a Flame trail for Halloween
- 긴 설명: From Oct 24 to Nov 2, claim your Halloween gift on the Events screen: 300 coins and a Flame trail. Sign in to claim.

**日本語**
- 이름: ハロウィンパーティー
- 짧은 설명: ハロウィンにコイン300と炎の軌跡をプレゼント
- 긴 설명: 10月24日〜11月2日、イベント画面でハロウィンギフトを受け取ろう。炎の軌跡をつけて弾幕をくぐり抜けよう。ログインで受け取れます。

**简体中文**
- 이름: 万圣节派对
- 짧은 설명: 万圣节送你300金币和火焰拖尾
- 긴 설명: 10月24日至11月2日，在活动页面领取万圣节礼物：300金币和火焰拖尾。登录即可领取。

## 3. 11월 랭킹 레이스

1번을 복제해서 아래만 바꾼다. 참조 이름 `Leaderboard 2026-11`.

**한국어**
- 이름: 11월 랭킹 레이스
- 짧은 설명: 이번 달 세계 순위, 어디까지 올라갈 수 있을까요
- 긴 설명: 월간 랭킹은 11월 30일에 마감돼요. 갤럭시·피구·프리킥에서 버틴 시간으로 세계·국가 순위를 겨뤄 보세요. 로그인하면 기록이 올라가요.

**English**
- 이름: November Leaderboard Climb
- 짧은 설명: Climb this month's world rankings in three zones
- 긴 설명: Monthly rankings close on Nov 30. Survive longer in Galaxy, Dodgeball and FreeKick to rise worldwide and at home.

**日本語**
- 이름: 11月ランキングレース
- 짧은 설명: 今月の世界ランキング、どこまで上がれる？
- 긴 설명: 月間ランキングは11月30日に締め切り。ギャラクシー・ドッジボール・フリーキックで耐えた時間で、世界と国別の順位を競おう。

**简体中文**
- 이름: 11月排行榜冲刺
- 짧은 설명: 本月世界排行榜，你能冲到第几名？
- 긴 설명: 月度排行榜于11月30日截止。在银河、躲避球、任意球中坚持更久，冲击世界和国家排名。

## 4. 연말 선물

| 칸 | 값 |
|---|---|
| 참조 이름 | Holiday 2026 |
| 배지 | 특별 이벤트 (Special Event) |
| 이벤트 목적 | 모든 사용자에게 적합 |
| 우선순위 | **높음** |
| 그림 | `holiday_card.png` · `holiday_detail.png` |

**한국어**
- 이름: 연말 선물
- 짧은 설명: 연말 선물로 코인 500과 눈송이 잔상을 받아 가세요
- 긴 설명: 12월 20일부터 1월 4일까지 이벤트 화면에서 연말 선물을 받으세요. 눈송이 잔상으로 새해 첫 기록에 도전해 보세요. 로그인하면 받을 수 있어요.

**English**
- 이름: Holiday Gift
- 짧은 설명: Get 500 coins and a Snow trail for the holidays
- 긴 설명: From Dec 20 to Jan 4, claim your holiday gift on the Events screen: 500 coins and a Snow trail. Sign in to claim.

**日本語**
- 이름: ホリデーギフト
- 짧은 설명: ホリデーにコイン500と雪の軌跡をプレゼント
- 긴 설명: 12月20日〜1月4日、イベント画面でホリデーギフトを受け取ろう。雪の軌跡で新年最初の記録に挑戦しよう。ログインで受け取れます。

**简体中文**
- 이름: 节日礼物
- 짧은 설명: 节日送你500金币和雪花拖尾
- 긴 설명: 12月20日至1月4日，在活动页面领取节日礼物：500金币和雪花拖尾。登录即可领取。

> 할로윈·연말은 "선물" 성격이라 반려될 수 있다 — 불꽃·눈송이 잔상은 상점에서 코인 350에 파는 아이템이라 "새 콘텐츠"로 보기엔 약하다.
> 반려되면 이유를 보고 고치되, 랭킹 레이스는 Apple 예시("June Leaderboard Climb")와 같은 꼴이라 그대로 간다.

---

## 피처링 추천 신청 (Featuring Nominations)

App Store Connect › 앱 › (사이드바) 피처링 › **추천** › ＋ › 추천 생성. 처음이면 "시작하기".
에디터 팀은 **최소 3주 전** 신청을 권한다 — 그래서 할로윈(12일 남음)이 아니라 **연말**로 낸다.
에디터 팀은 여러 나라 사람이라 설명은 영어로 쓴다. 설명 칸은 **1000자**, 도움이 되는 세부 정보는 **500자**라 영어만 넣었다(한국어는 참고용).

> 2026-10-12 **추천 1 을 초안으로 저장해 두었다**(설명·기간·플랫폼·참고 링크·세부 정보 · "새 인앱 이벤트를 제출할 계획" 체크). 연말 이벤트가 승인되면 추천에 붙이고 "피처링 요청 제출".

### 추천 1 — 연말 (새로운 콘텐츠)

| 칸 | 값 |
|---|---|
| 추천 이름 | ZONBER Holiday 2026 |
| 유형 | **새로운 콘텐츠** (New Content) |
| 게시 날짜 | 사용자 지정 기간 2026-12-20 ~ 2027-01-04 |
| 플랫폼 | iPhone · iPad |
| 국가 또는 지역 | 자동 선택 그대로(전체) — 한국 · 일본 · 미국을 우선으로 적고 싶으면 "도움이 되는 세부 정보"에 |
| 현지화 | 자동 선택 그대로(한국어 · 영어 · 일본어 · 중국어 간체) |
| 인앱 이벤트 | **연말 선물**(Holiday 2026) — 승인돼야 붙일 수 있다. 그 전엔 "이 피처링 요청에 대해 새로운 앱 내 이벤트를 제출할 계획입니까?"를 체크 |
| 보조 자료 | App Store 페이지 `https://apps.apple.com/app/id6757195275` |

**설명 (English)**

ZONBER is a one-finger survival arcade: drag your character through a tight zone and dodge everything thrown at you for as long as you can. Version 2.0 rebuilt the game around three zones that each play differently — Galaxy (classic bullet hell in deep space), Dodgeball (turn-based throws that split and speed up) and FreeKick (guard the box against curlers and knuckleballs) — with weekly, monthly and yearly rankings worldwide and by country.

For the holidays (Dec 20 – Jan 4) every signed-in player can claim a Holiday Gift: 500 coins and the Snow trail, six-pointed snowflakes that spin behind your character as it weaves through the bullets. It is a good moment to start: the yearly rankings reset on Jan 1, so new players can race for the first spots of 2027 alongside everyone else.

The game is free with ads, has no pay-to-win items (coins only buy cosmetics, rankings are pure skill), and is fully localized in Korean, English, Japanese and Simplified Chinese.

**설명 (한국어)**

ZONBER는 손가락 하나로 좁은 존 안을 움직이며 쏟아지는 공을 끝까지 피하는 생존 아케이드입니다. 2.0 에서 세 존으로 새로 만들었습니다 — 갤럭시(우주 탄막), 피구(턴마다 던지고, 갈라지고, 빨라지는 공), 프리킥(감아차기·무회전을 막는 골문 지키기). 주간·월간·연간 랭킹을 세계·나라별로 겨룹니다.

연말(12/20~1/4)에는 로그인한 플레이어는 누구나 연말 선물로 코인 500과 눈송이 잔상(캐릭터 뒤로 도는 눈 결정)을 받습니다. 1월 1일에 연간 랭킹이 새로 시작해서, 처음 온 사람도 2027년 첫 순위를 다 같이 겨룰 수 있는 때입니다.

무료(광고 포함)이고, 코인은 꾸미기에만 써서 랭킹은 순수 실력 경쟁입니다. 한국어·영어·일본어·중국어 간체를 모두 지원합니다.

**도움이 되는 세부 정보**

Indie game made by a solo developer in Korea. One-finger drag control with no reading required to play, and playable instantly without an account (sign-in is only needed to post records). The Holiday Gift in-app event (Dec 20 - Jan 4) is submitted for review alongside this nomination. Priority markets: Korea, Japan, United States.

### 추천 2 — 2.0 큰 업데이트 (앱 개선) · 선택

다음 iOS 빌드(지원 언어 수정이 들어간 것)를 낼 때 같이 낸다.

| 칸 | 값 |
|---|---|
| 추천 이름 | ZONBER 2.0 — Three Zones & Friends |
| 유형 | **앱 개선** (App Enhancements) |
| 게시 날짜 | 사용자 지정 기간 2026-11-02 ~ 2026-11-30 |
| 인앱 이벤트 | 11월 랭킹 레이스 |

**설명 (English)**

ZONBER 2.0 is a full rebuild of our one-finger survival arcade. Three zones now play differently: Galaxy (bullet hell in deep space), Dodgeball (turn-based throws that split and speed up) and FreeKick (guard the box against curlers, rockets and knuckleballs). Difficulty rises in the same 15 steps in every zone, and the HUD shows how far you are from the next world target (TOP 100 → 30 → 10 → #1) while you play.

New social features: add friends with a short friend code, compare zone records in a friends leaderboard, and get a notification when a friend beats your time. Results can be shared as an image card with your world rank. 46 badges, 8 characters and 80+ cosmetics (all earned with in-game coins — no pay-to-win). Fully localized in Korean, English, Japanese and Simplified Chinese.

**설명 (한국어)**

ZONBER 2.0 은 손가락 하나 생존 아케이드를 처음부터 다시 만든 업데이트입니다. 세 존이 서로 다르게 플레이됩니다 — 갤럭시(우주 탄막), 피구(턴마다 던지고 갈라지고 빨라지는 공), 프리킥(감아차기·총알슛·무회전을 막는 골문). 난이도는 세 존 모두 같은 15단계로 오르고, 플레이 중에 다음 세계 목표(TOP 100 → 30 → 10 → 1위)까지 남은 시간을 보여 줍니다.

친구 코드로 친구 추가, 존별 친구 랭킹, 친구가 내 기록을 넘으면 알림, 세계 순위가 담긴 결과 카드 공유가 새로 들어갔습니다. 뱃지 46종, 캐릭터 8종, 꾸미기 80종 이상(모두 게임 코인으로 — 과금으로 이기는 요소 없음). 한국어·영어·일본어·중국어 간체를 모두 지원합니다.
