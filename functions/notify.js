// ─────────────────────────────────────────────────────────────
// 한 사람에게 알림 — users/{uid}/devices 의 기기 토큰으로(친구 알림). 문구는 기기 언어로(logic.js TEXTS).
// 설정 › 친구 알림을 끈 기기(friend == false)에는 보내지 않는다. 없어진 토큰은 지운다.
// 이벤트·소식 푸시(토픽)는 index.js sendPushCampaign — 여기와 다르다.
// ─────────────────────────────────────────────────────────────
const logger = require('firebase-functions/logger');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { textFor } = require('./logic');

// Android 알림 채널 — 앱이 만든다(lib/services/reminder_service.dart friendsChannelId)
const CHANNEL = 'friends';

const DEAD_TOKEN = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/// [kind] 알림을 [uid] 의 기기 전부에. 보낸 기기 수
async function notifyUser(uid, kind, params) {
  const devices = await getFirestore().collection('users').doc(uid).collection('devices').get();
  let sent = 0;
  for (const d of devices.docs) {
    const dev = d.data();
    if (dev.friend === false || !dev.token) continue;
    const text = textFor(kind, dev.lang, params);
    if (!text) continue;
    try {
      await getMessaging().send({
        token: dev.token,
        notification: { title: text[0], body: text[1] },
        data: { kind, zone: String((params && params.zone) || '') },
        android: { priority: 'high', notification: { channelId: CHANNEL, icon: 'ic_notification', color: '#37E0FF' } },
        apns: { payload: { aps: { sound: 'default' } } },
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

module.exports = { notifyUser, CHANNEL };
