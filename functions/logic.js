// ─────────────────────────────────────────────────────────────
// 순수 로직 — Firestore 없이 시험할 수 있는 것만(node --test functions/test)
// ─────────────────────────────────────────────────────────────

const LANGS = ['ko', 'en', 'ja', 'zh'];

// 친구 제한 — docs/FRIENDS.md §3 · lib/friends.dart 와 같게
const MAX_FRIENDS = 100;
const MAX_PENDING = 50;
const REQUEST_DAYS = 7;
const COOLDOWN_DAYS = 7;
const BEAT_PER_FRIEND_PER_DAY = 1;
const BEAT_PER_DAY = 3;

const DAY_MS = 24 * 60 * 60 * 1000;

// 푸시 유효 시간 — 이보다 늦게 도착할 푸시는 버린다(폰이 꺼져 있다 켜져도 지난 알림이 쏟아지지 않게).
// 친구 알림은 알림함에 늘 남으니 짧게, 이벤트·소식은 조금 길게
const FRIEND_TTL_MS = 10 * 60 * 1000;
const NEWS_TTL_MS = 30 * 60 * 1000;
// 알림함 한 사람당 최대(넘으면 오래된 것부터 지운다) · 이벤트·소식은 이 날수 안의 것만 보여 준다
const INBOX_MAX = 100;
const NEWS_DAYS = 30;

// 친구 코드 형식 — lib/promotions.dart FriendCodes 와 같다(영문 대문자·숫자 4~5자)
function normalizeCode(v) {
  const c = String(v || '').trim().toUpperCase();
  return /^[A-Z0-9]{4,5}$/.test(c) ? c : '';
}

function requestId(from, to) {
  return `${from}_${to}`;
}

/// 친구 기록 알림 대상 — 이번에 처음으로 친구 최고 기록을 넘었나(이전 최고 < 친구 최고 < 이번 기록)
function crossed(prevBest, now, friendBest) {
  return typeof friendBest === 'number' && friendBest > 0 && prevBest < friendBest && friendBest < now;
}

/// 하루 알림 한도 — state = push_state/{uid} 의 {day, count, from: {uid: true}}. 보내도 되면 새 state, 아니면 null
function allowBeat(state, fromUid, today) {
  const s = state && state.day === today ? state : { day: today, count: 0, from: {} };
  const from = s.from || {};
  if ((from[fromUid] || 0) >= BEAT_PER_FRIEND_PER_DAY) return null;
  if ((s.count || 0) >= BEAT_PER_DAY) return null;
  return { day: today, count: (s.count || 0) + 1, from: { ...from, [fromUid]: (from[fromUid] || 0) + 1 } };
}

/// 한국 시간 기준 날짜(하루 한도 자르는 선) — 'YYYY-MM-DD'
function kstDay(ms) {
  return new Date(ms + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

function fmtTime(sec) {
  return Number(sec || 0).toFixed(3);
}

// 존 이름 — lib/translations.dart world_{id} 와 같게
const ZONES = {
  cyber: { ko: '갤럭시', en: 'Galaxy', ja: 'ギャラクシー', zh: '银河' },
  dodgeball: { ko: '피구', en: 'Dodgeball', ja: 'ドッジボール', zh: '躲避球' },
  keeper: { ko: '프리킥', en: 'FreeKick', ja: 'フリーキック', zh: '任意球' },
};

// 친구 알림 문구 — {name} 친구 닉네임 · {zone} 존 이름 · {time} 내 기록(초)
const TEXTS = {
  friend_request: {
    ko: ['👋 친구 요청', '{name}님이 친구 요청을 보냈어요'],
    en: ['👋 Friend request', '{name} wants to be your friend'],
    ja: ['👋 フレンド申請', '{name}さんからフレンド申請が届きました'],
    zh: ['👋 好友请求', '{name} 想加你为好友'],
  },
  friend_accepted: {
    ko: ['🤝 친구가 됐어요', '{name}님이 친구 요청을 수락했어요'],
    en: ["🤝 You're now friends", '{name} accepted your friend request'],
    ja: ['🤝 フレンドになりました', '{name}さんがフレンド申請を承認しました'],
    zh: ['🤝 你们成为好友了', '{name} 接受了你的好友请求'],
  },
  friend_added: {
    ko: ['🤝 새 친구', '{name}님이 내 친구 코드로 친구가 됐어요'],
    en: ['🤝 New friend', '{name} added you with your friend code'],
    ja: ['🤝 新しいフレンド', '{name}さんがフレンドコードでフレンドになりました'],
    zh: ['🤝 新好友', '{name} 通过你的好友码加你为好友'],
  },
  friend_beat: {
    ko: ['🔥 기록이 깨졌어요!', '{name}님이 {zone}에서 내 기록({time}초)을 넘었어요. 되찾으러 가기!'],
    en: ['🔥 Your record was beaten!', '{name} just beat your {zone} record ({time}s). Take it back!'],
    ja: ['🔥 記録が抜かれた！', '{name}さんが{zone}であなたの記録（{time}秒）を超えました。取り返そう！'],
    zh: ['🔥 你的纪录被打破了！', '{name} 在{zone}超过了你的纪录（{time}秒），快去夺回来！'],
  },
};

/// 알림 한 통의 [제목, 본문] — 모르는 언어는 영어
function textFor(kind, lang, params) {
  const t = TEXTS[kind];
  if (!t) return null;
  const l = LANGS.includes(lang) ? lang : 'en';
  const p = params || {};
  const zone = p.zone ? (ZONES[p.zone] || {})[l] || p.zone : '';
  const fill = (s) =>
    s.replace('{name}', String(p.name || '?')).replace('{zone}', zone).replace('{time}', p.time == null ? '' : fmtTime(p.time));
  return [fill(t[l][0]), fill(t[l][1])];
}

module.exports = {
  LANGS,
  MAX_FRIENDS,
  MAX_PENDING,
  REQUEST_DAYS,
  COOLDOWN_DAYS,
  BEAT_PER_FRIEND_PER_DAY,
  BEAT_PER_DAY,
  DAY_MS,
  FRIEND_TTL_MS,
  NEWS_TTL_MS,
  INBOX_MAX,
  NEWS_DAYS,
  ZONES,
  TEXTS,
  normalizeCode,
  requestId,
  crossed,
  allowBeat,
  kstDay,
  fmtTime,
  textFor,
};
