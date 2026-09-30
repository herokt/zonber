// ─────────────────────────────────────────────────────────────
// 친구 — docs/FRIENDS.md. 상대 목록에 나를 넣는 일은 앱에서 안전하게 못 해서 여기서 쓴다.
//   users/{uid}/friends/{친구uid}  {since, via}   양쪽에 한 건씩
//   friend_requests/{from_to}       {from, to, status, at, expiresAt, decidedAt}
// 앱이 부르는 함수(callable)는 결과를 { result: '코드' } 로 돌려준다 — lib/friends.dart FriendResult 와 같은 코드.
// 로그인 안 한 요청만 에러(unauthenticated)로 막는다.
// ─────────────────────────────────────────────────────────────
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const L = require('./logic');
const { notifyUser } = require('./notify');

const REGION = 'us-central1';
const db = () => getFirestore();
const users = () => db().collection('users');
const requests = () => db().collection('friend_requests');
const friendRef = (a, b) => users().doc(a).collection('friends').doc(b);
const reqRef = (from, to) => requests().doc(L.requestId(from, to));

/// 로그인한 회원 uid — 게스트(로그인 안 함)·익명은 막는다
function member(req) {
  const a = req.auth;
  if (!a || !a.uid || (a.token && a.token.firebase && a.token.firebase.sign_in_provider === 'anonymous')) {
    throw new HttpsError('unauthenticated', 'login required');
  }
  return a.uid;
}

async function nickname(uid) {
  const d = await users().doc(uid).get();
  return (d.exists && d.get('nickname')) || '';
}

async function friendCount(uid) {
  const c = await users().doc(uid).collection('friends').count().get();
  return c.data().count;
}

async function isFriend(a, b) {
  return (await friendRef(a, b).get()).exists;
}

/// 둘을 친구로 — 양쪽 목록 + 둘 사이 요청은 지운다
async function makeFriends(a, b, via) {
  const now = FieldValue.serverTimestamp();
  const batch = db().batch();
  batch.set(friendRef(a, b), { since: now, via });
  batch.set(friendRef(b, a), { since: now, via });
  batch.delete(reqRef(a, b));
  batch.delete(reqRef(b, a));
  await batch.commit();
}

/// 둘 다 친구 수 한도 안인가 — 아니면 결과 코드
async function limitProblem(me, other) {
  if ((await friendCount(me)) >= L.MAX_FRIENDS) return 'my_limit';
  if ((await friendCount(other)) >= L.MAX_FRIENDS) return 'their_limit';
  return null;
}

const expired = (d) => {
  const e = d.get('expiresAt');
  return !e || e.toMillis() < Date.now();
};

// ── 코드로 바로 친구 ──
exports.addFriendByCode = onCall({ region: REGION }, async (req) => {
  const me = member(req);
  const code = L.normalizeCode(req.data && req.data.code);
  if (!code) return { result: 'not_found' };
  const owner = (await db().collection('friend_codes').doc(code).get()).get('uid');
  if (!owner) return { result: 'not_found' };
  if (owner === me) return { result: 'self' };
  if (await isFriend(me, owner)) return { result: 'already', uid: owner };
  const problem = await limitProblem(me, owner);
  if (problem) return { result: problem };
  await makeFriends(me, owner, 'code');
  await notifyUser(owner, 'friend_added', { name: await nickname(me) }).catch((e) => logger.warn('notify', e));
  return { result: 'added', uid: owner };
});

// ── 친구 요청 ──
exports.sendFriendRequest = onCall({ region: REGION }, async (req) => {
  const me = member(req);
  const to = String((req.data && req.data.uid) || '');
  if (!to) return { result: 'not_found' };
  if (to === me) return { result: 'self' };
  const target = await users().doc(to).get();
  if (!target.exists || !target.get('nickname')) return { result: 'not_found' };
  if (await isFriend(me, to)) return { result: 'already' };

  // 상대가 먼저 보낸 요청이 있으면 — 서로 원한 것이니 바로 친구
  const reverse = await reqRef(to, me).get();
  if (reverse.exists && reverse.get('status') === 'pending' && !expired(reverse)) {
    const problem = await limitProblem(me, to);
    if (problem) return { result: problem };
    await makeFriends(me, to, 'request');
    await notifyUser(to, 'friend_accepted', { name: await nickname(me) }).catch((e) => logger.warn('notify', e));
    return { result: 'added' };
  }

  const mine = await reqRef(me, to).get();
  if (mine.exists) {
    if (mine.get('status') === 'pending' && !expired(mine)) return { result: 'requested' };
    const decided = mine.get('decidedAt');
    if (mine.get('status') === 'declined' && decided && Date.now() - decided.toMillis() < L.COOLDOWN_DAYS * L.DAY_MS) {
      return { result: 'cooldown' };
    }
  }

  // 대기 중인 보낸 요청 수 — 기한 지난 것은 이참에 지운다
  const pending = await requests().where('from', '==', me).where('status', '==', 'pending').limit(L.MAX_PENDING + 20).get();
  const stale = pending.docs.filter(expired);
  if (stale.length) {
    const b = db().batch();
    for (const d of stale) b.delete(d.ref);
    await b.commit();
  }
  if (pending.size - stale.length >= L.MAX_PENDING) return { result: 'too_many' };
  if ((await friendCount(me)) >= L.MAX_FRIENDS) return { result: 'my_limit' };

  await reqRef(me, to).set({
    from: me,
    to,
    status: 'pending',
    at: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + L.REQUEST_DAYS * L.DAY_MS),
  });
  await notifyUser(to, 'friend_request', { name: await nickname(me) }).catch((e) => logger.warn('notify', e));
  return { result: 'requested' };
});

// ── 받은 요청에 답하기 ──
exports.answerFriendRequest = onCall({ region: REGION }, async (req) => {
  const me = member(req);
  const from = String((req.data && req.data.uid) || '');
  const accept = !!(req.data && req.data.accept);
  const ref = reqRef(from, me);
  const r = await ref.get();
  if (!r.exists || r.get('status') !== 'pending') return { result: 'not_found' };
  if (expired(r)) {
    await ref.delete();
    return { result: 'expired' };
  }
  if (!accept) {
    await ref.update({ status: 'declined', decidedAt: FieldValue.serverTimestamp() });
    return { result: 'declined' };
  }
  const problem = await limitProblem(me, from);
  if (problem) return { result: problem };
  await makeFriends(me, from, 'request');
  await notifyUser(from, 'friend_accepted', { name: await nickname(me) }).catch((e) => logger.warn('notify', e));
  return { result: 'added' };
});

// ── 친구 끊기(양쪽) ──
exports.removeFriend = onCall({ region: REGION }, async (req) => {
  const me = member(req);
  const other = String((req.data && req.data.uid) || '');
  if (!other || other === me) return { result: 'not_found' };
  const b = db().batch();
  b.delete(friendRef(me, other));
  b.delete(friendRef(other, me));
  await b.commit();
  return { result: 'removed' };
});

// ── 친구 기록 알림 — 새 랭킹 기록이 친구 최고 기록을 처음 넘었으면 ──
// 친구 최고는 users/{친구}.bestTimes[존](앱이 올리는 개인 최고), 내 이전 최고는 기록 컬렉션에서(이번 기록 바로 아래)
exports.onRecordCreated = onDocumentCreated({ document: 'maps/{mapId}/records/{recordId}', region: REGION, retry: false }, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const rec = snap.data();
  const uid = String(rec.userId || '');
  const time = Number(rec.survivalTime || 0);
  const mapId = event.params.mapId;
  if (!uid || !(time > 0) || !L.ZONES[mapId]) return;

  const friends = await users().doc(uid).collection('friends').get();
  if (friends.empty) return;

  const top = await snap.ref.parent.where('userId', '==', uid).orderBy('survivalTime', 'desc').limit(2).get();
  if (!top.docs.length || top.docs[0].id !== snap.id) return; // 내 최고 기록이 아니면 누구도 새로 넘지 않았다
  const prev = top.docs.length > 1 ? Number(top.docs[1].get('survivalTime') || 0) : 0;

  const name = String(rec.nickname || (await nickname(uid)) || '?');
  const today = L.kstDay(Date.now());
  for (const f of friends.docs) {
    const fid = f.id;
    const u = await users().doc(fid).get();
    const best = u.exists ? Number(((u.get('bestTimes') || {})[mapId]) || 0) : 0;
    if (!L.crossed(prev, time, best)) continue;
    const stateRef = db().collection('push_state').doc(fid);
    const ok = await db().runTransaction(async (tx) => {
      const s = await tx.get(stateRef);
      const next = L.allowBeat(s.exists ? s.get('beat') : null, uid, today);
      if (!next) return false;
      tx.set(stateRef, { beat: next }, { merge: true });
      return true;
    });
    if (ok) await notifyUser(fid, 'friend_beat', { name, zone: mapId, time: best }).catch((e) => logger.warn('notify', e));
  }
});

// ── 탈퇴 정리 — 친구(양쪽) · 요청 · 기기 · 알림 상태 ──
exports.onUserDeleted = onDocumentDeleted({ document: 'users/{uid}', region: REGION, retry: false }, async (event) => {
  const uid = event.params.uid;
  const refs = [];
  const friends = await users().doc(uid).collection('friends').get();
  for (const f of friends.docs) {
    refs.push(f.ref, friendRef(f.id, uid));
  }
  const devices = await users().doc(uid).collection('devices').get();
  for (const d of devices.docs) refs.push(d.ref);
  for (const field of ['from', 'to']) {
    const q = await requests().where(field, '==', uid).get();
    for (const d of q.docs) refs.push(d.ref);
  }
  refs.push(db().collection('push_state').doc(uid));
  for (let i = 0; i < refs.length; i += 400) {
    const b = db().batch();
    for (const r of refs.slice(i, i + 400)) b.delete(r);
    await b.commit();
  }
  logger.info('user cleanup', { uid, deleted: refs.length });
});
