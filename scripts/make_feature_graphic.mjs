// Google Play 그래픽 이미지(1024×500) — 앱 아이콘 · ZONBER · 한 줄 문구(언어별) + 세 존 경기장 캡처 카드.
//
//   node scripts/make_feature_graphic.mjs [원본 폴더=build/store_shots] [저장 폴더=store/feature_graphic]
//
// 경기장 카드는 scripts/store_shots.sh 로 찍은 한국어 원본(ko/1_galaxy·2_dodgeball·3_keeper)에서 경기장만 잘라 쓴다
// (글자가 없어 언어와 무관). Chrome(헤드리스) · Google Fonts 사용 — 인터넷 필요. npm 의존성 없음.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const SRC = path.resolve(process.argv[2] || 'build/store_shots');
const OUT = path.resolve(process.argv[3] || 'store/feature_graphic');
const TMP = path.resolve('build/store_compose');
const W = 1024, H = 500;

const CHROME = [
  process.env.CHROME,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
].find((p) => p && fs.existsSync(p));
if (!CHROME) throw new Error('Chrome 을 찾지 못했다 — CHROME 환경변수로 경로를 준다');

// 한 줄 문구 · 존 이름(카드 아래 꼬리표)
const TEXT = {
  ko: { tag: '좁은 존에서 끝까지 버텨라', zones: ['갤럭시', '피구', '프리킥'], font: "'Noto Sans KR'" },
  en: { tag: 'Dodge, survive, rank worldwide', zones: ['Galaxy', 'Dodgeball', 'FreeKick'], font: "'Manrope'" },
  ja: { tag: '狭いゾーンで最後まで耐え抜け', zones: ['ギャラクシー', 'ドッジボール', 'フリーキック'], font: "'Noto Sans JP'" },
  zh: { tag: '在狭小区域中坚持到底', zones: ['银河', '躲避球', '任意球'], font: "'Noto Sans SC'" },
};
const ACCENT = ['#22C7E6', '#FF5A4E', '#2F6FE4'];
const CARDS = ['1_galaxy', '2_dodgeball', '3_keeper'].map((s) => path.join(SRC, 'ko', `${s}.png`));
for (const c of CARDS) if (!fs.existsSync(c)) throw new Error(`원본이 없다: ${c} — scripts/store_shots.sh 먼저`);

// 원본 1440×3120 에서 경기장(HUD 아래)만 — 비율로 자른다(기기 폭 기준 경기장은 위에서 약 22.5%~94%)
const crop = { top: 0.225, bottom: 0.945 };

function html(lang) {
  const t = TEXT[lang];
  const icon = pathToFileURL(path.resolve('assets/images/app_icon_rounded.png')).href;
  const cardW = 178, cardH = 300;
  const cards = CARDS.map((file, i) => {
    const rot = [-9, 0, 9][i];
    const x = 490 + i * 150;
    const y = [92, 58, 92][i];
    return `<div class="card" style="left:${x}px;top:${y}px;transform:rotate(${rot}deg);z-index:${i === 1 ? 3 : 2}">
<div class="shot" style="background-image:url('${pathToFileURL(file).href}')"></div>
<span style="background:${ACCENT[i]}">${t.zones[i]}</span></div>`;
  }).join('\n');
  return `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@700&family=Noto+Sans+JP:wght@700&family=Noto+Sans+KR:wght@700&family=Noto+Sans+SC:wght@700&family=Sora:wght@800&display=block" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${W}px;height:${H}px;overflow:hidden}
body{position:relative;font-family:${t.font},sans-serif;color:#fff;
  background:radial-gradient(520px 380px at 78% 45%,rgba(34,199,230,.28),transparent 70%),
             radial-gradient(420px 320px at 12% 80%,rgba(142,112,242,.35),transparent 70%),
             linear-gradient(135deg,#171B36 0%,#221A4F 55%,#141A33 100%)}
.dots{position:absolute;inset:0}
.brand{position:absolute;left:64px;top:0;bottom:0;width:430px;display:flex;flex-direction:column;justify-content:center}
.brand img{width:132px;height:132px;filter:drop-shadow(0 10px 24px rgba(0,0,0,.45))}
h1{margin-top:22px;font:800 76px Sora,sans-serif;letter-spacing:.02em;line-height:1}
p{margin-top:14px;font-weight:700;font-size:26px;color:rgba(255,255,255,.86);white-space:nowrap}
.card{position:absolute;width:${cardW}px;height:${cardH + 44}px}
.shot{width:${cardW}px;height:${cardH}px;border-radius:20px;background-size:${cardW}px auto;
  background-position:0 -${Math.round(cardW * 3120 / 1440 * crop.top)}px;border:4px solid rgba(255,255,255,.92);
  box-shadow:0 16px 36px rgba(0,0,0,.45)}
.card span{display:block;width:max-content;margin:10px auto 0;padding:5px 14px;border-radius:999px;font-weight:700;font-size:17px;box-shadow:0 6px 16px rgba(0,0,0,.3)}
</style></head><body>
<svg class="dots" width="${W}" height="${H}">${Array.from({ length: 34 }, (_, k) => {
    const x = (k * 197) % W, y = (k * 113 + 37) % H, r = 2 + (k % 3);
    return `<circle cx="${x}" cy="${y}" r="${r}" fill="${k % 4 === 0 ? '#FF5A4E' : '#FFFFFF'}" opacity="${k % 4 === 0 ? 0.55 : 0.18}"/>`;
  }).join('')}</svg>
<div class="brand"><img src="${icon}"><h1>ZONBER</h1><p>${t.tag}</p></div>
${cards}
</body></html>`;
}

fs.mkdirSync(TMP, { recursive: true });
fs.mkdirSync(OUT, { recursive: true });
for (const lang of Object.keys(TEXT)) {
  const page = path.join(TMP, `feature_${lang}.html`);
  fs.writeFileSync(page, html(lang));
  const out = path.join(OUT, `${lang}.png`);
  execFileSync(CHROME, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
    '--force-device-scale-factor=1', `--window-size=${W},${H}`, '--virtual-time-budget=15000',
    '--default-background-color=FF171B36', `--screenshot=${out}`, pathToFileURL(page).href,
  ], { stdio: 'ignore' });
  console.log(`만듦 ${path.relative(process.cwd(), out)}`);
}
