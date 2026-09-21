// DB 의 기록 시간을 소수점 셋째 자리로 맞춘다(넷째 자리부터 버림 — 앱의 recordTime 과 같은 규칙).
//   대상: maps/*/records/*.survivalTime · users/*.bestTimes.* · users/*.plates.*.survivalTime
//   gcloud auth login   (프로젝트 소유 계정)
//   node round_records_3dp.mjs         ← 바뀔 건수만 + 백업 파일 생성
//   node round_records_3dp.mjs --yes   ← 실제 수정 (필드만 부분 수정, 문서 삭제 없음)
// 수정 전 값은 backup_round_3dp_<시각>.json 에 남는다. 다시 돌려도 이미 맞춘 값은 건너뛴다.
import { execSync } from 'child_process';
import { writeFileSync } from 'fs';

const PROJECT = 'stayzone-88364';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const doIt = process.argv.includes('--yes');
const token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
const headers = { Authorization: `Bearer ${token}`, 'x-goog-user-project': PROJECT, 'Content-Type': 'application/json' };

/** 셋째 자리까지 버림. 12.345 × 1000 = 12344.999… 오차를 막으려고 1e-6 을 더한다 */
const round3 = (t) => Math.floor(t * 1000 + 1e-6) / 1000;
const num = (v) => (v?.doubleValue ?? (v?.integerValue !== undefined ? Number(v.integerValue) : undefined));

async function listAll(path) {
  const out = [];
  let pageToken = '';
  do {
    const j = await (await fetch(`${BASE}/${path}?pageSize=300${pageToken ? `&pageToken=${pageToken}` : ''}`, { headers })).json();
    if (j.error) throw new Error(`${path}: ${j.error.status} ${j.error.message}`);
    out.push(...(j.documents ?? []));
    pageToken = j.nextPageToken ?? '';
  } while (pageToken);
  return out;
}

const changes = []; // { name, mask, fields, before }

// 1) 랭킹 기록
const maps = (await listAll('maps')).map((d) => d.name.split('/').pop());
for (const m of maps) {
  let n = 0;
  for (const d of await listAll(`maps/${m}/records`)) {
    const t = num(d.fields?.survivalTime);
    if (t === undefined || round3(t) === t) continue;
    n++;
    changes.push({ name: d.name, mask: ['survivalTime'], fields: { survivalTime: { doubleValue: round3(t) } }, before: { survivalTime: t } });
  }
  console.log(`maps/${m}/records: ${n}건 수정 대상`);
}

// 2) 유저 최고 기록 · 명패
let u = 0;
for (const d of await listAll('users')) {
  const f = d.fields ?? {};
  const mask = [], fields = {}, before = {};
  const best = f.bestTimes?.mapValue?.fields;
  if (best) {
    let dirty = false;
    const nb = {};
    for (const [k, v] of Object.entries(best)) {
      const t = num(v);
      if (t !== undefined && round3(t) !== t) { dirty = true; nb[k] = { doubleValue: round3(t) }; } else nb[k] = v;
    }
    if (dirty) { mask.push('bestTimes'); fields.bestTimes = { mapValue: { fields: nb } }; before.bestTimes = best; }
  }
  const plates = f.plates?.mapValue?.fields;
  if (plates) {
    let dirty = false;
    const np = {};
    for (const [k, v] of Object.entries(plates)) {
      const pf = v.mapValue?.fields;
      const t = num(pf?.survivalTime);
      if (pf && t !== undefined && round3(t) !== t) { dirty = true; np[k] = { mapValue: { fields: { ...pf, survivalTime: { doubleValue: round3(t) } } } }; } else np[k] = v;
    }
    if (dirty) { mask.push('plates'); fields.plates = { mapValue: { fields: np } }; before.plates = plates; }
  }
  if (mask.length) { u++; changes.push({ name: d.name, mask, fields, before }); }
}
console.log(`users: ${u}명 수정 대상`);

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
writeFileSync(new URL(`./backup_round_3dp_${stamp}.json`, import.meta.url), JSON.stringify(changes.map(({ name, before }) => ({ name, before })), null, 2));
console.log(`전체 ${changes.length}건 · 백업 backup_round_3dp_${stamp}.json`);
if (!doIt) {
  console.log('(목록만 — 수정하려면 --yes)');
  process.exit(0);
}

let ok = 0, fail = 0;
for (const c of changes) {
  const q = c.mask.map((m) => `updateMask.fieldPaths=${m}`).join('&') + '&currentDocument.exists=true';
  const res = await fetch(`https://firestore.googleapis.com/v1/${c.name}?${q}`, { method: 'PATCH', headers, body: JSON.stringify({ fields: c.fields }) });
  if (res.ok) ok++; else { fail++; console.log('실패', c.name, res.status, await res.text()); }
}
console.log(`수정 ${ok}건 · 실패 ${fail}건`);
