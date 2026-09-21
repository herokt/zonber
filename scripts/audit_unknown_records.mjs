// 랭킹에 "알 수 없음(Unknown)"으로 뜨는 기록을 찾는다. 읽기만 한다.
//   node audit_unknown_records.mjs            (scripts 디렉터리에서 실행)
// 결과는 unknown_records.json 에 저장된다(삭제 스크립트의 입력이자 백업).
//
// 미상 기준 — 랭킹 화면(ranking_system._attachUserInfo)이 이름을 못 찾는 기록:
//   - userId 가 없다
//   - users/{userId} 문서가 없다(탈퇴·삭제된 계정)
//   - 유저 문서와 기록 모두 닉네임이 비었거나 'Unknown'
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, getDocs } from 'firebase/firestore';
import { writeFileSync } from 'fs';

const firebaseConfig = {
  apiKey: 'AIzaSyAvfXaZzncy2xMXzwg1-F1oDDWIriti24w',
  appId: '1:682278346224:web:a442a9f3b5e5fcd98bd135',
  messagingSenderId: '682278346224',
  projectId: 'stayzone-88364',
  authDomain: 'stayzone-88364.firebaseapp.com',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
await signInAnonymously(auth);

const isBlankName = (n) => n === undefined || n === null || String(n).trim() === '' || String(n).trim() === 'Unknown';

const users = new Map();
for (const d of (await getDocs(collection(db, 'users'))).docs) users.set(d.id, d.data());

const mapsSnap = await getDocs(collection(db, 'maps'));
const out = [];
let total = 0;
for (const m of mapsSnap.docs) {
  const recs = await getDocs(collection(db, 'maps', m.id, 'records'));
  let bad = 0;
  for (const r of recs.docs) {
    total++;
    const d = r.data();
    const uid = d.userId ?? '';
    const u = uid ? users.get(uid) : undefined;
    let reason = null;
    if (!uid) reason = 'no_userId';
    else if (!u) reason = 'no_user_doc';
    else if (isBlankName(u.nickname) && isBlankName(d.nickname)) reason = 'no_nickname';
    if (reason) {
      bad++;
      out.push({
        path: `maps/${m.id}/records/${r.id}`,
        reason,
        userId: uid,
        nickname: d.nickname ?? null,
        flag: d.flag ?? null,
        survivalTime: d.survivalTime ?? null,
        timestamp: d.timestamp?.toDate?.().toISOString?.() ?? null,
      });
    }
  }
  console.log(`${m.id}: 기록 ${recs.size}건 중 미상 ${bad}건`);
}
const byReason = out.reduce((a, r) => ((a[r.reason] = (a[r.reason] ?? 0) + 1), a), {});
console.log(`\n전체 ${total}건 중 미상 ${out.length}건`, byReason);
writeFileSync(new URL('./unknown_records.json', import.meta.url), JSON.stringify(out, null, 2));
console.log('→ scripts/unknown_records.json');
process.exit(0);
