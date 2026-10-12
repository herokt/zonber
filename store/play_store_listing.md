# ZONBER — Google Play 스토어 등록 정보 (2.1.0)

Play Console › 성장 › 스토어 등록정보 › 기본 스토어 등록정보(언어별 번역 추가)에 붙여 넣는다. 괄호 안은 글자 수 제한.
App Store 문구(`app_store_listing.md`)를 Play 칸에 맞춰 옮긴 것 — Play 에는 부제·프로모션 텍스트·키워드 칸이 없고
**간단한 설명(80)** 이 있다. Android 는 Apple 로그인이 없으므로 로그인 문구는 Google 만 적는다.
언어 코드: 한국어 `ko-KR` · 영어 `en-US` · 일본어 `ja-JP` · 중국어 간체 `zh-CN`.

**검색(ASO) 원칙 (2026-09-29)** — Play 는 키워드 칸이 없고 **앱 이름 · 간단한 설명 · 자세한 설명**을 검색에 쓴다.
이름에 `ZONBER: <핵심 키워드>` 를 붙이고, 간단한 설명 첫머리에 같은 핵심어를 한 번 더 둔다.
Play 정책상 이름·간단한 설명에는 "무료·1위·할인·선물" 같은 홍보 문구를 넣지 않는다 — 이벤트 소개는 자세한 설명과 출시 노트에만.

**그래픽 규격**
| 항목 | 규격 | 파일 |
|---|---|---|
| 앱 아이콘 | 512×512 PNG(32비트, 알파 가능) | `store/play_icon_512.png` |
| 그래픽 이미지 | 1024×500 JPG/PNG(알파 없음) · 언어별 | `store/feature_graphic/{ko,en,ja,zh}.png` — `node scripts/make_feature_graphic.mjs` (아이콘 · ZONBER · 한 줄 문구 + 세 존 경기장 카드) |
| 휴대전화 스크린샷 | 2~8장 · 9:16 · 1080×1920 이상 권장(긴 변 ≤ 짧은 변 × 2) | `store/screenshots_play/{ko,en,ja,zh}/phone/` 8장 (`index.html` 로 한눈에 보기 · App Store 10장 중 뱃지·홈 뺌) |
| 태블릿 스크린샷(선택) | 7·10인치 · 긴 변 ≤ 짧은 변 × 2 | iPad 이미지 `store/screenshots/{lang}/ipad/`(2064×2752)가 규격에 맞는다 |

> 휴대전화 스크린샷은 실제 기기(Galaxy S24+)에서 **스크린샷 모드**로 찍어 합성한다(2026-09-30, 2.0.3 화면 — App Store 이미지와 같은 원본·문구).
> 랭킹·세계 신기록은 가짜 기록(실제 유저 닉네임이 나오지 않게), 판은 공이 많은 순간에서 멈춘 모습이다.
> ```
> flutter build apk --release --dart-define=STORE_SHOT=true   # 스크린샷 모드 (lib/store_shot.dart)
> adb -s <기기> install -r build/app/outputs/flutter-apk/app-release.apk
> bash scripts/store_shots.sh <기기>        # 언어 4 × 화면 6 캡처 → build/store_shots/
> node scripts/compose_store_shots.mjs      # 문구·틀 합성 → store/screenshots_play/
> ```
> 끝나면 보통 빌드를 다시 설치한다(스크린샷 모드 앱은 저절로 화면을 넘긴다). 문구·배경색은 `compose_store_shots.mjs` 안에 있다.
> 그래픽 이미지는 같은 원본(한국어 캡처)의 경기장만 잘라 만든다 — 캡처를 다시 하면 `make_feature_graphic.mjs` 도 다시 돌린다.

---

## 한국어 (ko-KR)

### 앱 이름 (30)
ZONBER: 탄막 피하기 생존게임

### 간단한 설명 (80)
탄막 피하기 생존게임! 갤럭시·피구·프리킥, 손가락 하나로 피하고 막아 끝까지 버텨라

### 자세한 설명 (4000)
좁은 존 안에서 쏟아지는 공을 피하며 최대한 오래 버티세요.
손가락 하나로 끌면 존버가 그대로 따라 움직입니다. 조작은 그게 전부인데, 버틴 시간은 1초, 1초가 소중해집니다.

■ 3개의 존, 3가지 생존법
• 갤럭시 — 깊은 우주, 크고 작은 운석이 사방에서 쏟아집니다. 오리지널 ZONBER.
• 피구 — 상대 코트에서 한 턴에 한 번, 나를 향해 던집니다. 공이 갈라지고, 나란히 오고, 점점 빨라집니다.
• 프리킥 — 페널티 박스를 지키며 슛을 막으세요. 감아차기, 총알슛, 무회전까지 날아옵니다.

■ 세계와 겨루는 랭킹
• 주간·월간·연간 랭킹, 세계와 나라별 순위
• 다음 목표(TOP 100 → 30 → 10 → 1위)까지 남은 시간을 플레이 중에 바로 확인
• 랭킹에서 다른 플레이어를 누르면 프로필과 기록을 볼 수 있습니다

■ 나만의 존버 꾸미기
• 펫 6종 — 캐릭터 둘레를 돌며 날아오는 탄과 공을 바깥으로 쳐내 줍니다
• 캐릭터 8종, 몸통 스킨 14종, 이동 잔상 12종, 오라 12종
• 존마다 다른 장비 63종 — 비쌀수록 능력치(속도·무적·회복·막는 범위·코인)가 높아집니다
• 버틴 시간만큼 코인이 쌓입니다

■ 뱃지·미션
• 뱃지 46종 — 생존, 기술, 랭킹, 수집, 출석까지
• 매일 바뀌는 오늘의 미션과 출석 보상

■ 친구와 겨루기
• 판이 끝나면 기록과 세계 순위를 바로 자랑 — 카톡·인스타로 도전장을 보내세요
• 친구 코드를 입력하면 친구와 나 모두 코인 200
• 처음 오면 환영 선물(코인 300 + 구름 스킨), SNS 이벤트 코드로 추가 보상

■ 가볍게 시작
• 로그인 없이 바로 플레이할 수 있습니다
• 기록을 랭킹에 올리고 코인·뱃지를 모으려면 Google로 로그인하세요
• 한국어, English, 日本語, 中文 지원

오늘 기록, 어제보다 1초만 더 버텨 보세요.

### 출시 노트 (500)
ZONBER 2.1.0
• 펫 6종 등장 — 캐릭터 둘레를 돌며 탄과 공을 바깥으로 쳐내 줘요
• 갤럭시가 운석 지대로 — 크기가 다른 운석 4종
• 피구·골키퍼 상대 팀과 공, 스테이지 배너를 새로 그렸어요
• 장비·꾸미기 대부분에 능력치, 새 아이템 추가
• 게임 오버 연출·로딩 화면이 부드러워졌어요
• 새 버전이 나오면 앱에서 알려 드려요

---

## English (en-US)

### App name (30)
ZONBER: Dodge & Survive

### Short description (80)
Dodge & survive! Galaxy, Dodgeball, FreeKick — a one-finger bullet hell arcade

### Full description (4000)
Stay inside a tight zone, dodge everything thrown at you, and survive as long as you can.
Drag with one finger and your Zonber follows exactly. That's the whole control scheme — and every extra second counts.

■ 3 ZONES, 3 WAYS TO SURVIVE
• Galaxy — Deep space, meteors big and small from every side. The original ZONBER.
• Dodgeball — One throw a turn, right at you. Balls split, line up and get faster.
• FreeKick — Guard the penalty box and stop the shots: curlers, rockets and knuckleballs.

■ BEAT THE WORLD
• Weekly, monthly and yearly rankings — worldwide and by country
• See how far you are from the next target (TOP 100 → 30 → 10 → #1) while you play
• Tap any player in the rankings to see their profile and records

■ DRESS UP YOUR ZONBER
• 6 pets that orbit your Zonber and knock incoming bullets and balls away
• 8 characters, 14 body skins, 12 trails and 12 auras
• 63 pieces of gear for each zone — pricier gear gives bigger stats (speed, invincibility, recovery, reach, coins)
• Earn coins for every second you survive

■ BADGES & MISSIONS
• 46 badges for survival, skill, rankings, collecting and check-ins
• New daily missions and check-in rewards every day

■ CHALLENGE YOUR FRIENDS
• Brag your time and world rank the moment a run ends — send a challenge to any chat app
• Enter a friend's code and you both get 200 coins
• Welcome gift for new players (300 coins + Cloud skin), plus bonus codes on our socials

■ JUMP RIGHT IN
• Play instantly — no login needed
• Sign in with Google to post your records and keep your coins and badges
• Available in English, 한국어, 日本語 and 中文

Beat yesterday by just one more second.

### Release notes (500)
ZONBER 2.1.0
• 6 pets that orbit you and knock bullets and balls away
• Galaxy is now a meteor field — 4 meteor sizes
• New art for rival teams, balls and stage banners
• Most gear and cosmetics now have stats, plus new items
• Smoother game-over and loading screens
• The app tells you when a new version is out

---

## 日本語 (ja-JP)

### アプリ名 (30)
ZONBER: 弾幕よけサバイバル

### 簡単な説明 (80)
弾幕よけサバイバル！ギャラクシー・ドッジボール・フリーキックを指1本で耐え抜け

### 詳しい説明 (4000)
狭いゾーンの中で、飛んでくるすべてをかわし、できるだけ長く生き残ろう。
指1本でドラッグすれば、ZONBERがそのままついてくる。操作はそれだけ。だからこそ、1秒1秒が大切になる。

■ 3つのゾーン、3つの生き残り方
• ギャラクシー — 深い宇宙、大小の隕石が四方から降りそそぐ。オリジナルのZONBER。
• ドッジボール — 相手コートから1ターンに1球、まっすぐあなたへ。分裂し、並んで飛び、どんどん速くなる。
• フリーキック — ペナルティエリアを守ってシュートを止めろ。カーブ、ロケット、そして無回転。

■ 世界と競うランキング
• 週間・月間・年間ランキング、世界と国別の順位
• 次の目標（TOP 100 → 30 → 10 → 1位）までの残り時間をプレイ中に確認
• ランキングでプレイヤーをタップすると、プロフィールと記録が見られる

■ 自分だけのZONBERに
• ペット6種 — キャラのまわりを回って、飛んでくる弾やボールを外へはじく
• キャラクター8種、ボディスキン14種、トレイル12種、オーラ12種
• ゾーンごとの装備63種 — 高いほど能力値（速さ・無敵・回復・守備範囲・コイン）がアップ
• 生き残った時間に応じてコインが貯まる

■ バッジとミッション
• バッジ46種 — 生存、テクニック、ランキング、コレクション、出席まで
• 毎日の「今日のミッション」と出席ボーナス

■ 友だちと勝負
• 1プレイ終わったら記録と世界順位をすぐ自慢 — メッセージアプリで挑戦状を送ろう
• フレンドコードを入力すると、自分も友だちもコイン200
• はじめての方に歓迎ギフト（コイン300 + くもスキン）、SNSのイベントコードでさらに報酬

■ 気軽にスタート
• ログインなしですぐにプレイ
• 記録をランキングに載せ、コインやバッジを貯めるにはGoogleでログイン
• English、한국어、日本語、中文に対応

昨日より、あと1秒だけ長く。

### リリースノート (500)
ZONBER 2.1.0
• ペット6種登場 — まわりを回って弾やボールを外へはじく
• ギャラクシーが隕石ゾーンに — 大きさの違う隕石4種
• 相手チーム・ボール・ステージバナーを描き直し
• 装備・着せ替えの多くに能力値、新アイテム追加
• ゲームオーバー演出とロード画面がなめらかに
• 新バージョンが出たらアプリでお知らせ

---

## 简体中文 (zh-CN)

### 应用名称 (30)
ZONBER：躲弹幕生存挑战

### 简短说明 (80)
躲弹幕生存挑战！银河、躲避球、任意球，一根手指闪避扑救，坚持到最后

### 完整说明 (4000)
待在狭小的区域里，躲开飞来的一切，尽可能坚持得更久。
一根手指拖动，ZONBER 就会紧紧跟随。操作只有这么简单——正因如此，每多坚持一秒都弥足珍贵。

■ 三个区域，三种生存方式
• 银河 — 深空之中，大大小小的陨石四面袭来。原版 ZONBER。
• 躲避球 — 对手每回合一球，直冲你来。球会分裂、并排飞来，而且越来越快。
• 任意球 — 守住禁区，挡住射门：弧线球、火箭球，还有电梯球。

■ 挑战全世界
• 周榜、月榜、年榜，全球与国家排名
• 游戏中随时查看距离下一个目标（TOP 100 → 30 → 10 → 第1名）还差多少
• 在排行榜中点击玩家，即可查看其资料与记录

■ 打造你的 ZONBER
• 6种宠物——围着角色转圈，把飞来的子弹和球弹开
• 8个角色、14款身体皮肤、12种拖尾、12种光环
• 每个区域专属装备63件——越贵属性越高（速度、无敌、回复、守备范围、金币）
• 坚持越久，金币越多

■ 徽章与任务
• 46枚徽章——生存、技巧、排名、收集、签到
• 每日刷新的今日任务与签到奖励

■ 和好友一较高下
• 每局结束立即炫耀成绩与全球排名——一键向好友发起挑战
• 输入好友代码，你和好友各得 200 金币
• 新玩家欢迎礼（300 金币 + 云朵皮肤），社媒兑换码还有额外奖励

■ 轻松开始
• 无需登录，立即开玩
• 使用 Google 登录，即可上传排名记录并保存金币和徽章
• 支持 English、한국어、日本語、中文

今天，比昨天多坚持一秒。

### 版本说明 (500)
ZONBER 2.1.0
• 6种宠物登场——围着你转圈，把子弹和球弹开
• 银河变成陨石带——4种大小的陨石
• 重新绘制对手队伍、球和关卡横幅
• 大部分装备和装扮都有属性，新增道具
• 游戏结束动画和加载画面更流畅
• 有新版本时会在应用内提醒你