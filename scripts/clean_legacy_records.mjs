// 랭킹 기록 정리 — 실제 유저 기록만 남기고, 모두 userId 를 갖게 한다(2026-09-30)
//
// 예전 버전에서 옮겨 온 갤럭시 기록은 userId 가 없어 랭킹에서 눌러도 프로필이 안 떴다.
//   · userId 없는 기록 → 닉네임이 같은 실제 유저(users 문서)가 있으면 그 uid 를 붙인다
//       같은 닉네임이 여럿이면 국기가 같은 사람, 그래도 여럿이면 먼저 가입한 사람(옛 기록의 주인일 가능성이 높다)
//       붙인 기록이 그 유저 프로필 최고 기록(users.bestTimes)보다 좋으면 프로필 최고 기록도 올린다(프로필 카드 = 랭킹)
//   · userId 없는 기록인데 이어지는 유저가 없다 → 지운다(실제 유저가 아니다)
//   · userId 는 있는데 유저 문서가 없다(탈퇴 등) → 지운다
//
//   node scripts/clean_legacy_records.mjs            # 무엇을 바꿀지 보기만(기본)
//   node scripts/clean_legacy_records.mjs --apply    # 백업(scripts/backup_clean_records_*.json) 뒤 반영
//   node scripts/clean_legacy_records.mjs --apply --no-delete   # uid 붙이기·프로필 최고 기록만(지우지 않는다)
// gcloud auth login(프로젝트 소유 계정) 필요. 백업 파일로 되살릴 수 있다(기록 문서 이름 + 필드 원본).
import { execSync } from 'child_process';
import { writeFileSync } from 'fs';

const APPLY = process.argv.includes('--apply');
// --no-delete — uid 붙이기 · 프로필 최고 기록만(지우기는 건너뛴다)
const NO_DELETE = process.argv.includes('--no-delete');
const DB = 'projects/stayzone-88364/databases/(default)';
const base = `https://firestore.googleapis.com/v1/${DB}/documents`;
const token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
const H = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
const MAPS = ['cyber', 'dodgeball', 'keeper'];
const norm = (s) => String(s || '').trim().toLowerCase();

async function listAll(path) {
  let page = '';
  let out = [];
  do {
    const r = await fetch(`${base}/${path}?pageSize=300${page ? `&pageToken=${page}` : ''}`, { headers: H });
    const j = await r.json();
    if (j.error) throw new Error(JSON.stringify(j.error));
    out = out.concat(j.documents || []);
    page = j.nextPageToken || '';
  } while (page);
  return out;
}

// 실제 유저 — users 문서(가입한 회원). 닉네임 → [{uid, flag}]
const users = await listAll('users');
const userIds = new Set(users.map((u) => u.name.split('/').pop()));
const byNick = new Map();
for (const u of users) {
  const nick = norm(u.fields?.nickname?.stringValue);
  if (!nick) continue;
  if (!byNick.has(nick)) byNick.set(nick, []);
  byNick.get(nick).push({
    uid: u.name.split('/').pop(),
    flag: u.fields?.flag?.stringValue || '',
    joined: u.fields?.createdAt?.timestampValue || '9999',
    best: Object.fromEntries(
      Object.entries(u.fields?.bestTimes?.mapValue?.fields || {}).map(([k, v]) => [k, Number(v.doubleValue ?? v.integerValue ?? 0)]),
    ),
  });
}
console.log(`실제 유저 ${users.length}명(닉네임 있음 ${byNick.size})`);

const assign = []; // {name, uid, nick, map}
const remove = []; // {name, why, nick, map}
const unsure = []; // {name, nick, candidates}
const backup = [];
for (const mapId of MAPS) {
  for (const d of await listAll(`maps/${mapId}/records`)) {
    const f = d.fields || {};
    const uid = f.userId?.stringValue || '';
    const nick = f.nickname?.stringValue || '';
    if (uid) {
      if (!userIds.has(uid)) {
        remove.push({ name: d.name, why: '유저 문서 없음', nick, map: mapId });
        backup.push({ name: d.name, fields: f });
      }
      continue;
    }
    let cands = byNick.get(norm(nick)) || [];
    if (cands.length > 1) {
      const sameFlag = cands.filter((c) => c.flag && c.flag === (f.flag?.stringValue || ''));
      if (sameFlag.length) cands = sameFlag;
    }
    backup.push({ name: d.name, fields: f });
    const time = Number(f.survivalTime?.doubleValue ?? f.survivalTime?.integerValue ?? 0);
    if (cands.length === 0) {
      remove.push({ name: d.name, why: '이어지는 유저 없음', nick, map: mapId });
      continue;
    }
    if (cands.length > 1) {
      cands = [...cands].sort((a, b) => a.joined.localeCompare(b.joined)); // 먼저 가입한 사람
      unsure.push({ name: d.name, nick, candidates: cands.map((c) => c.uid) });
    }
    assign.push({ name: d.name, uid: cands[0].uid, nick, map: mapId, time, best: cands[0].best });
  }
}

const group = (list) => {
  const m = new Map();
  for (const x of list) m.set(`${x.map} ${x.nick}`, (m.get(`${x.map} ${x.nick}`) || 0) + 1);
  return [...m.entries()].sort((a, b) => b[1] - a[1]);
};
console.log(`\n① uid 붙이기 ${assign.length}건 (${group(assign).length}명)`);
for (const [k, n] of group(assign)) console.log(`   ${k} — ${n}건 → ${assign.find((a) => `${a.map} ${a.nick}` === k).uid}`);
console.log(`\n② 지우기 ${remove.length}건 (${group(remove).length}명)`);
for (const [k, n] of group(remove).slice(0, 15)) console.log(`   ${k} — ${n}건`);
if (group(remove).length > 15) console.log(`   … 외 ${group(remove).length - 15}명`);
const whys = remove.reduce((m, r) => ((m[r.why] = (m[r.why] || 0) + 1), m), {});
console.log('   이유:', JSON.stringify(whys));
if (unsure.length) {
  const seen = new Set();
  console.log(`\n③ 같은 닉네임 여러 명 ${unsure.length}건 — 먼저 가입한 사람에게(①에 포함)`);
  for (const u of unsure) {
    if (seen.has(u.nick)) continue;
    seen.add(u.nick);
    console.log(`   ${u.nick} → ${u.candidates[0]} (후보 ${u.candidates.join(', ')})`);
  }
}

if (!APPLY) {
  console.log('\n보기만 했습니다. 반영하려면 --apply');
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const file = `scripts/backup_clean_records_${stamp}.json`;
writeFileSync(file, JSON.stringify(backup, null, 1));
console.log(`\n백업 ${backup.length}건 → ${file}`);

// 프로필 최고 기록 올리기 — 유저·존별로 붙인 기록 중 가장 좋은 것이 지금 값보다 좋을 때만
const raise = new Map(); // `${uid}|${map}` → 시간
for (const a of assign) {
  const k = `${a.uid}|${a.map}`;
  if (a.time > (a.best[a.map] || 0) && a.time > (raise.get(k) || 0)) raise.set(k, a.time);
}
console.log(`프로필 최고 기록 올림 ${raise.size}건`);
const writes = [
  ...assign.map((a) => ({ update: { name: a.name, fields: { userId: { stringValue: a.uid } } }, updateMask: { fieldPaths: ['userId'] }, currentDocument: { exists: true } })),
  ...(NO_DELETE ? [] : remove.map((r) => ({ delete: r.name }))),
  ...[...raise.entries()].map(([k, t]) => {
    const [uid, map] = k.split('|');
    return {
      update: { name: `${DB}/documents/users/${uid}`, fields: { bestTimes: { mapValue: { fields: { [map]: { doubleValue: t } } } } } },
      updateMask: { fieldPaths: [`bestTimes.${map}`] },
      currentDocument: { exists: true },
    };
  }),
];
let ok = 0;
for (let i = 0; i < writes.length; i += 400) {
  const chunk = writes.slice(i, i + 400);
  const r = await fetch(`https://firestore.googleapis.com/v1/${DB}/documents:batchWrite`, { method: 'POST', headers: H, body: JSON.stringify({ writes: chunk }) });
  const j = await r.json();
  if (j.error) throw new Error(JSON.stringify(j.error));
  const failed = (j.status || []).filter((s) => s.code && s.code !== 0);
  ok += chunk.length - failed.length;
  for (const f of failed) console.log('실패', JSON.stringify(f));
}
console.log(`반영 ${ok}/${writes.length}건 (uid 붙임 ${assign.length} · 지움 ${NO_DELETE ? 0 : remove.length} · 프로필 최고 기록 ${raise.size})`);
