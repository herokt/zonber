// ─────────────────────────────────────────────────────────────
// 백오피스 관리 함수 — 관리자(ADMIN_EMAILS, 이메일 인증)만 부른다. 백오피스 유저 목록의 일괄 삭제 · 랭킹 정리.
//
// adminDeleteUsers({uids})  — 계정을 통째로 지운다(한 번에 50명까지). 앱의 탈퇴(auth_service.dart deleteAccount)보다 넓다:
//   로그인 계정(Firebase Auth) · 랭킹 기록(maps/*/records) · users/{uid} 와 그 아래 전부(runs · private · promos · codes ·
//   inbox · inbox_state · devices · friends) · 친구 목록의 반대쪽 · 친구 코드 · 친구 코드 입력 기록 · 친구 요청 · 알림 횟수
// adminOrphanRecords({apply}) — 주인 없는 랭킹 기록(userId 없음 · 유저 문서 없음). apply 가 아니면 세기만 한다
// ─────────────────────────────────────────────────────────────
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const REGION = 'us-central1';
// lib/admin_emails.dart · firestore.rules isAdmin() 과 같은 목록
const ADMIN_EMAILS = ['herokt851103@gmail.com'];
const MAPS = ['cyber', 'dodgeball', 'keeper'];
const MAX_UIDS = 50;
const db = () => getFirestore();

function admin(req) {
  const t = req.auth && req.auth.token;
  if (!t || t.email_verified !== true || !ADMIN_EMAILS.includes(String(t.email || '').toLowerCase())) {
    throw new HttpsError('permission-denied', 'admin only');
  }
  return String(t.email);
}

async function deleteRefs(refs) {
  for (let i = 0; i < refs.length; i += 400) {
    const b = db().batch();
    for (const r of refs.slice(i, i + 400)) b.delete(r);
    await b.commit();
  }
}

/// 한 사람 지우기 — 지운 랭킹 기록 수
async function deleteOne(uid) {
  const userRef = db().collection('users').doc(uid);
  const refs = [];
  // 랭킹 기록
  let records = 0;
  for (const m of MAPS) {
    const q = await db().collection('maps').doc(m).collection('records').where('userId', '==', uid).get();
    records += q.size;
    for (const d of q.docs) refs.push(d.ref);
  }
  // 친구 목록의 반대쪽(내 friends 를 지우기 전에 읽는다)
  const friends = await userRef.collection('friends').get();
  for (const f of friends.docs) refs.push(db().collection('users').doc(f.id).collection('friends').doc(uid));
  // 친구 코드 · 입력 기록 · 요청 · 알림 횟수
  const codes = await db().collection('friend_codes').where('uid', '==', uid).get();
  for (const d of codes.docs) refs.push(d.ref);
  refs.push(db().collection('friend_invites').doc(uid));
  for (const field of ['from', 'to']) {
    const q = await db().collection('friend_requests').where(field, '==', uid).get();
    for (const d of q.docs) refs.push(d.ref);
  }
  refs.push(db().collection('push_state').doc(uid));
  await deleteRefs(refs);
  // users/{uid} 와 그 아래 전부
  await db().recursiveDelete(userRef);
  // 로그인 계정
  try {
    await getAuth().deleteUser(uid);
  } catch (e) {
    if (!(e && e.code === 'auth/user-not-found')) throw e;
  }
  return records;
}

exports.adminDeleteUsers = onCall({ region: REGION, timeoutSeconds: 540 }, async (req) => {
  const by = admin(req);
  const uids = Array.isArray(req.data && req.data.uids) ? [...new Set(req.data.uids.map(String).filter(Boolean))] : [];
  if (!uids.length) return { results: {} };
  if (uids.length > MAX_UIDS) throw new HttpsError('invalid-argument', `max ${MAX_UIDS}`);
  const results = {};
  let records = 0;
  for (const uid of uids) {
    try {
      records += await deleteOne(uid);
      results[uid] = 'ok';
    } catch (e) {
      results[uid] = `error: ${e && e.message ? e.message : e}`;
      logger.error('admin delete failed', { uid, error: String(e) });
    }
  }
  logger.info('admin deleted users', { by, count: uids.length, records, results });
  return { results, records };
});

exports.adminOrphanRecords = onCall({ region: REGION, timeoutSeconds: 540 }, async (req) => {
  const by = admin(req);
  const apply = !!(req.data && req.data.apply);
  const orphans = [];
  const byName = {};
  const userExists = new Map();
  for (const m of MAPS) {
    const snap = await db().collection('maps').doc(m).collection('records').get();
    for (const d of snap.docs) {
      const uid = String(d.get('userId') || '');
      let orphan = !uid;
      if (uid) {
        if (!userExists.has(uid)) userExists.set(uid, (await db().collection('users').doc(uid).get()).exists);
        orphan = !userExists.get(uid);
      }
      if (!orphan) continue;
      orphans.push(d.ref);
      const k = `${m} · ${d.get('nickname') || '?'}`;
      byName[k] = (byName[k] || 0) + 1;
    }
  }
  if (apply && orphans.length) await deleteRefs(orphans);
  const top = Object.entries(byName)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 30)
    .map(([name, n]) => ({ name, n }));
  logger.info('admin orphan records', { by, apply, count: orphans.length });
  return { count: orphans.length, people: Object.keys(byName).length, top, deleted: apply ? orphans.length : 0 };
});
