# ZONBER — Google Play 스토어 등록 정보 (2.0.0)

Play Console › 성장 › 스토어 등록정보 › 기본 스토어 등록정보(언어별 번역 추가)에 붙여 넣는다. 괄호 안은 글자 수 제한.
App Store 문구(`app_store_listing.md`)를 Play 칸에 맞춰 옮긴 것 — Play 에는 부제·프로모션 텍스트·키워드 칸이 없고
**간단한 설명(80)** 이 있다. Android 는 Apple 로그인이 없으므로 로그인 문구는 Google 만 적는다.
언어 코드: 한국어 `ko-KR` · 영어 `en-US` · 일본어 `ja-JP` · 중국어 간체 `zh-CN`.

**그래픽 규격**
| 항목 | 규격 | 파일 |
|---|---|---|
| 앱 아이콘 | 512×512 PNG(32비트, 알파 가능) | `store/play_icon_512.png` |
| 그래픽 이미지 | 1024×500 JPG/PNG(알파 없음) · 언어별 | `store/feature_graphic/{ko,en,ja,zh}.png` — `node scripts/make_feature_graphic.mjs` (아이콘 · ZONBER · 한 줄 문구 + 세 존 경기장 카드) |
| 휴대전화 스크린샷 | 2~8장 · 9:16 · 1080×1920 이상 권장(긴 변 ≤ 짧은 변 × 2) | `store/screenshots_play/{ko,en,ja,zh}/phone/` 6장 (`index.html` 로 한눈에 보기) |
| 태블릿 스크린샷(선택) | 7·10인치 · 긴 변 ≤ 짧은 변 × 2 | iPad 이미지 `store/screenshots/{lang}/ipad/`(2064×2752)가 규격에 맞는다 |

> 휴대전화 스크린샷은 실제 기기(Galaxy S24+)에서 **스크린샷 모드**로 찍어 합성한다(2026-09-24, 2.0.0 화면).
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
ZONBER

### 간단한 설명 (80)
좁은 존에서 끝까지 버텨라! 갤럭시·피구·프리킥, 손가락 하나로 피하고 막는 생존 게임

### 자세한 설명 (4000)
좁은 존 안에서 쏟아지는 공을 피하며 최대한 오래 버티세요.
손가락 하나로 끌면 존버가 그대로 따라 움직입니다. 조작은 그게 전부인데, 버틴 시간은 1초, 1초가 소중해집니다.

■ 3개의 존, 3가지 생존법
• 갤럭시 — 깊은 우주, 사방에서 탄막이 쏟아집니다. 오리지널 ZONBER.
• 피구 — 상대 코트에서 한 턴에 한 번, 나를 향해 던집니다. 공이 갈라지고, 나란히 오고, 점점 빨라집니다.
• 프리킥 — 페널티 박스를 지키며 슛을 막으세요. 감아차기, 총알슛, 무회전까지 날아옵니다.

■ 세계와 겨루는 랭킹
• 주간·월간·연간 랭킹, 세계와 나라별 순위
• 다음 목표(TOP 100 → 30 → 10 → 1위)까지 남은 시간을 플레이 중에 바로 확인
• 랭킹에서 다른 플레이어를 누르면 프로필과 기록을 볼 수 있습니다

■ 나만의 존버 꾸미기
• 캐릭터 8종, 몸통 스킨 12종, 이동 잔상 10종, 오라 10종
• 존마다 다른 장비 53종 — 미리 입어 보고 고르세요
• 버틴 시간만큼 코인이 쌓입니다

■ 뱃지·미션
• 뱃지 46종 — 생존, 기술, 랭킹, 수집, 출석까지
• 매일 바뀌는 오늘의 미션과 출석 보상

■ 가볍게 시작
• 로그인 없이 바로 플레이할 수 있습니다
• 기록을 랭킹에 올리고 코인·뱃지를 모으려면 Google로 로그인하세요
• 한국어, English, 日本語, 中文 지원

오늘 기록, 어제보다 1초만 더 버텨 보세요.

### 출시 노트 (500)
ZONBER 2.0 — 완전히 새로워졌습니다.
• 3개의 존: 갤럭시 · 피구 · 프리킥
• 캐릭터 8종과 몸통 스킨·잔상·오라·존별 장비
• 뱃지 46종, 오늘의 미션과 출석 보상
• 주간·월간·연간 세계/나라별 랭킹
• 로그인 없이 바로 플레이

---

## English (en-US)

### App name (30)
ZONBER

### Short description (80)
Dodge & block with one finger in 3 zones: Galaxy, Dodgeball, FreeKick. Survive!

### Full description (4000)
Stay inside a tight zone, dodge everything thrown at you, and survive as long as you can.
Drag with one finger and your Zonber follows exactly. That's the whole control scheme — and every extra second counts.

■ 3 ZONES, 3 WAYS TO SURVIVE
• Galaxy — Deep space, bullets from every side. The original ZONBER.
• Dodgeball — One throw a turn, right at you. Balls split, line up and get faster.
• FreeKick — Guard the penalty box and stop the shots: curlers, rockets and knuckleballs.

■ BEAT THE WORLD
• Weekly, monthly and yearly rankings — worldwide and by country
• See how far you are from the next target (TOP 100 → 30 → 10 → #1) while you play
• Tap any player in the rankings to see their profile and records

■ DRESS UP YOUR ZONBER
• 8 characters, 12 body skins, 10 trails and 10 auras
• 53 pieces of gear made for each zone — try them on before you pick
• Earn coins for every second you survive

■ BADGES & MISSIONS
• 46 badges for survival, skill, rankings, collecting and check-ins
• New daily missions and check-in rewards every day

■ JUMP RIGHT IN
• Play instantly — no login needed
• Sign in with Google to post your records and keep your coins and badges
• Available in English, 한국어, 日本語 and 中文

Beat yesterday by just one more second.

### Release notes (500)
ZONBER 2.0 — rebuilt from the ground up.
• 3 zones: Galaxy, Dodgeball and FreeKick
• 8 characters plus body skins, trails, auras and gear for each zone
• 46 badges, daily missions and check-in rewards
• Weekly, monthly and yearly rankings — worldwide and by country
• Play instantly, no login needed

---

## 日本語 (ja-JP)

### アプリ名 (30)
ZONBER

### 簡単な説明 (80)
ギャラクシー・ドッジボール・フリーキック、3つのゾーンで指1本サバイバル！どこまで耐えられる？

### 詳しい説明 (4000)
狭いゾーンの中で、飛んでくるすべてをかわし、できるだけ長く生き残ろう。
指1本でドラッグすれば、ZONBERがそのままついてくる。操作はそれだけ。だからこそ、1秒1秒が大切になる。

■ 3つのゾーン、3つの生き残り方
• ギャラクシー — 深い宇宙、四方から弾幕が降りそそぐ。オリジナルのZONBER。
• ドッジボール — 相手コートから1ターンに1球、まっすぐあなたへ。分裂し、並んで飛び、どんどん速くなる。
• フリーキック — ペナルティエリアを守ってシュートを止めろ。カーブ、ロケット、そして無回転。

■ 世界と競うランキング
• 週間・月間・年間ランキング、世界と国別の順位
• 次の目標（TOP 100 → 30 → 10 → 1位）までの残り時間をプレイ中に確認
• ランキングでプレイヤーをタップすると、プロフィールと記録が見られる

■ 自分だけのZONBERに
• キャラクター8種、ボディスキン12種、トレイル10種、オーラ10種
• ゾーンごとの装備53種 — 試着してから選べる
• 生き残った時間に応じてコインが貯まる

■ バッジとミッション
• バッジ46種 — 生存、テクニック、ランキング、コレクション、出席まで
• 毎日の「今日のミッション」と出席ボーナス

■ 気軽にスタート
• ログインなしですぐにプレイ
• 記録をランキングに載せ、コインやバッジを貯めるにはGoogleでログイン
• English、한국어、日本語、中文に対応

昨日より、あと1秒だけ長く。

### リリースノート (500)
ZONBER 2.0 — すべてが新しくなりました。
• 3つのゾーン：ギャラクシー・ドッジボール・フリーキック
• キャラクター8種、ボディスキン・トレイル・オーラ・ゾーン別の装備
• バッジ46種、今日のミッションと出席ボーナス
• 週間・月間・年間ランキング（世界・国別）
• ログインなしですぐにプレイ

---

## 简体中文 (zh-CN)

### 应用名称 (30)
ZONBER

### 简短说明 (80)
银河、躲避球、任意球——三个区域，一根手指闪避与扑救，看你能坚持多久！

### 完整说明 (4000)
待在狭小的区域里，躲开飞来的一切，尽可能坚持得更久。
一根手指拖动，ZONBER 就会紧紧跟随。操作只有这么简单——正因如此，每多坚持一秒都弥足珍贵。

■ 三个区域，三种生存方式
• 银河 — 深空之中，弹幕四面袭来。原版 ZONBER。
• 躲避球 — 对手每回合一球，直冲你来。球会分裂、并排飞来，而且越来越快。
• 任意球 — 守住禁区，挡住射门：弧线球、火箭球，还有电梯球。

■ 挑战全世界
• 周榜、月榜、年榜，全球与国家排名
• 游戏中随时查看距离下一个目标（TOP 100 → 30 → 10 → 第1名）还差多少
• 在排行榜中点击玩家，即可查看其资料与记录

■ 打造你的 ZONBER
• 8个角色、12款身体皮肤、10种拖尾、10种光环
• 每个区域专属装备53件——先试穿再选择
• 坚持越久，金币越多

■ 徽章与任务
• 46枚徽章——生存、技巧、排名、收集、签到
• 每日刷新的今日任务与签到奖励

■ 轻松开始
• 无需登录，立即开玩
• 使用 Google 登录，即可上传排名记录并保存金币和徽章
• 支持 English、한국어、日本語、中文

今天，比昨天多坚持一秒。

### 版本说明 (500)
ZONBER 2.0 — 全面焕新。
• 3个区域：银河、躲避球、任意球
• 8个角色，以及身体皮肤、拖尾、光环和各区域专属装备
• 46枚徽章、今日任务与签到奖励
• 周榜、月榜、年榜——全球与国家排名
• 无需登录，立即开玩
