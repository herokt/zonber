import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, getDocs, deleteDoc, doc } from 'firebase/firestore';

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

const toDelete = ['zone_2_prism', 'zone_3_chaos'];

for (const mapId of toDelete) {
  // Delete all records subcollection first
  const recordsSnap = await getDocs(collection(db, 'maps', mapId, 'records'));
  for (const r of recordsSnap.docs) {
    await deleteDoc(r.ref);
  }
  console.log(`  records 삭제: ${recordsSnap.size}건 (${mapId})`);

  // Delete the map doc itself
  await deleteDoc(doc(db, 'maps', mapId));
  console.log(`  maps/${mapId} 삭제 완료`);
}

console.log('완료');
process.exit(0);
