// 스토어 소개 이미지 합성 — scripts/store_shots.sh 로 찍은 원본(build/store_shots/{언어}/{이름}.png)에
// 문구·배경·휴대폰 틀·상태바를 입혀 Google Play 휴대전화 스크린샷(1080×1920)을 만든다.
//
//   node scripts/compose_store_shots.mjs [원본 폴더=build/store_shots] [저장 폴더=store/screenshots_play]
//
// Chrome(헤드리스)으로 그린다 — 글꼴은 Google Fonts(Noto Sans KR/JP/SC · Sora)라 인터넷이 필요하다.
// npm 의존성 없음.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const SRC = path.resolve(process.argv[2] || 'build/store_shots');
const OUT = path.resolve(process.argv[3] || 'store/screenshots_play');
const TMP = path.resolve('build/store_compose');
const W = 1080, H = 1920;

const CHROME = [
  process.env.CHROME,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
].find((p) => p && fs.existsSync(p));
if (!CHROME) throw new Error('Chrome 을 찾지 못했다 — CHROME 환경변수로 경로를 준다');

// 화면마다 배경(위→아래) · 강조색 · 상태바 글자색(앱 화면 위쪽이 어두우면 light)
const THEMES = {
  '1_galaxy': { bg: ['#262B45', '#1C2653'], hl: '#3DE3CB', bar: 'light' },
  '2_dodgeball': { bg: ['#EC9A45', '#D35E26'], hl: '#FFE68C', bar: 'dark' },
  '3_keeper': { bg: ['#46B472', '#2F9657'], hl: '#DDF76E', bar: 'dark' },
  '4_ranking': { bg: ['#2997B2', '#0F5F7A'], hl: '#FFCC55', bar: 'dark' },
  '5_bag': { bg: ['#8E70F2', '#5537CC'], hl: '#FFBCE8', bar: 'dark' },
  '6_home': { bg: ['#262B45', '#1B2A5A'], hl: '#3DE3CB', bar: 'dark' },
};

// 문구 — [ ] 안은 강조색. 제목의 \n 은 줄바꿈 (App Store 이미지와 같은 문구)
const CAPTIONS = {
  ko: {
    '1_galaxy': ['[존]에서 [버]터라', '사방에서 쏟아지는 탄막,\n몇 초나 버틸 수 있을까?'],
    '2_dodgeball': ['날아오는 [공]을 피해라', '한 턴에 한 번,\n점점 빨라지는 피구공'],
    '3_keeper': ['[골문]을 지켜라', '감아차기, 총알슛,\n무회전까지 막아라'],
    '4_ranking': ['[세계 1위]에 도전하라', '주간·월간·연간 랭킹,\n나라별 순위까지'],
    '5_bag': ['나만의 [존버] 꾸미기', '캐릭터 8종,\n존마다 다른 장비'],
    '6_home': ['[3]개의 존, [3]가지 생존', '우주, 피구장,\n그리고 페널티 박스'],
  },
  en: {
    '1_galaxy': ['HOLD OUT\nIN THE [ZONE]', 'Bullets from every side.\nHow long can you last?'],
    '2_dodgeball': ['DODGE\nEVERY [THROW]', 'One throw a turn —\nthen faster and faster.'],
    '3_keeper': ['GUARD\nTHE [GOAL]', 'Curlers, rockets\nand knuckleballs.'],
    '4_ranking': ['BEAT\nTHE [WORLD]', 'Weekly, monthly and yearly\nrankings — by country, too.'],
    '5_bag': ['DRESS UP\nYOUR [ZONBER]', '8 characters and\ngear for every zone.'],
    '6_home': ['[3] ZONES,\n[3] WAYS TO SURVIVE', 'Deep space, the dodgeball court\nand the penalty box.'],
  },
  ja: {
    '1_galaxy': ['[ゾーン]で耐え抜け', '四方から迫る弾幕、\n何秒耐えられる？'],
    '2_dodgeball': ['すべての[球]をかわせ', '1ターンに1球、\nどんどん速くなる'],
    '3_keeper': ['[ゴール]を守り抜け', 'カーブ、ロケット、\nそして無回転'],
    '4_ranking': ['[世界1位]をめざせ', '週間・月間・年間ランキング、\n国別順位も'],
    '5_bag': ['自分だけの[ZONBER]', 'キャラクター8種、\nゾーンごとの装備'],
    '6_home': ['[3]つのゾーン、[3]つの戦い', '宇宙、ドッジボールコート、\nそしてペナルティエリア'],
  },
  zh: {
    '1_galaxy': ['在[区域]中坚持住', '弹幕四面袭来，\n你能撑多久？'],
    '2_dodgeball': ['躲开每一[球]', '每回合一球，\n越来越快'],
    '3_keeper': ['守住[球门]', '弧线球、火箭球，\n还有电梯球'],
    '4_ranking': ['挑战[世界第一]', '周榜、月榜、年榜，\n还有国家排行'],
    '5_bag': ['打造你的[ZONBER]', '8个角色，\n每个区域专属装备'],
    '6_home': ['[3]个区域，[3]种挑战', '太空、躲避球场，\n还有禁区'],
  },
};

const FONT = {
  ko: "'Noto Sans KR'",
  en: "'Sora', 'Noto Sans KR'",
  ja: "'Noto Sans JP'",
  zh: "'Noto Sans SC'",
};

// 휴대폰 — 폭 PHONE_W, 테 BEZEL. 화면은 원본 비율 그대로. 위에서 PHONE_TOP 부터 아래로 넘친다
const PHONE_W = 740, BEZEL = 18, PHONE_TOP = 590;
// 원본 앱 위쪽의 상태바 자리(lib/store_shot.dart statusBarDp) 와 기기 dp 폭
const STATUS_DP = 34;

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
const mark = (s, hl) =>
  esc(s).replace(/\[([^\]]+)\]/g, `<span style="color:${hl}">$1</span>`).replace(/\n/g, '<br>');

function pngSize(file) {
  const b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

function html(lang, shot, imgFile) {
  const t = THEMES[shot];
  const [title, sub] = CAPTIONS[lang][shot];
  const { w: iw, h: ih } = pngSize(imgFile);
  const screenW = PHONE_W - BEZEL * 2;
  const screenH = Math.round((screenW * ih) / iw);
  // 기기 dp 폭 — 1440px 폭 기기는 3.75배(384dp). 원본 폭으로 짐작한다
  const dpW = iw / (iw >= 1400 ? 3.75 : iw >= 1000 ? 2.625 : 2);
  const barH = Math.round((STATUS_DP * screenW) / dpW);
  const ink = t.bar === 'light' ? '#FFFFFF' : '#111827';
  const titleSize = lang === 'en' ? 92 : 100;
  return `<!doctype html><html><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@500;900&family=Noto+Sans+KR:wght@500;900&family=Noto+Sans+SC:wght@500;900&family=Manrope:wght@600&family=Roboto:wght@500&family=Sora:wght@800&display=block" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${W}px;height:${H}px;overflow:hidden}
body{background:linear-gradient(180deg,${t.bg[0]} 0%,${t.bg[1]} 100%);font-family:${FONT[lang]},sans-serif;color:#fff;position:relative}
.cap{position:absolute;left:60px;right:60px;top:0;height:${PHONE_TOP - 20}px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center}
h1{white-space:nowrap;font-size:${titleSize}px;font-weight:${lang === 'en' ? 800 : 900};line-height:1.14;letter-spacing:${lang === 'en' ? '0.01em' : '-0.02em'};text-shadow:0 4px 18px rgba(0,0,0,.18)}
p{margin-top:34px;font-size:40px;font-weight:${lang === 'en' ? 600 : 500};font-family:${lang === 'en' ? "'Manrope'" : FONT[lang]},sans-serif;line-height:1.45;color:rgba(255,255,255,.84)}
.phone{position:absolute;left:${(W - PHONE_W) / 2}px;top:${PHONE_TOP}px;width:${PHONE_W}px;height:${screenH + BEZEL * 2}px;border-radius:92px;background:#0B0D12;padding:${BEZEL}px;box-shadow:0 30px 80px rgba(0,0,0,.35),inset 0 0 0 3px #2A2F3A}
.screen{position:relative;width:${screenW}px;height:${screenH}px;border-radius:${92 - BEZEL}px;overflow:hidden;background:#000}
.screen img{display:block;width:100%;height:100%}
.bar{position:absolute;left:0;right:0;top:0;height:${barH}px;display:flex;align-items:center;justify-content:space-between;padding:0 ${Math.round(barH * 0.62)}px;color:${ink};font:500 ${Math.round(barH * 0.42)}px Roboto,sans-serif}
.cam{position:absolute;left:50%;top:${Math.round(barH * 0.5)}px;width:${Math.round(barH * 0.42)}px;height:${Math.round(barH * 0.42)}px;margin:-${Math.round(barH * 0.21)}px 0 0 -${Math.round(barH * 0.21)}px;border-radius:50%;background:#050608;box-shadow:0 0 0 2px rgba(255,255,255,.06)}
.icons{display:flex;gap:${Math.round(barH * 0.16)}px;align-items:center}
.icons svg{height:${Math.round(barH * 0.42)}px;width:auto;fill:${ink}}
</style></head><body>
<div class="cap"><h1>${mark(title, t.hl)}</h1><p>${mark(sub, t.hl)}</p></div>
<div class="phone"><div class="screen"><img src="${pathToFileURL(imgFile).href}">
<div class="bar"><span>12:00</span><div class="icons">
<svg viewBox="0 0 24 24"><path d="M12 21.5 0.6 8.6A16.5 16.5 0 0 1 12 4a16.5 16.5 0 0 1 11.4 4.6z"/></svg>
<svg viewBox="0 0 24 24"><path d="M2 22h20V2z"/></svg>
<svg viewBox="0 0 30 24"><rect x="1" y="5" width="24" height="14" rx="3.5" fill="none" stroke="${ink}" stroke-width="2"/><rect x="3.5" y="7.5" width="17" height="9" rx="1.5"/><rect x="26" y="9.5" width="2.5" height="5" rx="1"/></svg>
</div></div><div class="cam"></div></div></div>
<script>
// 제목이 한 줄 폭을 넘으면 넘치지 않을 때까지 글자를 줄인다
document.fonts.ready.then(() => { const h = document.querySelector('h1'); let s = parseFloat(getComputedStyle(h).fontSize); while (h.scrollWidth > h.parentElement.clientWidth && s > 40) { s -= 2; h.style.fontSize = s + 'px'; } });
</script>
</body></html>`;
}

fs.mkdirSync(TMP, { recursive: true });
let made = 0;
for (const lang of Object.keys(CAPTIONS)) {
  for (const shot of Object.keys(THEMES)) {
    const img = path.join(SRC, lang, `${shot}.png`);
    if (!fs.existsSync(img)) {
      console.log(`없음: ${lang}/${shot}`);
      continue;
    }
    const page = path.join(TMP, `${lang}_${shot}.html`);
    fs.writeFileSync(page, html(lang, shot, img));
    const outDir = path.join(OUT, lang, 'phone');
    fs.mkdirSync(outDir, { recursive: true });
    const out = path.join(outDir, `${shot}.png`);
    execFileSync(CHROME, [
      '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
      '--force-device-scale-factor=1', `--window-size=${W},${H}`, '--virtual-time-budget=15000',
      `--screenshot=${out}`, pathToFileURL(page).href,
    ], { stdio: 'ignore' });
    console.log(`만듦 ${lang}/${shot}`);
    made++;
  }
}
console.log(`${made}장 → ${OUT}`);
