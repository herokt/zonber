import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, getDocs, query, where, updateDoc } from 'firebase/firestore';

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

const snap = await getDocs(query(collection(db, 'users'), where('nickname', '==', 'Guest')));

if (snap.empty) {
  console.log('nickname이 Guest인 유저를 찾을 수 없습니다.');
  process.exit(0);
}

let updated = 0;
for (const doc of snap.docs) {
  await updateDoc(doc.ref, { flag: '🇰🇷', countryName: 'South Korea' });
  console.log(`업데이트: ${doc.id}`);
  updated++;
}

console.log(`완료: ${updated}명 업데이트됨`);
process.exit(0);
