// 더미 아트 생성 — ffmpeg(drawtext) 로 단색 + 라벨 PNG 를 만든다.
// 실아트가 같은 파일명으로 들어오면 코드 수정 없이 교체된다 (docs/RESOURCES.md).
//   node scripts/make_dummy_assets.mjs          (없는 파일만)
//   node scripts/make_dummy_assets.mjs --force  (전부 덮어씀 — 실아트도 지워짐)
import { execFileSync } from 'node:child_process';
import { mkdirSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const out = resolve('assets/images/worlds');
mkdirSync(out, { recursive: true });

const FONT = 'C\\:/Windows/Fonts/arial.ttf';
const stages = {
  // 파일명은 내부 id(cyber 등) 유지, 라벨만 표시 이름
  cyber: { floor: '0x141A33', accent: '0x0A9DBD', label: 'GALAXY' },
  dodgeball: { floor: '0xE9CFA6', accent: '0xE5484D', label: 'DODGEBALL' },
  keeper: { floor: '0xA8DC8F', accent: '0x2F6FE4', label: 'GOALKEEPER' },
};

// 이미 있는 파일(실아트)은 덮어쓰지 않는다. 전부 다시 만들려면 --force
const force = process.argv.includes('--force');

function png(name, w, h, color, label, fontSize, dark = false) {
  const file = resolve(out, name);
  if (!force && existsSync(file)) { console.log('skip (exists)', name); return; }
  const text = label.replace(/:/g, '\\:').replace(/'/g, '');
  const vf =
    `drawtext=fontfile='${FONT}':text='${text}':fontcolor=${dark ? '0xFFFFFF' : '0x0F172A'}@0.75:fontsize=${fontSize}:` +
    `x=(w-text_w)/2:y=(h-text_h)/2,` +
    `drawbox=x=2:y=2:w=iw-4:h=ih-4:color=${dark ? '0xFFFFFF' : '0x0F172A'}@0.25:t=2`;
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'lavfi', '-i', `color=c=${color}:s=${w}x${h}`,
    '-frames:v', '1', '-vf', vf, file]);
  console.log('wrote', name);
}

for (const [id, c] of Object.entries(stages)) {
  const up = c.label;
  png(`${id}_hero.png`, 684, 360, c.floor, `${up} HERO 684x360 (dummy)`, 34, id === 'cyber');
  png(`${id}_bg.png`, 480, 768, c.floor, `${up} BG 480x768 (dummy)`, 28, id === 'cyber');
  png(`icon_${id}.png`, 64, 64, c.accent, up.slice(0, 2), 20);
}
png('keeper_goal.png', 160, 160, '0x4C8DFF', 'GOAL 160 (dummy)', 16);
png('ball_cyber.png', 32, 32, '0xD32F2F', 'C', 14);
png('ball_dodgeball.png', 48, 48, '0xFF5A4E', 'DB', 16);
png('ball_dodgeball_fast.png', 48, 48, '0xF5C542', 'DF', 16);
png('ball_keeper.png', 48, 48, '0xF2F4F8', 'K', 16);
png('ball_keeper_curve.png', 48, 48, '0xF5C542', 'KC', 16);
console.log('done →', out, existsSync(out));
