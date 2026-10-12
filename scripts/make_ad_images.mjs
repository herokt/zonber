// Google Ads 앱 캠페인 이미지 — 언어별 6장(가로 1200×628 ×3 · 정사각 1200×1200 ×2 · 세로 1200×1500 ×1).
//
//   node scripts/make_ad_images.mjs [원본 폴더=build/store_shots] [저장 폴더=store/ad_images]
//
// 그림은 존 히어로 아트(assets/images/worlds/{id}_hero.png — Gemini 시안 아트)와 실제 플레이 캡처
// (scripts/store_shots.sh 로 찍은 {lang}/01_galaxy·02_dodgeball·03_keeper)만 쓴다 — 광고가 실제 게임과 같게.
// 버튼처럼 보이는 그림(가짜 [설치])은 넣지 않는다(Google 광고 이미지 정책). 글자는 짧게 한두 줄.
// Chrome(헤드리스) · Google Fonts 사용 — 인터넷 필요. npm 의존성 없음.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const SRC = path.resolve(process.argv[2] || 'build/store_shots');
const OUT = path.resolve(process.argv[3] || 'store/ad_images');
const TMP = path.resolve('build/ad_compose');

const CHROME = [
  process.env.CHROME,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
].find((p) => p && fs.existsSync(p));
if (!CHROME) throw new Error('Chrome 을 찾지 못했다 — CHROME 환경변수로 경로를 준다');

// shots = 플레이 캡처 폴더(언어). zh-TW 는 앱이 간체라 zh 캡처를 쓴다.
const TEXT = {
  en: {
    shots: 'en', font: "'Manrope'",
    title: 'How long can you survive?', sub: 'One finger. Dodge everything.',
    zones: ['Dodge the meteors', 'Dodge the dodgeballs', 'Stop the free kicks'],
  },
  ko: {
    shots: 'ko', font: "'Noto Sans KR'",
    title: '얼마나 버틸 수 있나요?', sub: '손가락 하나로 피하고 막아라',
    zones: ['운석을 피해라', '피구공을 피해라', '프리킥을 막아라'],
  },
  ja: {
    shots: 'ja', font: "'Noto Sans JP'",
    title: 'どこまで耐えられる？', sub: '指一本でよけて、止めろ',
    zones: ['隕石をよけろ', 'ドッジボールをよけろ', 'フリーキックを止めろ'],
  },
  'zh-TW': {
    shots: 'zh', font: "'Noto Sans TC'",
    title: '你能撐多久？', sub: '一根手指，閃避到底',
    zones: ['閃避隕石', '閃避躲避球', '擋下自由球'],
  },
};
const ZONES = ['cyber', 'dodgeball', 'keeper'];
const SHOTS = ['01_galaxy', '02_dodgeball', '03_keeper'];
const ACCENT = ['#22C7E6', '#FF5A4E', '#3DBE6B'];

const url = (p) => pathToFileURL(path.resolve(p)).href;
const hero = (i) => url(`assets/images/worlds/${ZONES[i]}_hero.png`);
const shot = (lang, i) => {
  const f = path.join(SRC, TEXT[lang].shots, `${SHOTS[i]}.png`);
  if (!fs.existsSync(f)) throw new Error(`원본이 없다: ${f} — scripts/store_shots.sh 먼저`);
  return pathToFileURL(f).href;
};
const ICON = url('assets/images/app_icon_rounded.png');

const BASE = (t, w, h) => `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@700;800&family=Noto+Sans+JP:wght@700;900&family=Noto+Sans+KR:wght@700;900&family=Noto+Sans+TC:wght@700;900&family=Sora:wght@800&display=block" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${w}px;height:${h}px;overflow:hidden}
body{position:relative;font-family:${t.font},sans-serif;color:#fff;background:#141A33}
.fill{position:absolute;inset:0;background-size:cover;background-position:center}
.brand{display:flex;align-items:center;gap:16px}
.brand img{border-radius:22%;box-shadow:0 8px 22px rgba(0,0,0,.4)}
.brand b{font:800 1em Sora,sans-serif;letter-spacing:.03em}
.title{font-weight:900;line-height:1.12;text-shadow:0 3px 14px rgba(0,0,0,.35)}
.sub{font-weight:700;opacity:.88}
.pill{display:inline-block;padding:.32em .9em;border-radius:999px;font-weight:900;box-shadow:0 8px 20px rgba(0,0,0,.3)}
.phone{position:absolute;border-radius:34px;border:6px solid #fff;background-size:cover;background-position:center top;box-shadow:0 22px 50px rgba(0,0,0,.5)}
.bg{background:radial-gradient(60% 50% at 75% 40%,rgba(34,199,230,.25),transparent 70%),
  radial-gradient(50% 45% at 10% 85%,rgba(142,112,242,.35),transparent 70%),
  linear-gradient(135deg,#171B36 0%,#221A4F 55%,#141A33 100%)}
</style></head><body>`;

// 가로 1200×628 — 존 하나의 히어로 아트 + 왼쪽 아래 문구
function landscape(lang, i) {
  const t = TEXT[lang];
  return `${BASE(t, 1200, 628)}
<div class="fill" style="background-image:url('${hero(i)}')"></div>
<div class="fill" style="background:linear-gradient(90deg,rgba(10,12,30,.82) 0%,rgba(10,12,30,.55) 36%,transparent 62%)"></div>
<div style="position:absolute;left:56px;top:48px;font-size:38px" class="brand"><img src="${ICON}" width="72" height="72"><b>ZONBER</b></div>
<div style="position:absolute;left:56px;bottom:62px;width:560px">
  <div class="pill" style="background:${ACCENT[i]};font-size:40px">${t.zones[i]}</div>
  <div class="sub" style="margin-top:20px;font-size:30px">${t.sub}</div>
</div>
</body></html>`;
}

// 정사각 1 — 위 브랜드·질문, 아래 세 존 히어로 타일
function squareHeroes(lang) {
  const t = TEXT[lang];
  const tiles = ZONES.map((_, i) => `<div style="position:relative;height:250px;border-radius:26px;overflow:hidden;background:url('${hero(i)}') center/cover;box-shadow:0 12px 30px rgba(0,0,0,.4)">
<span class="pill" style="position:absolute;left:22px;bottom:18px;background:${ACCENT[i]};font-size:28px">${t.zones[i]}</span></div>`).join('');
  return `${BASE(t, 1200, 1200)}<div class="fill bg"></div>
<div style="position:absolute;left:70px;right:70px;top:70px">
  <div class="brand" style="font-size:46px"><img src="${ICON}" width="92" height="92"><b>ZONBER</b></div>
  <div class="title" style="margin-top:34px;font-size:68px">${t.title}</div>
</div>
<div style="position:absolute;left:70px;right:70px;bottom:70px;display:grid;gap:24px">${tiles}</div>
</body></html>`;
}

// 정사각 2 — 실제 플레이 화면 세 장(휴대폰 틀) + 짧은 문구
function squareShots(lang) {
  const t = TEXT[lang];
  const pw = 330, ph = Math.round(pw * 2676 / 1236);
  const phones = [0, 1, 2].map((i) => {
    const x = 600 - pw / 2 + (i - 1) * 360, y = i === 1 ? 330 : 400;
    return `<div class="phone" style="left:${x}px;top:${y}px;width:${pw}px;height:${ph}px;background-image:url('${shot(lang, i)}');transform:rotate(${(i - 1) * 6}deg);z-index:${i === 1 ? 2 : 1}"></div>`;
  }).join('');
  return `${BASE(t, 1200, 1200)}<div class="fill bg"></div>
<div style="position:absolute;left:0;right:0;top:64px;text-align:center">
  <div class="brand" style="justify-content:center;font-size:40px"><img src="${ICON}" width="76" height="76"><b>ZONBER</b></div>
  <div class="title" style="margin-top:24px;font-size:60px">${t.title}</div>
</div>
${phones}
</body></html>`;
}

// 세로 1200×1500 — 갤럭시 플레이 화면 하나 크게 + 위 문구
function portrait(lang) {
  const t = TEXT[lang];
  const pw = 520, ph = Math.round(pw * 2676 / 1236);
  return `${BASE(t, 1200, 1500)}
<div class="fill" style="background-image:url('${hero(0)}');filter:blur(18px) brightness(.55);transform:scale(1.1)"></div>
<div style="position:absolute;left:0;right:0;top:70px;text-align:center">
  <div class="brand" style="justify-content:center;font-size:46px"><img src="${ICON}" width="92" height="92"><b>ZONBER</b></div>
  <div class="title" style="margin-top:28px;font-size:72px">${t.title}</div>
  <div class="sub" style="margin-top:14px;font-size:36px">${t.sub}</div>
</div>
<div class="phone" style="left:${600 - pw / 2}px;top:500px;width:${pw}px;height:${ph}px;border-radius:48px;border-width:8px;background-image:url('${shot(lang, 0)}')"></div>
</body></html>`;
}

const JOBS = [
  ['landscape_galaxy', 1200, 628, (l) => landscape(l, 0)],
  ['landscape_dodgeball', 1200, 628, (l) => landscape(l, 1)],
  ['landscape_freekick', 1200, 628, (l) => landscape(l, 2)],
  ['square_zones', 1200, 1200, squareHeroes],
  ['square_gameplay', 1200, 1200, squareShots],
  ['portrait_gameplay', 1200, 1500, portrait],
];

fs.mkdirSync(TMP, { recursive: true });
for (const lang of Object.keys(TEXT)) {
  const dir = path.join(OUT, lang);
  fs.mkdirSync(dir, { recursive: true });
  for (const [name, w, h, make] of JOBS) {
    const page = path.join(TMP, `${lang}_${name}.html`);
    fs.writeFileSync(page, make(lang));
    const out = path.join(dir, `${name}.png`);
    execFileSync(CHROME, [
      '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
      '--force-device-scale-factor=1', `--window-size=${w},${h}`, '--virtual-time-budget=15000',
      '--default-background-color=FF141A33', `--screenshot=${out}`, pathToFileURL(page).href,
    ], { stdio: 'ignore' });
    console.log(`만듦 ${path.relative(process.cwd(), out)}`);
  }
}
