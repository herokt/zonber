// ─────────────────────────────────────────────────────────────
// ZONBER 서버 함수
//
// 친구(friends.js) — addFriendByCode · sendFriendRequest · answerFriendRequest · removeFriend(앱이 부름)
//   · onRecordCreated(친구 기록 알림) · onUserDeleted(탈퇴 정리). 알림 보내기는 notify.js, 순수 로직은 logic.js
//
// sendPushCampaign — 백오피스가 push_campaigns/{id} 를 status: pending 으로 만들면 보낸다.
//   언어마다 한 번씩, FCM 토픽 조건으로 — 기기는 언어 토픽 하나(lang_ko …) + member/guest + (관리자) tester 를 구독한다.
//   약속(토픽 이름·대상·문구 규칙)은 lib/push.dart 가 정본이다. 바꾸면 여기도 같이 고친다.
//   결과: status sending → sent(하나라도 보냄) | failed, results.{언어} = "ok <message id>" | "error: …" | "skip: …"
//
// 배포: firebase deploy --only functions  (deploy_admin.bat 이 같이 올린다)
// Firestore 가 nam5(미국 다중 리전)라 트리거 함수는 us-central1 에 둔다.
// ─────────────────────────────────────────────────────────────
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { NEWS_TTL_MS } = require('./logic');

initializeApp();

const LANGS = ['ko', 'en', 'ja', 'zh'];
// lib/admin_emails.dart · firestore.rules isAdmin() 과 같은 목록
const ADMIN_EMAILS = ['herokt851103@gmail.com'];
const AUDIENCE_TOPIC = { all: null, members: 'member', guests: 'guest', testers: 'tester' };

// lib/push.dart PushTopics.condition 과 같다
function condition(lang, audience) {
  const base = `'lang_${lang}' in topics`;
  const extra = AUDIENCE_TOPIC[audience];
  return extra ? `${base} && '${extra}' in topics` : base;
}

// 그 언어 문구 — 비면 영어
function pick(map, lang) {
  const m = map || {};
  return String(m[lang] || '').trim() || String(m.en || '').trim();
}

exports.sendPushCampaign = onDocumentCreated(
  { document: 'push_campaigns/{id}', region: 'us-central1', retry: false },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const ref = snap.ref;
    const c = snap.data();

    // 한 번만 — pending 을 sending 으로 바꾼 쪽만 보낸다
    const mine = await getFirestore().runTransaction(async (tx) => {
      const d = await tx.get(ref);
      if (d.get('status') !== 'pending') return false;
      tx.update(ref, { status: 'sending' });
      return true;
    });
    if (!mine) return;

    if (!ADMIN_EMAILS.includes(String(c.createdBy || '').toLowerCase())) {
      await ref.update({ status: 'failed', results: { all: 'error: not an admin' }, sentAt: FieldValue.serverTimestamp() });
      return;
    }
    const audience = Object.prototype.hasOwnProperty.call(AUDIENCE_TOPIC, c.audience) ? c.audience : 'all';
    const langs = Array.isArray(c.langs) && c.langs.length ? c.langs.filter((l) => LANGS.includes(l)) : LANGS;

    const results = {};
    let sent = 0;
    for (const lang of langs) {
      const title = pick(c.title, lang);
      const body = pick(c.body, lang);
      if (!title || !body) {
        results[lang] = 'skip: no text';
        continue;
      }
      try {
        const id = await getMessaging().send({
          condition: condition(lang, audience),
          notification: { title, body },
          data: { campaign: event.params.id, kind: 'news' },
          // 늦게 도착할 것은 버리고(TTL), 여러 개가 쌓였으면 최신 하나만(collapse) — 지난 소식이 뒤늦게 쏟아지지 않게
          android: {
            priority: 'high',
            ttl: NEWS_TTL_MS,
            collapseKey: 'news',
            notification: { channelId: 'news', icon: 'ic_notification', color: '#37E0FF', tag: 'news' },
          },
          apns: {
            headers: { 'apns-expiration': String(Math.floor((Date.now() + NEWS_TTL_MS) / 1000)), 'apns-collapse-id': 'news' },
            payload: { aps: { sound: 'default' } },
          },
        });
        results[lang] = `ok ${id}`;
        sent++;
      } catch (e) {
        logger.error('push send failed', { id: event.params.id, lang, error: String(e && e.message ? e.message : e) });
        results[lang] = `error: ${e && e.message ? e.message : e}`;
      }
    }
    await ref.update({ status: sent > 0 ? 'sent' : 'failed', results, sentAt: FieldValue.serverTimestamp() });
    // 앱 알림 페이지(이벤트·소식)에 남긴다 — news/{id} 공개 읽기. 앱이 대상·언어로 걸러 보여 준다(lib/inbox.dart)
    if (sent > 0) {
      await getFirestore()
        .collection('news')
        .doc(event.params.id)
        .set({ title: c.title || {}, body: c.body || {}, langs, audience, at: FieldValue.serverTimestamp() })
        .catch((e) => logger.warn('news write failed', { id: event.params.id, error: String(e) }));
    }
    logger.info('push campaign done', { id: event.params.id, audience, sent, results });
  },
);

// ── 친구 ──
Object.assign(exports, require('./friends'));
