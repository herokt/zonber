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

## 홈 카드 히어로 3장 — `{id}_hero.png`

홈 화면 존 카드 윗부분(342×176, @2x **684×360**). 배경과 같은 세계관의 "대표 장면"이다.
배경과 달리 **주인공이 있어도 된다** — 캐릭터 하나와 그 존의 공.

| 파일 | 장면 | 구도 |
|---|---|---|
| `cyber_hero.png` | 성운 앞 플랫폼 위 캐릭터, 사방에서 빛나는 탄이 원을 그리며 다가옴 | 캐릭터 약간 오른쪽, 왼쪽 아래는 비움(카드 제목이 올라갈 수 있음) |
| `dodgeball_hero.png` | 체육관 마루, 빨간 고무공이 화면 밖에서 날아오고 캐릭터가 몸을 피함 | 공의 궤적(모션 라인 1~2개) |
| `keeper_hero.png` | 잔디 위 원형 골대 앞, 캐릭터가 공을 막는 순간 | 골대는 오른쪽, 공은 왼쪽 위에서 |

- 글자·로고 없음(카드 제목은 코드가 쓴다). 아래 25%는 너무 복잡하지 않게.
- 세 장의 화풍·조명·캐릭터 크기를 통일한다. 캐릭터는 기본 캐릭터(Neon Green)로.

---

## 납품 체크리스트

- [ ] 파일명·규격 일치 (배경 960×1536, 히어로 684×360, PNG)
- [ ] 휴대폰 실제 크기로 줄여 봤을 때 공(@2x 기준 지름 18~36px: Galaxy 탄 18, 피구 공 30~36, 골키퍼 공 30)이 바로 보이는지
- [ ] 가장자리 120px 안에 어두운 얼룩이 없는지
- [ ] 파일당 500KB 이하 (pngquant 등으로 압축)
