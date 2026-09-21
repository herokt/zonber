// 닉네임·국가 없이 가입이 끊긴 유저(미상)의 기록 + 닉네임이 'Unknown' 인 기록을 찾는다. 읽기만 한다.
//   node find_unknown_user_records.mjs   → unknown_user_records.json (삭제 입력이자 백업)
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, getDocs } from 'firebase/firestore';
import { writeFileSync } from 'fs';

const app = initializeApp({
  apiKey: 'AIzaSyAvfXaZzncy2xMXzwg1-F1oDDWIriti24w',
  appId: '1:682278346224:web:a442a9f3b5e5fcd98bd135',
  messagingSenderId: '682278346224',
  projectId: 'stayzone-88364',
  authDomain: 'stayzone-88364.firebaseapp.com',
});
const db = getFirestore(app);
await signInAnonymously(getAuth(app));

const blank = (v) => v === undefined || v === null || String(v).trim() === '' || String(v).trim() === 'Unknown';
const unknownUsers = new Set();
const allUsers = new Set();
for (const d of (await getDocs(collection(db, 'users'))).docs) {
  const u = d.data();
  allUsers.add(d.id);
  if (blank(u.nickname) || blank(u.flag) || blank(u.countryName)) unknownUsers.add(d.id);
}
const out = [];
for (const m of (await getDocs(collection(db, 'maps'))).docs) {
  for (const r of (await getDocs(collection(db, 'maps', m.id, 'records'))).docs) {
    const d = r.data();
    // 랭킹이 이름을 못 찾는 기록: 미상 유저의 기록, 또는 기록에도 이름이 없고 유저 문서로도 못 찾는 기록
    const byUser = d.userId && unknownUsers.has(d.userId);
    const noName = blank(d.nickname) && (!d.userId || !allUsers.has(d.userId));
    if (byUser || noName) {
      out.push({ path: `maps/${m.id}/records/${r.id}`, reason: byUser ? 'unknown_user' : 'unknown_nickname', data: { ...d, timestamp: d.timestamp?.toDate?.().toISOString?.() ?? null } });
    }
  }
}
console.log(`미상 유저 ${unknownUsers.size}명:`, [...unknownUsers].join(', '));
console.log(`미상 기록 ${out.length}건`);
for (const o of out) console.log(`  ${o.path}  [${o.reason}] nick=${JSON.stringify(o.data.nickname)} t=${o.data.survivalTime} ${o.data.timestamp}`);
writeFileSync(new URL('./unknown_user_records.json', import.meta.url), JSON.stringify({ users: [...unknownUsers], records: out }, null, 2));
process.exit(0);
