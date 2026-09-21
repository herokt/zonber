// 스테이지 1(갤럭시) 랭킹을 앱과 같은 방식(올해 기록 → 시간순)으로 읽어 상위 10개를 보여 준다. 읽기만 한다.
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, getDocs, query, where, limit, Timestamp } from 'firebase/firestore';
const app = initializeApp({
  apiKey: 'AIzaSyAvfXaZzncy2xMXzwg1-F1oDDWIriti24w', appId: '1:682278346224:web:a442a9f3b5e5fcd98bd135',
  messagingSenderId: '682278346224', projectId: 'stayzone-88364', authDomain: 'stayzone-88364.firebaseapp.com',
});
const db = getFirestore(app);
await signInAnonymously(getAuth(app));
const col = collection(db, 'maps', 'cyber', 'records');
const all = await getDocs(col);
const year = new Date(new Date().getFullYear(), 0, 1);
const snap = await getDocs(query(col, where('timestamp', '>=', Timestamp.fromDate(year)), limit(3000)));
const recs = snap.docs.map((d) => d.data()).sort((a, b) => b.survivalTime - a.survivalTime);
console.log(`cyber 전체 ${all.size}건 · 올해 ${snap.size}건`);
const src = {};
for (const d of all.docs) { const k = d.data().legacyMapId ?? 'cyber(신규)'; src[k] = (src[k] ?? 0) + 1; }
console.log(src);
recs.slice(0, 10).forEach((r, i) => console.log(`${i + 1}. ${r.nickname ?? '(userId ' + (r.userId ?? '').slice(0, 6) + ')'} ${r.flag ?? ''} ${r.survivalTime.toFixed(1)}s  ${r.legacyMapId ?? ''}`));
process.exit(0);
