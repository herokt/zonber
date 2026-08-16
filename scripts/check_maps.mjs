import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, getDocs, getCountFromServer } from 'firebase/firestore';

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

const mapsSnap = await getDocs(collection(db, 'maps'));

for (const doc of mapsSnap.docs) {
  const data = doc.data();
  const recordsSnap = await getCountFromServer(collection(db, 'maps', doc.id, 'records'));
  console.log(`[${doc.id}]`);
  console.log(`  playCount: ${data.playCount ?? 0}`);
  console.log(`  records 수: ${recordsSnap.data().count}`);
  console.log(`  기타 필드:`, Object.keys(data).filter(k => k !== 'playCount'));
}

process.exit(0);
