import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, getDocs, query, where, orderBy, limit } from 'firebase/firestore';

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

const now = new Date();
const weekStart = new Date(now);
weekStart.setDate(now.getDate() - (now.getDay() || 7) + 1);
weekStart.setHours(0, 0, 0, 0);

const yearStart = new Date(now.getFullYear(), 0, 1);

const mapId = 'zone_1_classic';

// --- Records 현황 ---
const allRecords = await getDocs(collection(db, 'maps', mapId, 'records'));
let hasUserId = 0, noUserId = 0, hasFlag = 0, noFlag = 0;
for (const r of allRecords.docs) {
  const d = r.data();
  d.userId ? hasUserId++ : noUserId++;
  (d.flag && d.flag.length > 0) ? hasFlag++ : noFlag++;
}
console.log(`\n=== ${mapId} records 전체 ${allRecords.size}건 ===`);
console.log(`  userId 있음: ${hasUserId} / 없음: ${noUserId}`);
console.log(`  flag 있음: ${hasFlag} / 없음: ${noFlag}`);

// --- 주간 글로벌 상위 5개 ---
const weekRecords = allRecords.docs
  .map(d => ({ id: d.id, ...d.data() }))
  .filter(r => r.timestamp?.toDate() >= weekStart)
  .sort((a, b) => b.survivalTime - a.survivalTime)
  .slice(0, 5);
console.log(`\n=== 주간 글로벌 Top5 (records 기준) ===`);
weekRecords.forEach((r, i) => {
  console.log(`  ${i+1}. userId:${r.userId?.slice(0,8) ?? 'NONE'} | flag:${r.flag ?? 'NONE'} | nick:${r.nickname ?? 'NONE'} | time:${r.survivalTime}s`);
});

// --- 국내(🇰🇷) 유저 수 ---
const krUsers = await getDocs(query(collection(db, 'users'), where('flag', '==', '🇰🇷')));
console.log(`\n=== 🇰🇷 유저 수: ${krUsers.size}명 ===`);
const krUserIds = krUsers.docs.map(d => d.id);

// 해당 유저들의 주간 records 확인
const krRecords = allRecords.docs
  .map(d => ({ id: d.id, ...d.data() }))
  .filter(r => r.timestamp?.toDate() >= weekStart && krUserIds.includes(r.userId))
  .sort((a, b) => b.survivalTime - a.survivalTime)
  .slice(0, 5);
console.log(`=== 국내 주간 Top5 (userId 매칭) ===`);
krRecords.forEach((r, i) => {
  const user = krUsers.docs.find(u => u.id === r.userId)?.data();
  console.log(`  ${i+1}. ${user?.nickname ?? r.nickname ?? 'NONE'} | time:${r.survivalTime}s`);
});

// 주간 records 중 userId 없는데 flag=🇰🇷 인 구버전 레코드
const legacyKr = allRecords.docs
  .map(d => ({ id: d.id, ...d.data() }))
  .filter(r => r.timestamp?.toDate() >= weekStart && !r.userId && r.flag === '🇰🇷');
console.log(`\n=== 구버전 레코드(userId 없음, flag=🇰🇷) 주간: ${legacyKr.length}건 ===`);
legacyKr.slice(0,3).forEach(r => {
  console.log(`  nickname:${r.nickname} | time:${r.survivalTime}s`);
});

process.exit(0);
