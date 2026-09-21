# ZONBER 캐릭터 컨셉 — v1.0 (2026-09-21)

> 목표: 네온 원판 6종을 **정이 가는 마스코트 "존버"** 로 바꾼다. 능력치는 모두 같고, 고르는 건 모습과 성격뿐이다.
>
> **2026-09-21 적용(현행):** 존버를 **코드로 그린다**(`lib/zonber_painter.dart`) — 별의 커비 느낌의 동그란 몸 + 얼굴(눈·볼·입) + 양손 + 양발, 캐릭터마다 몸 색만 다르다(민트·잽·루나·블레이즈·써니·레이스).
> 표정 3종(기본 · 아야 >< · 신남 ^^) — 맞음/실점이면 아야+납작, 아슬아슬 회피/세이브면 신남. 몸은 돌지 않고 가는 쪽으로 살짝 기운다.
> 존 느낌은 **장비**(`lib/gear.dart`): 갤럭시 날개·로켓 부츠 / 피구 머리띠·운동화 / 골키퍼 모자·장갑·축구화. 부위별 장착, 상점 "장비" 탭.
> 장비는 능력치 보너스(`GearBonus`)를 가질 수 있다 — 지금은 전부 0. 캐릭터 기본 능력치는 모두 `CharacterStats.standard`.
> 아래 §1·§3·§5·§6(이미지 규격·프롬프트)은 나중에 그림 이미지로 바꿀 때의 참고로 남긴다.
> 관련: [STAGES.md](STAGES.md)(존 3종) · [RESOURCES.md](RESOURCES.md)(리소스 목록) · [ART_BRIEF.md](ART_BRIEF.md)(배경 규칙)

## 0. 원칙

| 원칙 | 이유 |
|---|---|
| **능력치 동일** (체력 3 · 속도 1.0 · 회복 25초 · 무적 1.5초) | 랭킹·명패는 순수 실력 경쟁이어야 가치가 있다. `CharacterStats.standard` (2026-09-21 적용) |
| **48px 에서 읽혀야 한다** | 게임 중 캐릭터는 지름 48px 원 안에 보인다. 실루엣 + 색 + 눈만으로 누군지 알아봐야 한다 |
| **얼굴은 코드가 그린다** | 몸통 이미지는 얼굴 없이 1장. 눈·입은 코드로 그려서 맞음·아슬아슬·세이브 반응을 이미지 추가 없이 만든다 |
| **존마다 소품만 바꾼다** | 캐릭터 6 × 존 3 = 18장이 아니라, 몸통 6장 + 소품 3장으로 끝낸다 |
| **id 는 그대로** | 기록·프로필에 `characterId` 가 저장돼 있다. 파일명·id(`neon_green` 등)는 유지하고 표시 이름만 바꾼다 |

## 1. 공통 몸통

- **모양:** 위에서 내려다본 동글동글한 찹쌀떡(모찌) — 거의 원형, 아래쪽이 살짝 넓은 물방울. 팔다리는 작은 뭉툭한 돌기 2개(옆)만. 캐릭터마다 **머리 위 특징 하나**(더듬이·불꽃·뿔 등)로 실루엣을 구분한다.
- **질감:** 매끈한 소프트 비닐 장난감. 위쪽에 둥근 하이라이트 1개, 아래쪽 은은한 음영. 외곽선 없음(또는 몸통 색보다 진한 2px).
- **얼굴 없음:** 눈·입 자리를 비워 둔다(코드가 몸통 중앙 약간 위에 그린다).
- **배경:** 투명. 그림자 없음(게임이 그린다).

### 코드가 그리는 표정

| 상태 | 언제 | 눈 | 입·효과 |
|---|---|---|---|
| 기본 | 평소 | 까만 타원 2개, 가끔 깜빡 | 작은 점 입 |
| 이동 | 빠르게 움직일 때 | 이동 방향으로 눈동자가 쏠림 | — |
| 아슬아슬 | 근접 회피(graze) | 눈 크게 | 땀방울 1개 튐 |
| 맞음 | 피격·실점 | ✕ ✕ | 몸이 납작하게 찌그러졌다 복원(0.2초) |
| 세이브 | 골키퍼 세이브 | 웃는 눈 ^ ^ | 반짝 효과 |
| 무적 | 피격 후 무적 시간 | 기본 눈 | 몸 깜빡임(현행 유지) |

## 2. 캐릭터 6종

| id (유지) | 표시 이름 (EN / KO) | 몸통 색 | 머리 위 특징 | 성격 한 줄 | 해금(4단계 예정) |
|---|---|---|---|---|---|
| `neon_green` | Mint / 민트 | 민트 `#45C4A0` | 새싹 잎 1장 | 원조 존버. 차분하고 꾸준하다 | 기본 |
| `electric_blue` | Zap / 잽 | 전기 파랑 `#2F8CF2` | 번개 모양 삐침머리 | 가만히 못 있는 재간둥이 | 누적 30판 |
| `plasma_purple` | Luna / 루나 | 라벤더 `#A66BF2` | 초승달 더듬이 | 몽환적. 피하면서 콧노래를 부른다 | 한 존에서 60초 |
| `cyber_red` | Blaze / 블레이즈 | 토마토 레드 `#F2503D` | 작은 불꽃 머리 | 지는 걸 못 참는 승부사 | 세 존 모두 60초 |
| `solar_gold` | Sunny / 써니 | 해바라기 `#FFC928` | 해 모양 왕관 테두리 | 맞아도 웃는 햇살 | 명패(브론즈 이상) 획득 |
| `void_dark` | Wraith / 레이스 | 먹색 `#3A3F4B` + 은은한 은빛 가장자리 | 뾰족한 두건 끝 | 어디서 왔는지 아무도 모르는 그림자 | 명패(골드 이상) 획득 |

- 색은 존 배경과 겹치지 않게 골랐다. 갤럭시(짙은 남색)·피구(마루·하늘·민트)·골키퍼(연두 잔디) 위에서 모두 구분돼야 한다. **민트는 피구 우리 진영(민트)과 가까워 몸통을 한 톤 진하게** 뽑는다.
- 기존 `void_dark` 는 밝은 회색이었지만, 먹색 + 은빛 가장자리로 바꿔 "그림자" 성격과 맞춘다.

## 3. 존별 소품 (3단계)

몸통 위에 겹치는 투명 PNG 1장씩. 모든 캐릭터가 같은 소품을 쓴다(색은 소품 고유색).
**결정(2026-09-21): 캐릭터는 모든 존 공통 한 세트, 존 느낌은 복장으로.** 존에 들어가면 그 존 복장을 자동으로 입는다.
지금은 임시로 코드로 그린다(`lib/cosmetics.dart` `paintOutfit`). 아래 파일명으로 이미지를 넣으면 자동으로 이미지로 바뀐다.
명패 보상으로 황금 복장(황금 헬멧 · 불꽃 머리띠 · 황금 장갑)이 있다 — 같은 규격으로 3장 더.

| 존 | 소품 | 파일 | 비고 |
|---|---|---|---|
| 1 Galaxy | 투명 우주 헬멧(둥근 유리 돔 + 반사광) · 황금 헬멧 | `props/outfit_cyber_basic.png` · `props/outfit_cyber_gold.png` | 몸통 전체를 덮는 돔. 반투명 |
| 2 Dodgeball | 빨간 머리띠 + 끝자락 두 가닥 · 불꽃 머리띠 | `props/outfit_dodgeball_basic.png` · `props/outfit_dodgeball_flame.png` | 피구왕 통키 느낌 — 참고만 |
| 3 Goalkeeper | 키퍼 장갑 한 쌍(양옆 돌기에) + 캡 · 황금 장갑 | `props/outfit_keeper_basic.png` · `props/outfit_keeper_gold.png` | 장갑이 보이면 "막는 역할"이 읽힌다 |

## 4. 해금 = 자랑거리 (4단계)

- 캐릭터는 위 표의 조건으로 열린다(현재는 전부 열림 — `CharacterData.allUnlocked`).
- **명패 전용 테두리:** 명패 등급(챔피언·골드·실버·브론즈)을 가진 사람은 그 금속색 테두리를 쓸 수 있다. 랭킹에서 이미 테두리로 보인다(2026-09-21 적용).
- 유료 스킨은 나중에 — 능력치가 없으니 과금이 랭킹 공정성을 해치지 않는다.

## 5. 리소스 규격

| 파일 | 크기 | 내용 |
|---|---|---|
| `assets/images/characters/{id}.png` × 6 | 512×512, 투명 | 얼굴 없는 몸통. 몸통이 캔버스의 약 80%를 채우고 가운데 정렬 |
| `assets/images/characters/props/outfit_*.png` × 6 | 512×512, 투명 | 몸통과 같은 캔버스 기준 위치에 소품만(파일명 = 복장 id) |

- 용량: 장당 200KB 이하(PNG 압축).
- 기존 원판 이미지는 교체 전까지 그대로 쓴다. 새 이미지를 같은 파일명으로 덮어쓰면 코드 변경 없이 바뀐다(얼굴 그리기 코드는 2단계에서 추가).

## 6. 생성 프롬프트 (Gemini 등)

**공통 스타일(모든 캐릭터 앞에 붙인다)**
```
Cute mascot character for a mobile hypercasual game, top-down view, a round soft mochi-like blob body
(almost a circle, slightly wider at the bottom), two tiny stubby nubs on the sides as arms,
smooth glossy vinyl-toy material, one soft round highlight at the top, subtle shading at the bottom,
NO face (no eyes, no mouth — leave the face area blank and smooth), no outline or a thin darker outline,
centered, filling about 80% of the canvas, transparent background, no shadow, no text, 512x512
```

| id | 캐릭터별 문구 (공통 뒤에 붙인다) |
|---|---|
| `neon_green` | `mint green body (#45C4A0), a single small sprout leaf growing from the top of the head` |
| `electric_blue` | `electric blue body (#2F8CF2), a spiky tuft of hair on top shaped like a lightning bolt` |
| `plasma_purple` | `lavender purple body (#A66BF2), two thin antennae on top ending in tiny crescent moons` |
| `cyber_red` | `tomato red body (#F2503D), a small stylized flame on top of the head like a hair tuft` |
| `solar_gold` | `sunflower yellow body (#FFC928), a ring of small rounded sun rays around the top like a crown` |
| `void_dark` | `charcoal ink body (#3A3F4B) with a faint silver rim light, the top tapers into a soft pointed hood tip` |

**소품**
```
galaxy_helmet:     A transparent round glass space helmet dome with a soft reflection streak, sized to cover a round blob character, transparent background, no character inside, 512x512
dodgeball_headband: A red sports headband with two short tails fluttering to the side, top-down view, sized for a round blob head, transparent background, 512x512
keeper_gloves:     A pair of chunky goalkeeper gloves (white and neon green) placed left and right at the sides, plus a small cap, top-down view, sized for a round blob character, transparent background, 512x512
```

뽑은 뒤 확인할 것: ① 얼굴이 비어 있는가 ② 48px 로 줄였을 때 6종이 구분되는가 ③ 배경이 투명한가 ④ 몸통 위치·크기가 6장 모두 같은가(소품이 맞아야 한다).

## 7. 진행 단계

| 단계 | 내용 | 상태 |
|---|---|---|
| 1 | 능력치 통일 · 선택 화면 스탯 바 제거 | ✅ 2026-09-21 |
| 2 | 몸통 이미지 6장 교체 + 코드 표정(눈·입·반응) + 표시 이름 변경 | 이미지 대기 |
| 3 | 존별 복장 자동 착용 + 명패 보상 황금 복장 | ✅ 임시 코드 그림 2026-09-21 · 이미지 대기 |
| 4 | 해금 조건 켜기 · 명패 테두리 선택 | 기획 확정 후 |
