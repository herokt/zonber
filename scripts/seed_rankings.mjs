import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, addDoc, setDoc, doc, Timestamp, increment } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyAvfXaZzncy2xMXzwg1-F1oDDWIriti24w',
  appId: '1:682278346224:web:a442a9f3b5e5fcd98bd135',
  messagingSenderId: '682278346224',
  projectId: 'stayzone-88364',
  authDomain: 'stayzone-88364.firebaseapp.com',
  storageBucket: 'stayzone-88364.firebasestorage.app',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// ─── 더미 유저 풀 ───────────────────────────────────────────────────
const USERS = [
  { nickname: 'ShadowX',    flag: '🇰🇷' },
  { nickname: 'NeonRacer',  flag: '🇺🇸' },
  { nickname: 'BlitzKing',  flag: '🇯🇵' },
  { nickname: 'ZeroGhost',  flag: '🇬🇧' },
  { nickname: 'ArcStrike',  flag: '🇩🇪' },
  { nickname: 'IceVortex',  flag: '🇫🇷' },
  { nickname: 'PixelWolf',  flag: '🇧🇷' },
  { nickname: 'CyberAce',   flag: '🇨🇳' },
  { nickname: 'StarDrift',  flag: '🇨🇦' },
  { nickname: 'VoidPulse',  flag: '🇦🇺' },
  { nickname: 'ThunderMk',  flag: '🇲🇽' },
  { nickname: 'PlasmaBit',  flag: '🇮🇳' },
  { nickname: 'LunarFox',   flag: '🇸🇪' },
  { nickname: 'QuantumZ',   flag: '🇳🇱' },
  { nickname: 'DarkNebula', flag: '🇪🇸' },
  { nickname: 'RedComet',   flag: '🇰🇷' },
  { nickname: 'NanoBlast',  flag: '🇹🇼' },
  { nickname: 'FrostByte',  flag: '🇵🇱' },
  { nickname: 'OrbitX',     flag: '🇸🇬' },
  { nickname: 'WarpDrive',  flag: '🇦🇷' },
];

// ─── 스테이지별 시간 범위 (초) ──────────────────────────────────────
// zone_1: 쉬움 → 전반적으로 긴 생존 가능
// zone_2: 중간
// zone_5: 어려움 → 짧은 시간 중심
const STAGES = [
  {
    id: 'zone_1_classic',
    label: 'Zone 1 (Classic)',
    count: 25,
    timeRange: [15, 180],   // 15초 ~ 3분
  },
  {
    id: 'zone_2_obstacles',
    label: 'Zone 2 (Obstacles)',
    count: 20,
    timeRange: [8, 120],    // 8초 ~ 2분
  },
  {
    id: 'zone_5_maze',
    label: 'Zone 3 (Maze)',
    count: 15,
    timeRange: [5, 90],     // 5초 ~ 1.5분
  },
];

// ─── 유틸 ───────────────────────────────────────────────────────────
function randomFloat(min, max) {
  return Math.random() * (max - min) + min;
}

// 분포를 자연스럽게: 낮은 시간 대역에 많이, 높은 시간 대역에 적게
function weightedTime(min, max) {
  // sqrt 를 이용해 낮은 쪽에 가중치
  const t = Math.random();
  return min + (max - min) * (t * t);
}

// 랜덤 과거 타임스탬프 (최근 30일 내)
function randomTimestamp() {
  const now = Date.now();
  const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
  return Timestamp.fromMillis(now - Math.random() * thirtyDaysMs);
}

function pickUser(index) {
  return USERS[index % USERS.length];
}

// ─── 메인 ───────────────────────────────────────────────────────────
async function seed() {
  console.log('🔐 익명 로그인 중...');
  await signInAnonymously(auth);
  console.log('✅ 로그인 성공\n');

  for (const stage of STAGES) {
    console.log(`📊 [${stage.label}] — ${stage.count}개 레코드 삽입 중...`);
    let inserted = 0;

    // 유저 인덱스를 섞어서 배분
    const shuffledIndices = Array.from({ length: stage.count }, (_, i) => i);

    for (let i = 0; i < stage.count; i++) {
      const user = pickUser(shuffledIndices[i]);
      const survivalTime = parseFloat(weightedTime(...stage.timeRange).toFixed(2));
      const timestamp = randomTimestamp();

      try {
        await addDoc(collection(db, 'maps', stage.id, 'records'), {
          nickname: user.nickname,
          flag: user.flag,
          survivalTime,
          timestamp,
        });
        inserted++;
        process.stdout.write(`  → ${user.nickname} (${user.flag}) : ${survivalTime}s\n`);
      } catch (e) {
        console.error(`  ❌ 오류: ${e.message}`);
      }
    }

    // playCount 업데이트
    await setDoc(doc(db, 'maps', stage.id), { playCount: increment(inserted) }, { merge: true });
    console.log(`  ✅ ${inserted}개 완료, playCount +${inserted}\n`);
  }

  console.log('🎉 시딩 완료!');
  process.exit(0);
}

seed().catch(e => {
  console.error('❌ 오류:', e);
  process.exit(1);
});
