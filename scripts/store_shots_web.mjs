// 스토어 스크린샷 — 기기 없이 PC Chrome(헤드리스)으로 찍는다(2026-10-12).
//   flutter build web --release --dart-define=STORE_SHOT=true --output build/web_storeshot
//   node scripts/store_shots_web.mjs            # 휴대폰 화면 → build/store_shots/{언어}/{이름}.png
//   node scripts/store_shots_web.mjs --ipad     # 4:3 → build/store_shots_ipad/
// 앱(스크린샷 모드)이 콘솔에 `STORESHOT <언어>/<이름>` 을 찍는 순간 화면을 캡처한다(scripts/store_shots.sh 와 같은 약속).
// 그다음 합성은 그대로: node scripts/compose_store_shots.mjs · node scripts/compose_ios_shots.mjs
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { spawn } from 'node:child_process';

const ipad = process.argv.includes('--ipad');
const WEB = path.resolve('build/web_storeshot');
const OUT = path.resolve(ipad ? 'build/store_shots_ipad' : 'build/store_shots');
// 휴대폰 = 412×892 @3 (1236×2676, 19.5:9) · iPad = 768×1024 @2.6875 (2064×2752)
const VIEW = ipad ? { w: 768, h: 1024, dpr: 2.6875, mobile: false } : { w: 412, h: 892, dpr: 3, mobile: true };
const CHROME = ['C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe'].find((p) => fs.existsSync(p));
if (!CHROME) throw new Error('Chrome 이 없다');

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.wav': 'audio/wav', '.mp3': 'audio/mpeg', '.css': 'text/css' };
const server = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(WEB, p);
  if (!f.startsWith(WEB) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': MIME[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
}).listen(0, '127.0.0.1');
await new Promise((r) => server.once('listening', r));
const url = `http://127.0.0.1:${server.address().port}/`;

const prof = fs.mkdtempSync(path.join(process.env.TEMP || '/tmp', 'zshot-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${prof}`, '--no-first-run', '--autoplay-policy=no-user-gesture-required', '--hide-scrollbars', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
const wsUrl = await new Promise((res, rej) => {
  let buf = '';
  chrome.stderr.on('data', (d) => { buf += d; const m = buf.match(/ws:\/\/[^\s]+/); if (m) res(m[0]); });
  setTimeout(() => rej(new Error('Chrome 디버그 주소를 못 받았다')), 20000);
});
const port = new URL(wsUrl).port;
const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = targets.find((t) => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r));
let id = 0;
const waits = new Map();
const send = (method, params = {}) => new Promise((res) => { const i = ++id; waits.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
const queue = [];
let finished;
const done = new Promise((r) => (finished = r));
ws.addEventListener('message', async (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && waits.has(m.id)) { waits.get(m.id)(m.result); waits.delete(m.id); return; }
  if (m.method === 'Runtime.consoleAPICalled') {
    const text = (m.params.args || []).map((a) => a.value ?? '').join(' ');
    const i = text.indexOf('STORESHOT ');
    if (/failed|Error|rror:/.test(text)) console.log('[앱]', text.slice(0, 300));
    if (i < 0) return;
    const name = text.slice(i + 10).trim();
    if (name === 'done') return finished();
    queue.push(name);
    const shot = await send('Page.captureScreenshot', { format: 'png' });
    const f = path.join(OUT, `${name}.png`);
    fs.mkdirSync(path.dirname(f), { recursive: true });
    fs.writeFileSync(f, Buffer.from(shot.data, 'base64'));
    console.log('찍음', name);
  }
});
await send('Runtime.enable');
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: VIEW.w, height: VIEW.h, deviceScaleFactor: VIEW.dpr, mobile: VIEW.mobile });
if (VIEW.mobile) await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
await send('Page.navigate', { url });
const timeout = setTimeout(() => { console.error('시간 초과 — 찍은 것', queue.length); finished(); }, 15 * 60 * 1000);
await done;
clearTimeout(timeout);
console.log(`끝 — ${queue.length}장 → ${OUT}`);
ws.close();
chrome.kill();
server.close();
