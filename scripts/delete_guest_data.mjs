// 게스트(익명 로그인) 데이터 제거 — 2026-09-22 게스트는 로그인 없이 게임 맛보기만 하도록 바뀌면서 예전 버전이 남긴 것을 지운다.
//   gcloud auth login   (프로젝트 소유 계정)
//   node scripts/delete_guest_data.mjs            ← 미리 보기(아무것도 지우지 않는다)
//   node scripts/delete_guest_data.mjs --apply    ← 백업 파일을 쓴 뒤 실제로 지운다
//
// 게스트 판정: Firebase Auth 계정에 로그인 수단(Google·Apple 등)이 하나도 없는 익명 계정의 uid.
//   + users 문서의 loginProvider 가 'Guest' / 'Anonymous' 인데 Auth 계정이 이미 없는 uid(고아 게스트 문서).
//   loginProvider 가 비어 있고 Auth 계정도 없는 문서는 판단할 수 없어 목록만 보여 주고 지우지 않는다.
// 지우는 것: users/{uid} 문서와 하위(private·runs), maps/*/records 중 그 uid 기록, 익명 Auth 계정.
import { execSync } from 'child_process';
import { writeFileSync } from 'fs';

const PROJECT = 'stayzone-88364';
const APPLY = process.argv.includes('--apply');
const token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
const H = { Authorization: `Bearer ${token}`, 'x-goog-user-project': PROJECT, 'Content-Type': 'application/json' };
const DB = `projects/${PROJECT}/databases/(default)`;
const FS = `https://firestore.googleapis.com/v1/${DB}/documents`;
const IDT = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}`;

async function call(url, init = {}) {
  const r = await fetch(url, { headers: H, ...init });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || j.error) throw new Error(`${url} → ${r.status} ${JSON.stringify(j.error ?? j)}`);
  return j;
}

// ── 1. Auth 계정 전부 → 익명(로그인 수단 없음) uid ──
const authUsers = [];
for (let next = ''; ;) {
  const j = await call(`${IDT}/accounts:batchGet?maxResults=1000${next ? `&nextPageToken=${next}` : ''}`);
  authUsers.push(...(j.users ?? []));
  if (!j.nextPageToken) break;
  next = j.nextPageToken;
}
const authById = new Map(authUsers.map((u) => [u.localId, u]));
const anonIds = new Set(authUsers.filter((u) => !(u.providerUserInfo?.length) && !u.email).map((u) => u.localId));

// ── 2. users 문서 전부 ──
const userDocs = [];
for (let next = ''; ;) {
  const j = await call(`${FS}/users?pageSize=300${next ? `&pageToken=${next}` : ''}`);
  userDocs.push(...(j.documents ?? []));
  if (!j.nextPageToken) break;
  next = j.nextPageToken;
}
const idOf = (name) => name.split('/').pop();
const provOf = (d) => (d.fields?.loginProvider?.stringValue ?? '').trim();
const guestIds = new Set(anonIds);
const unknown = [];
for (const d of userDocs) {
  const id = idOf(d.name);
  if (authById.has(id)) continue;
  const p = provOf(d);
  if (p === 'Guest' || p === 'Anonymous') guestIds.add(id);
  else if (p === '') unknown.push(id);
}
const guestDocs = userDocs.filter((d) => guestIds.has(idOf(d.name)));

// ── 3. 하위 문서·랭킹 기록 ──
async function listAll(parent, collectionId) {
  const out = [];
  for (let next = ''; ;) {
    const j = await call(`${FS}/${parent}/${collectionId}?pageSize=300${next ? `&pageToken=${next}` : ''}`);
    out.push(...(j.documents ?? []));
    if (!j.nextPageToken) break;
    next = j.nextPageToken;
  }
  return out;
}
const sub = [];
for (const d of guestDocs) {
  const id = idOf(d.name);
  for (const c of ['private', 'runs']) sub.push(...(await listAll(`users/${id}`, c)));
}
const recRes = await call(`${FS}:runQuery`, {
  method: 'POST',
  body: JSON.stringify({ structuredQuery: { from: [{ collectionId: 'records', allDescendants: true }] } }),
});
const records = recRes.filter((x) => x.document && guestIds.has(x.document.fields?.userId?.stringValue)).map((x) => x.document);

// ── 요약 ──
console.log(`Auth 계정 ${authUsers.length}개 중 익명 ${anonIds.size}개`);
console.log(`users 문서 ${userDocs.length}개 중 게스트 ${guestDocs.length}개 (하위 문서 ${sub.length}개)`);
console.log(`게스트 uid 의 랭킹 기록 ${records.length}개`);
if (unknown.length) console.log(`판단 불가(loginProvider 없음 · Auth 계정 없음, 지우지 않음) ${unknown.length}개: ${unknown.join(', ')}`);
if (!APPLY) {
  console.log('\n미리 보기입니다. 지우려면 --apply 를 붙여 다시 실행하세요.');
  process.exit(0);
}

// ── 백업 후 삭제 ──
const stamp = new Date().toISOString().slice(0, 10).replaceAll('-', '');
const backup = new URL(`./backup_guest_${stamp}.json`, import.meta.url);
writeFileSync(backup, JSON.stringify({ authUsers: authUsers.filter((u) => anonIds.has(u.localId)), userDocs: guestDocs, sub, records }, null, 1));
console.log(`\n백업: ${backup.pathname}`);

const names = [...sub, ...records, ...guestDocs].map((d) => d.name);
for (let i = 0; i < names.length; i += 400) {
  await call(`https://firestore.googleapis.com/v1/${DB}/documents:commit`, {
    method: 'POST',
    body: JSON.stringify({ writes: names.slice(i, i + 400).map((n) => ({ delete: n })) }),
  });
}
console.log(`Firestore 문서 ${names.length}개 삭제`);

const anonList = [...anonIds];
for (let i = 0; i < anonList.length; i += 1000) {
  await call(`${IDT}/accounts:batchDelete`, {
    method: 'POST',
    body: JSON.stringify({ localIds: anonList.slice(i, i + 1000), force: true }),
  });
}
console.log(`익명 Auth 계정 ${anonList.length}개 삭제`);
