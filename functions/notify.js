// ─────────────────────────────────────────────────────────────
// 한 사람에게 알림(친구 알림) — ① 알림함에 남기고(users/{uid}/inbox) ② 기기 토큰으로 푸시.
//   알림함은 설정·기기와 상관없이 늘 남는다(앱 알림 페이지 — lib/inbox.dart). 100개를 넘으면 오래된 것부터 지운다.
//   푸시는 설정 › 친구 알림을 끈 기기(friend == false)에는 보내지 않는다. 문구는 기기 언어로(logic.js TEXTS).
//   늦게 도착한 푸시는 버린다(TTL) — 폰이 꺼져 있다 켜져도 지난 알림이 한꺼번에 오지 않게. 알림함에는 남아 있다.
// 이벤트·소식 푸시(토픽)는 index.js sendPushCampaign — 여기와 다르다.
// ─────────────────────────────────────────────────────────────
const logger = require('firebase-functions/logger');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { textFor, FRIEND_TTL_MS, INBOX_MAX } = require('./logic');

// Android 알림 채널 — 앱이 만든다(lib/services/reminder_service.dart friendsChannelId)
const CHANNEL = 'friends';

const DEAD_TOKEN = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/// 알림함에 한 줄 — 앱이 언어에 맞춰 문구를 만든다(kind + 값만 저장)
async function addInbox(uid, kind, params) {
  const col = getFirestore().collection('users').doc(uid).collection('inbox');
  await col.add({
    kind,
    from: String((params && params.from) || ''),
    name: String((params && params.name) || ''),
    zone: String((params && params.zone) || ''),
    time: params && params.time != null ? Number(params.time) : null,
    at: FieldValue.serverTimestamp(),
    read: false,
  });
  // 오래된 것 정리(가끔만 — 100개를 넘었을 때)
  const extra = await col.orderBy('at', 'desc').offset(INBOX_MAX).limit(50).get();
  if (!extra.empty) {
    const b = getFirestore().batch();
    for (const d of extra.docs) b.delete(d.ref);
    await b.commit();
  }
}

/// [kind] 알림을 [uid] 에게 — 알림함 + 기기 전부. 푸시 보낸 기기 수
async function notifyUser(uid, kind, params) {
  await addInbox(uid, kind, params).catch((e) => logger.warn('inbox write failed', { uid, kind, error: String(e) }));
  const devices = await getFirestore().collection('users').doc(uid).collection('devices').get();
  let sent = 0;
  for (const d of devices.docs) {
    const dev = d.data();
    if (dev.friend === false || !dev.token) continue;
    const text = textFor(kind, dev.lang, params);
    if (!text) continue;
    // 같은 종류·같은 친구 알림이 쌓여 있으면 최신 하나만(collapse) · 알림 트레이에서도 덮어쓴다(tag)
    const collapse = `${kind}_${(params && params.from) || ''}`.slice(0, 60);
    try {
      await getMessaging().send({
        token: dev.token,
        notification: { title: text[0], body: text[1] },
        data: { kind, zone: String((params && params.zone) || '') },
        android: {
          priority: 'high',
          ttl: FRIEND_TTL_MS,
          collapseKey: collapse,
          notification: { channelId: CHANNEL, icon: 'ic_notification', color: '#37E0FF', tag: collapse },
        },
        apns: {
          headers: {
            'apns-expiration': String(Math.floor((Date.now() + FRIEND_TTL_MS) / 1000)),
            'apns-collapse-id': collapse,
          },
          payload: { aps: { sound: 'default' } },
        },
      });
      sent++;
    } catch (e) {
      const code = e && e.code;
      if (DEAD_TOKEN.has(code)) {
        await d.ref.delete().catch(() => {});
      } else {
        logger.warn('notify failed', { uid, kind, code, error: String(e && e.message ? e.message : e) });
      }
    }
  }
  return sent;
}

module.exports = { notifyUser, addInbox, CHANNEL };
