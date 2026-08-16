// 국가(flag/countryName)가 비어 있는 기록/유저를 조사한다. 읽기만 하고 아무것도 지우지 않는다.
//   node audit_no_country.mjs           (scripts 디렉터리에서 실행)
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, getDocs } from 'firebase/firestore';

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

const EMPTY_FLAGS = ['', '🏳️', '🏳'];
const isEmptyFlag = (f) => f === undefined || f === null || EMPTY_FLAGS.includes(String(f).trim());
const isEmptyStr = (s) => s === undefined || s === null || String(s).trim() === '';

// ── 유저 목록 ────────────────────────────────────────────────
const usersSnap = await getDocs(collection(db, 'users'));
const users = new Map();
for (const d of usersSnap.docs) users.set(d.id, d.data());

const noFlag = [];
const noCountryName = [];
for (const [uid, u] of users) {
  if (isEmptyFlag(u.flag)) noFlag.push({ uid, ...u });
  if (isEmptyStr(u.countryName)) noCountryName.push({ uid, ...u });
}

const fmt = (u) =>
  `  - ${u.uid}  nickname=${JSON.stringify(u.nickname)}  flag=${JSON.stringify(u.flag)}  ` +
  `countryName=${JSON.stringify(u.countryName)}  ` +
  `createdAt=${u.createdAt?.toDate?.().toISOString?.() ?? u.createdAt ?? '-'}`;

console.log(`=== users: ${users.size}명 ===`);
console.log(`\n[A] flag 자체가 없는 유저: ${noFlag.length}명`);
noFlag.forEach((u) => console.log(fmt(u)));

console.log(`\n[B] countryName이 없는 유저(백오피스에서 '-'로 보임): ${noCountryName.length}명`);
noCountryName.forEach((u) => console.log(fmt(u)));

// ── 기록 조사 ────────────────────────────────────────────────
const mapsSnap = await getDocs(collection(db, 'maps'));
const mapIds = mapsSnap.docs.map((d) => d.id);

const targets = [];
let total = 0;
for (const mapId of mapIds) {
  const recSnap = await getDocs(collection(db, 'maps', mapId, 'records'));
  total += recSnap.size;
  for (const d of recSnap.docs) {
    const r = d.data();
    const user = r.userId ? users.get(r.userId) : undefined;
    // 리더보드는 record.flag를 쓰고, 비어 있으면 users의 값으로 보강된다.
    const effective = !isEmptyFlag(r.flag) ? r.flag : user?.flag;
    if (isEmptyFlag(effective)) {
      targets.push({
        path: `maps/${mapId}/records/${d.id}`,
        nickname: user?.nickname ?? r.nickname ?? '(unknown)',
        survivalTime: r.survivalTime,
        userId: r.userId ?? '(none)',
        timestamp: r.timestamp?.toDate?.().toISOString?.() ?? '-',
      });
    }
  }
}

console.log(`\n=== 기록: 전체 ${total}건 / 국가 없는 기록 ${targets.length}건 ===`);
for (const t of targets) {
  console.log(
    `  - ${t.path}  nickname=${JSON.stringify(t.nickname)} time=${t.survivalTime} userId=${t.userId} at=${t.timestamp}`
  );
}

console.log('\n--- 삭제 대상 경로 ---');
for (const t of targets) console.log(t.path);
process.exit(0);
