// App Store 스크린샷 합성 — 스크린샷 모드로 찍은 원본에 문구·배경·기기 틀·iOS 상태바를 입힌다.
//   iPhone 6.9" 1320×2868 ← build/store_shots/{언어}/{이름}.png       (휴대폰 그대로 찍은 것 — 비율이 거의 같다)
//   iPad 13"   2064×2752 ← build/store_shots_ipad/{언어}/{이름}.png  (기기 화면을 4:3 으로 바꿔 찍은 것)
//
//   bash scripts/store_shots.sh <기기>                                   # 휴대폰 화면
//   bash scripts/store_shots.sh <기기> build/store_shots_ipad --ipad     # iPad 비율(끝나면 화면 크기를 되돌린다)
//   node scripts/compose_ios_shots.mjs                                   # → store/screenshots/{언어}/{iphone,ipad}/
//
// 문구·색은 store_shot_captions.mjs. Chrome(헤드리스)으로 그린다 — 글꼴은 Google Fonts 라 인터넷이 필요하다. npm 의존성 없음.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { THEMES, CAPTIONS, FONT, FONTS_LINK, CHROME_PATHS } from './store_shot_captions.mjs';

const OUT = path.resolve('store/screenshots');
const TMP = path.resolve('build/store_compose_ios');
const CHROME = CHROME_PATHS.find((p) => p && fs.existsSync(p));
if (!CHROME) throw new Error('Chrome 을 찾지 못했다 — CHROME 환경변수로 경로를 준다');

// 원본 앱 위쪽의 상태바 자리(lib/store_shot.dart statusBarDp)
const STATUS_DP = 34;

const DEVICES = {
  iphone: {
    src: 'build/store_shots', W: 1320, H: 2868, capH: 700, title: 128, titleEn: 116, sub: 52, oneLine: false,
    dev: { top: 700, bottom: 80, bezel: 22, radius: 150 }, dpScale: 3.75, island: true,
  },
  ipad: {
    src: 'build/store_shots_ipad', W: 2064, H: 2752, capH: 620, title: 150, titleEn: 132, sub: 62, oneLine: true,
    dev: { top: 640, bottom: 80, bezel: 26, radius: 96 }, dpScale: 1.5, island: false,
  },
};

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
const mark = (s, hl) => esc(s).replace(/\[([^\]]+)\]/g, `<span style="color:${hl}">$1</span>`).replace(/\n/g, '<br>');

function pngSize(file) {
  const b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

function html(d, lang, shot, imgFile) {
  const t = THEMES[shot];
  let [title, sub] = CAPTIONS[lang][shot];
  if (d.oneLine) {
    title = title.replace(/\n/g, ' ');
    sub = sub.replace(/\n/g, lang === 'en' ? ' ' : ' ');
  }
  const { w: iw, h: ih } = pngSize(imgFile);
  // 기기 전체가 이미지 안에 들어오게 — 남은 높이에 맞춰 폭을 정한다(아래가 잘리면 버튼이 안 보인다)
  const { top, bottom, bezel, radius } = d.dev;
  const screenH = d.H - top - bottom - bezel * 2;
  const screenW = Math.round((screenH * iw) / ih);
  const devW = screenW + bezel * 2;
  const dpW = iw / d.dpScale;
  const barH = Math.round((STATUS_DP * screenW) / dpW);
  const ink = t.bar === 'light' ? '#FFFFFF' : '#0B0D12';
  const en = lang === 'en';
  const titleSize = en ? d.titleEn : d.title;
  const icon = Math.round(barH * (d.island ? 0.34 : 0.42));
  return `<!doctype html><html><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="${FONTS_LINK}" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${d.W}px;height:${d.H}px;overflow:hidden}
body{background:linear-gradient(180deg,${t.bg[0]} 0%,${t.bg[1]} 100%);font-family:${FONT[lang]},sans-serif;color:#fff;position:relative}
.cap{position:absolute;left:${Math.round(d.W * 0.06)}px;right:${Math.round(d.W * 0.06)}px;top:0;height:${d.capH}px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center}
h1{white-space:nowrap;font-size:${titleSize}px;font-weight:${en ? 800 : 900};line-height:1.12;letter-spacing:${en ? '0.01em' : '-0.02em'};text-shadow:0 5px 22px rgba(0,0,0,.18)}
p{margin-top:${Math.round(d.sub * 0.8)}px;white-space:nowrap;font-size:${d.sub}px;font-weight:${en ? 600 : 500};font-family:${en ? "'Manrope'" : FONT[lang]},sans-serif;line-height:1.42;color:rgba(255,255,255,.86)}
.dev{position:absolute;left:${(d.W - devW) / 2}px;top:${top}px;width:${devW}px;height:${screenH + bezel * 2}px;border-radius:${radius}px;background:#0B0D12;padding:${bezel}px;box-shadow:0 40px 110px rgba(0,0,0,.35),inset 0 0 0 4px #2A2F3A}
.screen{position:relative;width:${screenW}px;height:${screenH}px;border-radius:${radius - bezel}px;overflow:hidden;background:#000}
.screen img{display:block;width:100%;height:100%}
.bar{position:absolute;left:0;right:0;top:0;height:${barH}px;display:flex;align-items:center;justify-content:space-between;padding:0 ${Math.round(barH * (d.island ? 0.95 : 0.6))}px;color:${ink};font:600 ${Math.round(barH * (d.island ? 0.36 : 0.42))}px -apple-system,'SF Pro Text',Roboto,sans-serif;letter-spacing:.01em}
.island{position:absolute;left:50%;top:${Math.round(barH * 0.2)}px;width:${Math.round(screenW * 0.29)}px;height:${Math.round(barH * 0.64)}px;transform:translateX(-50%);border-radius:999px;background:#000}
.icons{display:flex;gap:${Math.round(icon * 0.4)}px;align-items:center}
.icons svg{height:${icon}px;width:auto;fill:${ink}}
.home{position:absolute;left:50%;bottom:${Math.round(barH * 0.2)}px;width:${Math.round(screenW * (d.island ? 0.36 : 0.2))}px;height:${Math.max(8, Math.round(barH * 0.1))}px;transform:translateX(-50%);border-radius:999px;background:${ink};opacity:.4}
</style></head><body>
<div class="cap"><h1>${mark(title, t.hl)}</h1><p>${mark(sub, t.hl)}</p></div>
<div class="dev"><div class="screen"><img src="${pathToFileURL(imgFile).href}">
<div class="bar"><span>9:41</span><div class="icons">
<svg viewBox="0 0 34 22"><rect x="0" y="14" width="6" height="8" rx="1.5"/><rect x="9" y="10" width="6" height="12" rx="1.5"/><rect x="18" y="5" width="6" height="17" rx="1.5"/><rect x="27" y="0" width="6" height="22" rx="1.5"/></svg>
<svg viewBox="0 0 30 22"><path d="M15 21.5l-4.2-4.5a6 6 0 0 1 8.4 0zM6.6 12.6a12 12 0 0 1 16.8 0l-2.8 3a8 8 0 0 0-11.2 0zM2.2 7.9a18 18 0 0 1 25.6 0l-2.8 3a14 14 0 0 0-20 0z"/></svg>
<svg viewBox="0 0 46 22"><rect x="1.5" y="1.5" width="38" height="19" rx="5.5" fill="none" stroke="${ink}" stroke-width="2.4" opacity=".45"/><rect x="4.5" y="4.5" width="32" height="13" rx="3"/><rect x="42" y="7.5" width="3" height="7" rx="1.5" opacity=".45"/></svg>
</div></div>${d.island ? '<div class="island"></div>' : ''}<div class="home"></div></div></div>
<script>
// 제목·부제가 한 줄 폭을 넘으면 넘치지 않을 때까지 글자를 줄인다
document.fonts.ready.then(() => { for (const el of document.querySelectorAll('h1,p')) { let s = parseFloat(getComputedStyle(el).fontSize); while (el.scrollWidth > el.parentElement.clientWidth && s > 30) { s -= 2; el.style.fontSize = s + 'px'; } } });
</script>
</body></html>`;
}

fs.mkdirSync(TMP, { recursive: true });
let made = 0;
for (const [kind, d] of Object.entries(DEVICES)) {
  for (const lang of Object.keys(CAPTIONS)) {
    const outDir = path.join(OUT, lang, kind);
    for (const shot of Object.keys(THEMES)) {
      const img = path.resolve(d.src, lang, `${shot}.png`);
      if (!fs.existsSync(img)) {
        console.log(`없음: ${kind} ${lang}/${shot}`);
        continue;
      }
      const page = path.join(TMP, `${kind}_${lang}_${shot}.html`);
      fs.writeFileSync(page, html(d, lang, shot, img));
      fs.mkdirSync(outDir, { recursive: true });
      execFileSync(CHROME, [
        '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
        '--force-device-scale-factor=1', `--window-size=${d.W},${d.H}`, '--virtual-time-budget=15000',
        `--screenshot=${path.join(outDir, `${shot}.png`)}`, pathToFileURL(page).href,
      ], { stdio: 'ignore' });
      made++;
    }
    console.log(`만듦 ${kind} ${lang}`);
  }
}
console.log(`${made}장 → ${OUT}`);
