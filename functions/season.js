// ─────────────────────────────────────────────────────────────
// 시즌(2026-10-26) — 매시간 한 번 깨어나서
//   ① 마감 n일 전(config/season.pushDays) 그 시간대의 pushHour 시에 자동 푸시 — push_campaigns 에 문서를 만들면
//      sendPushCampaign 이 보낸다(createdBy: 'system'). 한 시즌·한 날짜에 한 번(push_state/season_{id}_{n}).
//   ② 끝난 시즌이 있는데 hall_of_fame/{시즌 id} 가 없으면 존별 TOP 3 를 남긴다(명예의 전당). 최대 12 시즌 거슬러 올라간다.
// 시즌 계산은 logic.js seasonAt — lib/season.dart SeasonConfig.seasonAt 과 같은 식. 설정 문서는 백오피스 › 시즌.
// ─────────────────────────────────────────────────────────────
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const L = require('./logic');

const ZONE_IDS = Object.keys(L.ZONES); // rankingMapId = 존 id (cyber · dodgeball · keeper)

function configFrom(d) {
  const c = L.defaultSeasonConfig();
  if (!d) return c;
  if (['year', 'quarter', 'month', 'days'].includes(d.mode)) c.mode = d.mode;
  if (d.firstStart && typeof d.firstStart.toMillis === 'function') c.firstStartMs = d.firstStart.toMillis();
  if (Number.isFinite(d.offsetHours)) c.offsetHours = Math.max(-12, Math.min(14, Math.trunc(d.offsetHours)));
  if (Number.isFinite(d.periodDays)) c.periodDays = Math.max(1, Math.trunc(d.periodDays));
  if (Array.isArray(d.pushDays)) c.pushDays = d.pushDays.filter((n) => Number.isFinite(n) && n > 0).map((n) => Math.trunc(n));
  if (Number.isFinite(d.pushHour)) c.pushHour = Math.max(0, Math.min(23, Math.trunc(d.pushHour)));
  return c;
}

/// 마감 전 푸시 — 지금이 그 시간대의 pushHour 이고, 마감까지 남은 날이 pushDays 에 있으면 한 번
async function sendCountdown(db, cfg, cur, nowMs) {
  if (cur.number <= 0 || !cfg.pushDays.length) return;
  const d = L.seasonPushDue(cfg, cur, nowMs);
  if (d == null) return;
  const key = `season_${cur.id}_${d}`;
  const stateRef = db.collection('push_state').doc(key);
  const fresh = await db.runTransaction(async (tx) => {
    const s = await tx.get(stateRef);
    if (s.exists) return false;
    tx.set(stateRef, { season: cur.id, days: d, at: FieldValue.serverTimestamp() });
    return true;
  });
  if (!fresh) return;
  const label = L.seasonLabel(cur);
  const title = {};
  const body = {};
  for (const lang of L.LANGS) {
    const [t, b] = L.seasonText(lang, d, label);
    title[lang] = t;
    body[lang] = b;
  }
  const ref = await db.collection('push_campaigns').add({
    title,
    body,
    langs: [],
    audience: 'all',
    templateId: 'season_ending',
    status: 'pending',
    createdBy: 'system',
    createdAt: FieldValue.serverTimestamp(),
    season: cur.id,
    daysLeft: d,
  });
  logger.info('season countdown push', { season: cur.id, days: d, campaign: ref.id });
}

/// 시즌 [s] 의 존별 TOP 3 — 기록은 시즌 안(timestamp 범위)만, 사람마다 가장 좋은 기록 하나, 닉네임·국기·아바타는 지금 유저 문서
async function snapshot(db, s) {
  const zones = {};
  const uids = new Set();
  for (const z of ZONE_IDS) {
    const snap = await db
      .collection('maps')
      .doc(z)
      .collection('records')
      .where('timestamp', '>=', Timestamp.fromMillis(s.startMs))
      .where('timestamp', '<', Timestamp.fromMillis(s.endMs))
      .limit(3000)
      .get();
    const rows = snap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => (b.survivalTime || 0) - (a.survivalTime || 0));
    zones[z] = L.topUnique(rows, 3);
    zones[z].forEach((r) => r.userId && uids.add(r.userId));
  }
  const users = {};
  for (const uid of uids) {
    const u = await db.collection('users').doc(uid).get();
    if (u.exists) users[uid] = u.data();
  }
  for (const z of ZONE_IDS) {
    zones[z] = zones[z].map((r) => {
      const u = users[r.userId] || {};
      const eq = u.equipped || {};
      return {
        userId: r.userId || '',
        nickname: u.nickname || r.nickname || 'Unknown',
        flag: u.flag || r.flag || '',
        survivalTime: Number(r.survivalTime || 0),
        characterId: u.characterId || r.characterId || 'neon_green',
        skin: typeof eq.skin === 'string' ? eq.skin : 'skin_none',
      };
    });
  }
  await db.collection('hall_of_fame').doc(s.id).set({
    seasonId: s.id,
    number: s.number,
    mode: s.mode,
    label: L.seasonLabel(s),
    start: Timestamp.fromMillis(s.startMs),
    end: Timestamp.fromMillis(s.endMs),
    zones,
    createdAt: FieldValue.serverTimestamp(),
  });
  logger.info('hall of fame written', { season: s.id, top: Object.fromEntries(ZONE_IDS.map((z) => [z, zones[z].length])) });
}

async function closeEnded(db, cfg, cur) {
  let prev = L.seasonPrevious(cfg, cur);
  for (let i = 0; i < 12 && prev && prev.number >= 1; i++) {
    const doc = await db.collection('hall_of_fame').doc(prev.id).get();
    if (doc.exists) break; // 그 앞은 이미 다 적었다
    await snapshot(db, prev);
    prev = L.seasonPrevious(cfg, prev);
  }
}

exports.seasonTick = onSchedule({ schedule: 'every 1 hours', region: 'us-central1', timeZone: 'UTC' }, async () => {
  const db = getFirestore();
  const doc = await db.collection('config').doc('season').get();
  const cfg = configFrom(doc.exists ? doc.data() : null);
  const nowMs = Date.now();
  const cur = L.seasonAt(cfg, nowMs);
  try {
    await sendCountdown(db, cfg, cur, nowMs);
  } catch (e) {
    logger.error('season countdown failed', { error: String(e && e.message ? e.message : e) });
  }
  try {
    await closeEnded(db, cfg, cur);
  } catch (e) {
    logger.error('hall of fame failed', { error: String(e && e.message ? e.message : e) });
  }
});
