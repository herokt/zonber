// 광고 영상 원본 캡처 — 광고 영상 모드(lib/ad_video.dart) 웹 빌드를 PC Chrome(헤드리스)으로 돌리며 한 프레임씩 찍는다(2026-10-12).
//   flutter build web --release --dart-define=STORE_SHOT=true --dart-define=AD_VIDEO=true --output build/web_advideo
//   node scripts/ad_video_capture.mjs [--lang ko] [--seconds 10]   # → build/ad_video/{언어}/{장면}/f0000.png … + frames.json
//   python scripts/make_ad_video.py [--lang ko]                     # 합성 → store/ad_videos/{언어}/
// 앱이 `ADVIDEO scene <이름>` 을 찍으면 adVideoStep(2)(1/60초 × 2 = 30fps)와 캡처를 되풀이하고 adVideoNext() 로 넘긴다.
// 화면 = 360×640 @3 (1080×1920, 9:16). 장면마다 처음 1초는 자동 플레이가 자리 잡게 찍지 않고 넘긴다.
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { spawn } from 'node:child_process';

const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const LANG = arg('--lang', 'ko');
const SECONDS = Number(arg('--seconds', '10'));
const DRY = process.argv.includes('--dry'); // 찍지 않고 돌려 맞은 수·막은 수만 센다(자동 플레이 다듬기)
const FPS = 30;
const WARMUP = FPS; // 찍지 않고 넘기는 프레임
const WEB = path.resolve('build/web_advideo');
const OUT = path.resolve('build/ad_video', LANG);
const VIEW = { w: 360, h: 640, dpr: 3 };
const CHROME = ['C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe'].find((p) => fs.existsSync(p));
if (!CHROME) throw new Error('Chrome 이 없다');
if (!fs.existsSync(path.join(WEB, 'index.html'))) throw new Error(`웹 빌드가 없다: ${WEB} — 맨 위 주석의 flutter build web 먼저`);

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.wav': 'audio/wav', '.mp3': 'audio/mpeg', '.css': 'text/css' };
const server = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(WEB, p);
  if (!f.startsWith(WEB) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': MIME[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
}).listen(0, '127.0.0.1');
await new Promise((r) => server.once('listening', r));
const url = `http://127.0.0.1:${server.address().port}/?lang=${LANG}`;

const prof = fs.mkdtempSync(path.join(process.env.TEMP || '/tmp', 'zvid-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${prof}`, '--no-first-run', '--hide-scrollbars', '--mute-audio', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
const wsUrl = await new Promise((res, rej) => {
  let buf = '';
  chrome.stderr.on('data', (d) => { buf += d; const m = buf.match(/ws:\/\/[^\s]+/); if (m) res(m[0]); });
  setTimeout(() => rej(new Error('Chrome 디버그 주소를 못 받았다')), 20000);
});
const port = new URL(wsUrl).port;
const page = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find((t) => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r));
let id = 0;
const waits = new Map();
const send = (method, params = {}) => new Promise((res, rej) => {
  const i = ++id;
  waits.set(i, (m) => (m.error ? rej(new Error(`${method}: ${m.error.message}`)) : res(m.result)));
  ws.send(JSON.stringify({ id: i, method, params }));
});
const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(`${expression}: ${r.exceptionDetails.exception?.description || r.exceptionDetails.text}`);
  return r.result.value;
};

const scenes = [];
let finished;
const done = new Promise((r) => (finished = r));
ws.addEventListener('message', (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && waits.has(m.id)) { waits.get(m.id)(m); waits.delete(m.id); return; }
  if (m.method === 'Runtime.consoleAPICalled') {
    const text = (m.params.args || []).map((a) => a.value ?? '').join(' ');
    if (/failed|Error|rror:/.test(text)) console.log('[앱]', text.slice(0, 300));
    const i = text.indexOf('ADVIDEO ');
    if (i < 0) return;
    const [, kind, name] = text.slice(i).trim().split(/\s+/);
    if (kind === 'done') return finished();
    if (kind === 'scene') capture(name).catch((e) => { console.error(e); finished(); });
  }
});

async function capture(name) {
  const dir = path.join(OUT, name);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  for (let i = 0; i < WARMUP; i++) await evaluate('adVideoStep(2)');
  const frames = [];
  const total = Math.round(SECONDS * FPS);
  const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    frames.push(JSON.parse(await evaluate('adVideoStep(2)')));
    if (DRY) continue;
    const shot = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(path.join(dir, `f${String(i).padStart(4, '0')}.png`), Buffer.from(shot.data, 'base64'));
    if (i % 60 === 59) console.log(`${name} ${i + 1}/${total} (${((Date.now() - t0) / (i + 1)).toFixed(0)}ms/프레임)`);
  }
  if (DRY) {
    const count = {};
    for (const f of frames) for (const [n] of f.sfx) count[n] = (count[n] || 0) + 1;
    const xs = frames.map((f) => f.x).sort((a, b) => a - b), ys = frames.map((f) => f.y).sort((a, b) => a - b);
    const q = (a, p) => Math.round(a[Math.floor((a.length - 1) * p)]);
    console.log(name, `${SECONDS}초`, JSON.stringify(count), `캐릭터 x ${q(xs, 0.05)}~${q(xs, 0.95)} · y ${q(ys, 0.05)}~${q(ys, 0.95)} (화면 ${VIEW.w}×${VIEW.h})`);
    fs.rmSync(dir, { recursive: true, force: true });
    scenes.push(name);
    return evaluate('adVideoNext()');
  }
  fs.writeFileSync(path.join(dir, 'frames.json'), JSON.stringify({ fps: FPS, dpr: VIEW.dpr, frames }));
  scenes.push(name);
  console.log('찍음', name, total, '프레임');
  await evaluate('adVideoNext()');
}

await send('Runtime.enable');
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: VIEW.w, height: VIEW.h, deviceScaleFactor: VIEW.dpr, mobile: true });
await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
await send('Page.navigate', { url });
const timeout = setTimeout(() => { console.error('시간 초과 — 찍은 장면', scenes); finished(); }, 40 * 60 * 1000);
await done;
clearTimeout(timeout);
console.log(`끝 — ${scenes.join(', ')} → ${OUT}`);
ws.close();
chrome.kill();
server.close();
