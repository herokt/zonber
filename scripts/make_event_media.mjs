// App Store 인앱 이벤트 그림 — 이벤트 카드(16:9, 1920×1080) · 이벤트 상세(9:16, 1080×1920). 문구는 store/app_store_events.md
//
//   node scripts/make_event_media.mjs [원본 폴더=store/screenshots/ko/ipad] [저장 폴더=store/event_media]
//
// Apple 가이드: 그림에 글자·로고를 넣지 않는다(이벤트 이름·설명은 App Store 가 위에 얹는다) · 테두리·그라데이션을 넣지 않는다
// (App Store 가 자르고 그라데이션을 씌운다) · 카드 아래쪽은 이벤트 이름이 덮으니 중요한 건 위·가운데에.
// 그래서 iPad 스크린샷(2064×2752)에서 경기장만 잘라 쓴다 — 글자 없는 실제 게임 화면. 세 존 모두 경기장 자리가 같다.
// 스크린샷을 다시 만들면(compose_ios_shots.mjs) 이것도 다시 돌린다. Chrome(헤드리스) 사용. npm 의존성 없음.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const SRC = path.resolve(process.argv[2] || 'store/screenshots/ko/ipad');
const OUT = path.resolve(process.argv[3] || 'store/event_media');
const TMP = path.resolve('build/store_compose');

const CHROME = [
  process.env.CHROME,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
].find((p) => p && fs.existsSync(p));
if (!CHROME) throw new Error('Chrome 을 찾지 못했다 — CHROME 환경변수로 경로를 준다');

const SHOTS = ['01_galaxy', '02_dodgeball', '03_keeper'].map((s) => path.join(SRC, `${s}.png`));
for (const s of SHOTS) if (!fs.existsSync(s)) throw new Error(`원본이 없다: ${s} — scripts/compose_ios_shots.mjs 먼저`);

// iPad 원본(2064×2752) 안 경기장 — 테두리 선 안쪽만 (480:768)
const SHOT_W = 2064;
const ARENA = { x: 648, y: 1138, w: 769, h: 1233 };

// 이벤트마다 배경색 · 경기장 색 보정 · 배경에 흩뿌릴 점(공·눈)
const THEMES = {
  // 월간 랭킹 — 게임 그대로
  leaderboard: { bg: '#141833', filter: 'none', dots: { colors: ['#22C7E6', '#FFFFFF', '#FF5A4E'], count: 46, opacity: 0.35, glow: false } },
  // 할로윈 — 갤럭시는 색상을 돌려 남색 밤 → 보라 · 빨간 공 → 주황, 밝은 피구·프리킥은 어두운 보라 밤으로(sideFilter)
  halloween: { bg: '#1B1030', filter: 'hue-rotate(32deg) saturate(1.25)', sideFilter: 'brightness(.4) sepia(.6) hue-rotate(225deg) saturate(1.8)', dots: { colors: ['#FF8A1F', '#FFB347', '#B784FF'], count: 40, opacity: 0.8, glow: true } },
  // 연말 — 게임 그대로 + 눈
  holiday: { bg: '#0F1A33', filter: 'brightness(1.05)', dots: { colors: ['#FFFFFF'], count: 90, opacity: 0.75, glow: true }, snowOnTop: true },
};

/** 경기장 하나 — 원본에서 잘라 w 폭으로 */
function arena(file, w, theme, style, side = false) {
  const s = w / ARENA.w;
  const h = Math.round(ARENA.h * s);
  return `<div class="arena" style="width:${w}px;height:${h}px;${style};filter:${(side && theme.sideFilter) || theme.filter} drop-shadow(0 24px 40px rgba(0,0,0,.55));
background-image:url('${pathToFileURL(file).href}');background-size:${Math.round(SHOT_W * s)}px auto;
background-position:-${Math.round(ARENA.x * s)}px -${Math.round(ARENA.y * s)}px"></div>`;
}

/** 흩뿌린 점 — 자리는 정해진 수열이라 돌릴 때마다 같다 */
function dots(W, H, d, seed = 1) {
  let k = seed;
  const rnd = () => ((k = (k * 16807) % 2147483647) / 2147483647);
  return Array.from({ length: d.count }, (_, i) => {
    const x = rnd() * W, y = rnd() * H, r = 3 + rnd() * (d.glow ? 9 : 4);
    const c = d.colors[i % d.colors.length];
    return `<circle cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" r="${r.toFixed(1)}" fill="${c}" opacity="${(d.opacity * (0.45 + rnd() * 0.55)).toFixed(2)}"${d.glow ? ' filter="url(#g)"' : ''}/>`;
  }).join('');
}

function page(W, H, theme, body, seed) {
  const svg = (extra = '') => `<svg class="dots" width="${W}" height="${H}" ${extra}><defs><filter id="g" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="3"/></filter></defs>${dots(W, H, theme.dots, seed)}</svg>`;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${W}px;height:${H}px;overflow:hidden;background:${theme.bg}}
.dots{position:absolute;inset:0}
.arena{position:absolute;border-radius:28px;background-repeat:no-repeat}
</style></head><body>${svg()}${body}${theme.snowOnTop ? svg('style="z-index:9"') : ''}</body></html>`;
}

// 카드 16:9 — 세 존을 나란히(가운데가 앞). 아래 1/4 은 이벤트 이름이 덮는다
function card(theme) {
  const W = 1920, H = 1080;
  const side = 470, mid = 560;
  const top = 70;
  const body = [
    arena(SHOTS[1], side, theme, `left:${W / 2 - mid / 2 - side - 40}px;top:${top + 70}px;transform:rotate(-7deg);z-index:2`, true),
    arena(SHOTS[2], side, theme, `left:${W / 2 + mid / 2 + 40}px;top:${top + 70}px;transform:rotate(7deg);z-index:2`, true),
    arena(SHOTS[0], mid, theme, `left:${W / 2 - mid / 2}px;top:${top}px;z-index:3`),
  ].join('\n');
  return page(W, H, theme, body, 7);
}

// 상세 9:16 — 갤럭시를 크게, 피구·프리킥은 뒤에 비스듬히. 아래쪽은 글자 자리라 비운다
function detail(theme) {
  const W = 1080, H = 1920;
  const mid = 760, side = 560;
  const body = [
    arena(SHOTS[1], side, theme, `left:-150px;top:330px;transform:rotate(-9deg);z-index:2`, true),
    arena(SHOTS[2], side, theme, `left:${W - side + 150}px;top:330px;transform:rotate(9deg);z-index:2`, true),
    arena(SHOTS[0], mid, theme, `left:${(W - mid) / 2}px;top:150px;z-index:3`),
  ].join('\n');
  return page(W, H, theme, body, 11);
}

function shoot(html, W, H, out) {
  const file = path.join(TMP, path.basename(out, '.png') + '.html');
  fs.writeFileSync(file, html);
  execFileSync(CHROME, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
    '--force-device-scale-factor=1', `--window-size=${W},${H}`, '--virtual-time-budget=8000',
    `--screenshot=${out}`, pathToFileURL(file).href,
  ], { stdio: 'ignore' });
  console.log(`만듦 ${path.relative(process.cwd(), out)}`);
}

fs.mkdirSync(TMP, { recursive: true });
fs.mkdirSync(OUT, { recursive: true });
for (const [name, theme] of Object.entries(THEMES)) {
  shoot(card(theme), 1920, 1080, path.join(OUT, `${name}_card.png`));
  shoot(detail(theme), 1080, 1920, path.join(OUT, `${name}_detail.png`));
}
