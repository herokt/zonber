// 존 체계 이전의 랭킹 기록(zone_1_classic · zone_2_obstacles · zone_5_maze)을
// 스테이지 1(갤럭시, maps/cyber/records)로 **복사**한다. 원본은 건드리지 않는다.
//   gcloud auth login   (프로젝트 소유 계정)
//   node migrate_legacy_to_stage1.mjs         ← 목록·건수만
//   node migrate_legacy_to_stage1.mjs --yes   ← 실제 복사
// 복사본은 같은 문서 id 를 쓰고(다시 돌려도 중복 없음) legacyMapId 필드로 출처를 남긴다.
// timestamp 는 원래 값을 유지하므로 주간/월간/올해 필터도 원래 날짜 기준으로 동작한다.
import { execSync } from 'child_process';

const PROJECT = 'stayzone-88364';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const LEGACY = ['zone_1_classic', 'zone_2_obstacles', 'zone_5_maze'];
const TARGET = 'cyber';
// 정리 대상(이름 미상) — 옮기지 않는다
const SKIP = new Set(['maps/zone_1_classic/records/nL4Rmdz3AGCkY3tLor4U']);
const doIt = process.argv.includes('--yes');

const token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
const headers = { Authorization: `Bearer ${token}`, 'x-goog-user-project': PROJECT, 'Content-Type': 'application/json' };

async function listAll(mapId) {
  const out = [];
  let pageToken = '';
  do {
    const url = `${BASE}/maps/${mapId}/records?pageSize=300${pageToken ? `&pageToken=${pageToken}` : ''}`;
    const j = await (await fetch(url, { headers })).json();
    if (j.error) throw new Error(`${mapId}: ${j.error.status} ${j.error.message}`);
    out.push(...(j.documents ?? []));
    pageToken = j.nextPageToken ?? '';
  } while (pageToken);
  return out;
}

const existing = new Set((await listAll(TARGET)).map((d) => d.name.split('/').pop()));
let copy = 0, skip = 0, dup = 0, fail = 0;
for (const mapId of LEGACY) {
  const docs = await listAll(mapId);
  let n = 0;
  for (const d of docs) {
    const id = d.name.split('/').pop();
    if (SKIP.has(`maps/${mapId}/records/${id}`)) { skip++; continue; }
    if (existing.has(id)) { dup++; continue; }
    n++;
    if (!doIt) continue;
    const fields = { ...d.fields, legacyMapId: { stringValue: mapId } };
    const res = await fetch(`${BASE}/maps/${TARGET}/records/${id}?currentDocument.exists=false`, {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ fields }),
    });
    if (res.ok) { copy++; existing.add(id); } else { fail++; console.log('실패', mapId, id, res.status, await res.text()); }
  }
  console.log(`${mapId}: ${docs.length}건 → 옮길 대상 ${n}건`);
}
console.log(doIt
  ? `\n복사 ${copy}건 · 이미 있음 ${dup}건 · 제외 ${skip}건 · 실패 ${fail}건`
  : `\n(목록만 — 이미 있음 ${dup}건 · 제외 ${skip}건. 복사하려면 --yes)`);
