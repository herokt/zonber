# 존 배경 아트 브리프 — v1.0 (2026-09-18)

> 게임 무대 배경 3장(+ 홈 카드 히어로 3장)의 컨셉과 제작 규칙. 이미지는 외부에서 따로 뽑아 온다.
> 결과물은 `assets/images/worlds/` 에 **아래 파일명 그대로** 덮어쓰면 코드 수정 없이 들어간다. 목록 전체는 [RESOURCES.md](RESOURCES.md).

## 0. 모든 배경의 공통 규칙

**배경은 무대이지 주인공이 아니다.** 플레이어가 0.1초 안에 공과 그림자를 읽어야 하므로, 배경은 조용해야 한다.

| 항목 | 규칙 | 이유 |
|---|---|---|
| 규격 | **960×1536 PNG** (5:8, 480×768 무대의 @2x). 같은 비율이면 더 커도 된다 | 코드가 무대 크기(480×768)에 맞춰 늘려 그린다 |
| 시점 | **완전한 탑다운(정수리 시점)**, 원근·소실점 없음 | 공과 플레이어가 평면에서 움직인다 |
| 대비 | 명도 차를 작게. 무늬는 바닥색 ±10~15% 안쪽 | 공·그림자·플레이어가 떠 보여야 한다 |
| 중앙 | 가운데 320×320(@2x) 안은 가장 비워 둔다 | 플레이어 시작 위치이고 시선이 머무는 곳 |
| 가장자리 | 네 변 가장자리 120px 안에 **공과 비슷한 원형 무늬 금지** | 공이 가장자리 바깥에서 들어온다. 비슷한 무늬가 있으면 공으로 착각한다 (진입 그림자 예고는 2026-09-18 제거) |
| 금지 색 | 그 존의 공 색(아래 표)과 같은 계열의 점·원 | 공으로 오인 |
| 테두리 | 배경에 굵은 외곽 테두리를 그리지 않는다 | 코드가 존 라인 색으로 무대 경계를 그린다 |
| 글자·로고 | 없음 | 현지화·가독성 |
| 조명 | 고르게. 비네트(가장자리 어둡게)는 아주 약하게만 | 가장자리로 들어오는 공이 묻힌다 |
| 반복감 | 타일처럼 보여도 괜찮다. 단 모아레(촘촘한 줄무늬) 금지 | 작은 화면에서 깜빡여 보인다 |

코드가 배경 **위에** 그리는 것: 무대 테두리, 공, 플레이어(캐릭터), Goalkeeper 골대. 배경에 이것들을 그려 넣지 않는다.

---

## ZONE 1 · Galaxy / 갤럭시 — `cyber_bg.png`

**한 줄:** 은하 한가운데 떠 있는 작은 관측 플랫폼. 사방의 어둠에서 탄이 쏟아진다.

- **바닥색:** 짙은 남색 `#141A33` 기준 (현재 코드 바닥색과 맞춤)
- **요소**
  - 아주 옅은 성운 두 덩어리 — 청록(`#0A9DBD` 계열)과 보라(`#5B4BB7` 계열), 채도 낮게, 모서리 쪽으로 흐르듯
  - 작은 별 — 흰색·옅은 청색만, 1~3px, 밀도는 낮게
  - **중심을 둘러싼 동심원 궤도선 2~3개** — 가는 선, 투명도 10~15%. 탄이 원형으로 둘러싸 오는 게임 구조와 맞물린다
  - 중앙은 살짝 밝은 원형 "플랫폼" 느낌(바닥보다 5% 밝게) — 선이나 테두리 없이 그라데이션만
- **피할 것:** 빨간 별·주황 성운(탄 색 `#D32F2F`), 밝은 행성·큰 천체(시선 분산), 은하 나선의 강한 밝기
- **분위기 키워드:** 고요함, 깊이, 차가운 네온

**생성 프롬프트 (EN)**
```
Top-down 2D game arena background, portrait 5:8, deep navy space (#141A33),
very faint teal and violet nebula wisps drifting toward the corners, sparse tiny white
and pale-blue stars, two or three thin concentric orbit rings around the center at 10-15% opacity,
a subtle slightly brighter circular platform glow in the center, flat even lighting, low contrast,
minimalist, clean mobile game style, no planets, no red or orange, no text, no border, no vignette
```

---

## ZONE 2 · Dodgeball / 피구 — `dodgeball_bg.png`

**한 줄:** 햇살 드는 학교 체육관 마루. 코트 밖 네 변에서 공이 날아온다.

- **바닥색:** 밝은 원목 `#E9CFA6` 기준
- **요소**
  - 원목 마루 널판 — 세로 방향, 결은 약하게, 널판 경계선은 아주 옅게
  - 흰색 코트 라인 — 바깥 경계선(가장자리에서 안쪽 40px), **가로 중앙선 1개**, 중앙선 위아래 공격선 2개. 선 굵기 6~8px(@2x), 불투명도 70%
  - 중앙 원(지름 약 240px) 흰 선
  - 코트 안쪽 두 진영을 아주 옅은 파랑(`#7FA7D9` 15%)·민트(`#8FD1B5` 15%)로 칠해도 좋다 — 선택
- **피할 것:** 빨강·노랑 칠(공 색 `#FF5A4E`/`#F5C542`), 농구 골대 원·자유투 반원 같은 다른 종목 표시, 짙은 얼룩·신발 자국
- **분위기 키워드:** 밝음, 경쾌함, 방과 후 체육 시간

**생성 프롬프트 (EN)**
```
Top-down 2D game background of an indoor school gym floor, portrait 5:8, light natural wood
parquet (#E9CFA6) with vertical planks and very subtle grain, crisp white dodgeball court lines:
outer boundary inset from the edges, one horizontal center line, two attack lines, a center circle,
optional very faint pale-blue and mint tint on each half, flat even daylight, low contrast,
clean minimalist mobile game style, no red, no yellow, no basketball markings, no people, no text
```

---

## ZONE 3 · Goalkeeper / 골키퍼 — `keeper_bg.png` (2026-09-21 페널티킥형으로 교체 필요)

**한 줄:** 골문 앞 페널티 지역. 위쪽 필드에서 슈터들이 차고, 아래 골문을 지킨다.

> 현재 배경은 옛 "가운데 원형 골대" 기준이라 **가운데 큰 흰 원**이 필드를 가로지른다. 아래 규칙으로 다시 뽑아야 한다.

- **바닥색:** 밝은 잔디 `#A8DC8F` 기준, 가로 줄무늬 8~10개(두 톤 차 5%)
- **그리지 말 것(코드가 그림):** 골문·그물·골포스트, 페널티 박스·골 에어리어·페널티 아크 라인, 슈터
- **그려도 되는 것:** 잔디 줄무늬만. 원한다면 맨 위쪽에 하프라인 일부(가로선) 정도
- **피할 것:** 가운데 원(센터 서클), 흰 점·공 모양, 관중석, 코트 라인 전반
- **분위기 키워드:** 상쾌함, 페널티킥 직전의 긴장

**생성 프롬프트 (EN)**
```
Top-down 2D game background of a soccer pitch lawn, portrait 5:8, fresh light green grass (#A8DC8F)
with soft horizontal mowing stripes (two tones about 5% apart), completely plain otherwise:
no center circle, no lines, no goals, no penalty box, no balls, no white dots, no people, no text,
flat even lighting, low contrast, clean minimalist mobile game style
```

---

## 홈 카드 히어로 3장 — `{id}_hero.png` (v2, 2026-09-23)

홈 화면 존 카드의 윗부분. **한 장을 기기 비율에 따라 길게·짧게 잘라 쓴다**(`BoxFit.cover`).
코드가 이 이미지 위에 얹는 것: 왼쪽 위 `ZONE n` 칩뿐이다. 존 이름·설명·내 최고 기록은 이미지 **아래**에 따로 쓴다.

### 0. 이 그림이 말해야 하는 것

**ZONE = 내가 버티는 구역이다.** 존버(ZONBER)는 "이 구역에서 버티는 사람"이고, 게임은 한 구역 안에서
사방에서 오는 것을 피하거나 막으며 시간을 버티는 게임이다. 그래서 세 장 모두 같은 문장을 그림으로 말한다.

| 반드시 담을 것 | 그림에서 |
|---|---|
| **경계가 보이는 구역** | 바닥에 그 존의 경계(궤도 링 · 코트 라인 · 페널티 박스)가 또렷이 보인다 |
| **구역 한가운데의 나** | 캐릭터(민트 — 둥근 몸에 작은 손발) 하나가 구역 중앙 부근을 지키고 있다 |
| **바깥에서 들어오는 위협** | 그 존의 공/탄이 **화면 밖에서 구역 안으로** 날아온다. 궤적선 1~2개로 방향을 읽히게 |
| **버티는 중** | 폭발·승리 장면이 아니다. 맞기 직전의 긴장, 몸을 비튼 회피 자세 |

세 장은 같은 화풍·같은 캐릭터 크기·같은 조명이어야 한다. 카드를 좌우로 넘길 때 한 세계로 보여야 한다.

### 1. 기기 비율 대응 — 잘려도 되는 곳, 절대 안 되는 곳

카드 높이는 168dp로 고정이고 **폭은 기기마다 다르다**. 좁은 폰에서는 약 2:1, 큰 화면·펼친 폴드에서는 5:1 가까이
납작해진다. `cover`라서 **가로를 채우고 위아래가 잘린다.**

| 구분 | 값 | 규칙 |
|---|---|---|
| 납품 규격 | **1536×768 PNG (2:1)**, @2x | 가장 좁은 카드 비율과 같게 잡아 좌우는 거의 잘리지 않는다 |
| 필수 안전대 | 세로 **가운데 40%** (y 230~538) | 5:1로 잘려도 남는 곳. **캐릭터·공·경계선은 전부 여기 안에** |
| 넉넉 영역 | 세로 가운데 70% (y 115~653) | 2.5:1~3:1에서 보인다. 분위기 요소(성운·관중석·잔디결)용 |
| 잘려 나가는 곳 | 위아래 각 15% | 하늘·천장·먼 배경만. 여기 있는 것은 없어도 그림이 성립해야 한다 |
| 칩 자리 | 왼쪽 위 **280×120** | `ZONE n` 칩이 덮는다. 밝은 디테일·글자 금지, 배경만 |
| 좌우 끝 | 양쪽 각 5% | 아주 넓은 화면에서만 보인다. 배경이 끝까지 이어지게(테두리·액자 금지) |

**한 장으로 세 비율을 다 만족시키는 법**: 구도를 **가로로 길게, 세로로 얕게** 잡는다. 캐릭터는 중앙 높이에 두고,
위협은 좌우에서 수평에 가깝게 들어오게 한다. 위에서 아래로 떨어지는 구도는 잘리면 뜻이 사라진다.

### 2. 공통 화풍

- 평평한 2D 벡터 일러스트. 두꺼운 균일 외곽선(어두운 남색 `#1F2A44`), 완만한 그라데이션, 질감·노이즈 없음
- 3/4 부감(살짝 위에서 내려다봄) — 게임 무대의 완전 탑다운과 달리 카드에서는 공간감을 준다
- 조명은 고르게. 강한 그림자·빛 번짐 금지. 채도는 중간, 배경은 캐릭터보다 어둡거나 옅게
- 캐릭터: 민트색(`#3FBF97`) 둥근 몸, 작은 손발, 반쯤 감은 눈 — **화면 높이의 약 35%**
- 글자·로고·UI·워터마크 없음

### 3. 존별 프롬프트 (그대로 붙여 쓰기)

**ZONE 1 · Galaxy / 갤럭시 — `cyber_hero.png`**
> 우주에 떠 있는 원형 플랫폼이 내 구역이다. 사방의 어둠에서 네온 탄이 링을 그리며 좁혀 온다.

```
Wide 2:1 banner illustration for a mobile game card, flat 2D vector art with bold dark navy
outlines (#1F2A44). A round mint-green blob character (#3FBF97) with tiny hands and feet and
sleepy half-closed eyes stands at the center of a glowing circular platform floating in deep
navy space (#141A33). Two thin concentric orbit rings mark the edge of the platform — this is
his zone. Small cyan neon bullets (#0A9DBD) streak in from the left and right edges of the frame
toward him, each with one short motion trail. Faint teal and violet nebula wisps and sparse tiny
stars fill the background. Horizontal composition, character and all bullets kept inside the
middle 40% band of the image height, background extends to all four edges, even flat lighting,
calm and tense, clean minimal mobile game style, no text, no logo, no frame, no vignette
```

**ZONE 2 · Dodgeball / 피구 — `dodgeball_hero.png`**
> 코트 라인이 내 구역이다. 상대 코트에서 큰 공이 나를 조준해 날아온다.

```
Wide 2:1 banner illustration for a mobile game card, flat 2D vector art with bold dark navy
outlines (#1F2A44). A round mint-green blob character (#3FBF97) with tiny hands and feet leans
aside to dodge, standing inside a school gym court: light wooden floor (#E9CFA6) with crisp white
court lines and a center line marking his half — this is his zone. One large yellow dodgeball
(#FFC928) with a red seam band flies in from the upper left with a short motion trail, a second
orange ball (#FF7A1A) enters from the right edge. Bright indoor gym, faint bleachers far in the
background. Horizontal composition, character and both balls kept inside the middle 40% band of
the image height, background extends to all four edges, even flat lighting, clean minimal mobile
game style, no text, no logo, no frame, no vignette
```

**ZONE 3 · Goalkeeper / 골키퍼 — `keeper_hero.png`**
> 페널티 박스가 내 구역이다. 슛이 골문으로 오고, 나는 그 앞을 막는다.

```
Wide 2:1 banner illustration for a mobile game card, flat 2D vector art with bold dark navy
outlines (#1F2A44). A round mint-green blob character (#3FBF97) with tiny hands and feet stretches
sideways to make a save in front of a goal on fresh green grass (#A8DC8F) with soft mowing stripes.
White penalty box lines curve around him — this is his zone. A white soccer ball (#F4F6F8) rockets
in from the left with a curved motion trail, a yellow ball (#FFD23F) comes from the upper right.
Horizontal composition, goal mouth behind the character, character and both balls kept inside the
middle 40% band of the image height, background extends to all four edges, even flat lighting,
clean minimal mobile game style, no text, no logo, no frame, no vignette
```

**공통 네거티브 프롬프트**

```
text, letters, numbers, logo, watermark, UI, buttons, frame, border, vignette, dark corners,
photorealistic, 3D render, heavy shadows, noise, grain, busy background, crowd of characters,
explosion, fire, blood, top-down bird's eye view, vertical composition, cropped character
```

### 4. 납품·확인

- [ ] `cyber_hero.png` · `dodgeball_hero.png` · `keeper_hero.png` — 1536×768 PNG, 각 500KB 이하
- [ ] 세 장을 나란히 놓고 화풍·캐릭터 크기·조명이 같은지
- [ ] **비율 테스트**: 같은 그림을 2:1 / 3:1 / 5:1 로 가운데 잘라 봐서 셋 다 캐릭터·공·경계선이 다 보이는지
- [ ] 왼쪽 위 280×120 에 `ZONE n` 칩을 얹어도 묻히지 않는지
- [ ] 폰 크기(카드 폭 340dp)로 줄였을 때 공이 무엇인지 바로 읽히는지
- [ ] `assets/images/worlds/` 에 같은 파일명으로 덮어쓰면 코드 수정 없이 반영된다

---

## 납품 체크리스트

- [ ] 파일명·규격 일치 (배경 960×1536, 히어로 1536×768, PNG)
- [ ] 휴대폰 실제 크기로 줄여 봤을 때 공(@2x 기준 지름 18~36px: Galaxy 탄 18, 피구 공 30~36, 골키퍼 공 30)이 바로 보이는지
- [ ] 가장자리 120px 안에 어두운 얼룩이 없는지
- [ ] 파일당 500KB 이하 (pngquant 등으로 압축)
