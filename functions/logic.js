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


// ── 시즌(2026-10-26) — lib/season.dart SeasonConfig.seasonAt 과 **같은 식**. 바꾸면 둘 다 고친다 ──
const HOUR_MS = 60 * 60 * 1000;

function defaultSeasonConfig() {
  return { mode: 'year', firstStartMs: Date.UTC(2026, 10, 1), offsetHours: 0, periodDays: 90, pushDays: [30, 10, 3], pushHour: 18 };
}

// 시즌 시간대의 벽시계(UTC 로 표현한 ms) ↔ 실제 순간
const toS = (cfg, ms) => ms + cfg.offsetHours * HOUR_MS;
const fromS = (cfg, ms) => ms - cfg.offsetHours * HOUR_MS;

/// [nowMs] 순간의 시즌 — {number, id, startMs, endMs, mode}
function seasonAt(cfg, nowMs) {
  if (nowMs < cfg.firstStartMs) return { number: 0, id: 'S0', startMs: Date.UTC(2000, 0, 1), endMs: cfg.firstStartMs, mode: cfg.mode };
  const s = new Date(toS(cfg, nowMs));
  const fs = new Date(toS(cfg, cfg.firstStartMs));
  const y = s.getUTCFullYear();
  const m = s.getUTCMonth(); // 0~11
  let startS;
  let endS;
  let id;
  let number;
  switch (cfg.mode) {
    case 'quarter': {
      const q = Math.floor(m / 3);
      startS = Date.UTC(y, q * 3, 1);
      endS = Date.UTC(y, q * 3 + 3, 1);
      id = `${y}Q${q + 1}`;
      number = (y - fs.getUTCFullYear()) * 4 + q - Math.floor(fs.getUTCMonth() / 3) + 1;
      break;
    }
    case 'month':
      startS = Date.UTC(y, m, 1);
      endS = Date.UTC(y, m + 1, 1);
      id = `${y}-${String(m + 1).padStart(2, '0')}`;
      number = (y - fs.getUTCFullYear()) * 12 + m - fs.getUTCMonth() + 1;
      break;
    case 'days': {
      const len = Math.max(1, cfg.periodDays) * DAY_MS;
      const n = Math.floor((s.getTime() - fs.getTime()) / len);
      startS = fs.getTime() + n * len;
      endS = startS + len;
      id = `S${n + 1}`;
      number = n + 1;
      break;
    }
    default: // year
      startS = Date.UTC(y, 0, 1);
      endS = Date.UTC(y + 1, 0, 1);
      id = `${y}`;
      number = y - fs.getUTCFullYear() + 1;
  }
  if (startS < fs.getTime()) startS = fs.getTime(); // 첫 시즌은 시즌 1 시작부터
  return { number, id, startMs: fromS(cfg, startS), endMs: fromS(cfg, endS), mode: cfg.mode };
}

function seasonPrevious(cfg, info) {
  return info.number <= 0 ? null : seasonAt(cfg, info.startMs - 1);
}

/// lib/season.dart SeasonInfo.label 과 같게 — '2026' · '2026 Q4' · '2026.10' · 'S3'
function seasonLabel(info) {
  switch (info.mode) {
    case 'quarter':
      return info.id.replace('Q', ' Q');
    case 'month':
      return info.id.replace('-', '.');
    default:
      return info.id;
  }
}

/// 지금 보낼 마감 전 푸시가 있으면 며칠 전인지, 없으면 null — 시즌 시간대의 pushHour 시(그 시간 안 아무 때나)이고,
/// 오늘(시즌 시간대 날짜)부터 마감일까지 남은 날이 pushDays 에 있을 때
function seasonPushDue(cfg, info, nowMs) {
  const s = new Date(toS(cfg, nowMs));
  if (s.getUTCHours() !== cfg.pushHour) return null;
  const today = Date.UTC(s.getUTCFullYear(), s.getUTCMonth(), s.getUTCDate());
  const e = new Date(toS(cfg, info.endMs));
  const endDay = Date.UTC(e.getUTCFullYear(), e.getUTCMonth(), e.getUTCDate());
  const days = Math.round((endDay - today) / DAY_MS);
  return cfg.pushDays.includes(days) ? days : null;
}

/// 시간순(좋은 순)으로 정렬된 기록에서 사람마다 첫 기록만 — lib/ranking_system.dart _uniquePlayers 와 같게
function topUnique(sorted, n) {
  const seen = new Set();
  const out = [];
  for (const r of sorted) {
    const uid = r.userId || '';
    const key = uid || `legacy:${r.nickname || ''}|${r.flag || ''}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(r);
    if (out.length >= n) break;
  }
  return out;
}

// 마감 전 푸시 문구 — {days} 남은 날 · {season} 시즌 이름. 30·10·3 일은 따로, 나머지는 공통
const SEASON_TEXTS = {
  30: {
    ko: ['🏆 {season} 시즌 마감 한 달 전', '명예의 전당에 오를 기회가 한 달 남았어요. 지금 TOP 3 는 영원히 남아요!'],
    en: ['🏆 One month left in Season {season}', 'One month to earn a place in the Hall of Fame. The final TOP 3 stays forever!'],
    ja: ['🏆 シーズン{season} 締め切りまであと1か月', '殿堂入りのチャンスはあと1か月。最終TOP3は永遠に残ります！'],
    zh: ['🏆 {season} 赛季还剩一个月', '登上名人堂的机会只剩一个月。最终 TOP 3 将永久保留！'],
  },
  10: {
    ko: ['🏆 시즌 마감 D-10', '열흘 뒤 {season} 시즌이 끝나요. 명예의 전당 TOP 3, 아직 바꿀 수 있어요!'],
    en: ['🏆 Season ends in 10 days', 'Season {season} closes in 10 days. The Hall of Fame TOP 3 can still change!'],
    ja: ['🏆 シーズン締め切りまであと10日', 'あと10日でシーズン{season}が終了。殿堂のTOP3はまだ変えられる！'],
    zh: ['🏆 赛季结算倒计时 10 天', '{season} 赛季 10 天后结束，名人堂 TOP 3 还有变数！'],
  },
  3: {
    ko: ['🔥 시즌 마감 D-3', '사흘 남았어요! 마지막으로 기록을 올려 명예의 전당에 이름을 남기세요.'],
    en: ['🔥 3 days left in the season', 'Three days to go! Push your record one more time and get into the Hall of Fame.'],
    ja: ['🔥 シーズン締め切りまであと3日', 'あと3日！最後に記録を伸ばして殿堂に名前を残そう。'],
    zh: ['🔥 赛季结算倒计时 3 天', '只剩 3 天！最后冲一次纪录，把名字留在名人堂。'],
  },
  any: {
    ko: ['🏆 시즌 마감 D-{days}', '{days}일 뒤 {season} 시즌이 끝나요 — 명예의 전당에 오를 마지막 기회!'],
    en: ['🏆 Season ends in {days} days', 'Season {season} closes in {days} days — last chance for the Hall of Fame!'],
    ja: ['🏆 シーズン締め切りまであと{days}日', 'あと{days}日でシーズン{season}が終了 — 殿堂入りのラストチャンス！'],
    zh: ['🏆 赛季结算倒计时 {days} 天', '{season} 赛季 {days} 天后结束 — 登上名人堂的最后机会！'],
  },
};

function seasonText(lang, days, label) {
  const l = LANGS.includes(lang) ? lang : 'en';
  const t = (SEASON_TEXTS[days] || SEASON_TEXTS.any)[l];
  const fill = (s) => s.replace(/\{days\}/g, String(days)).replace(/\{season\}/g, String(label));
  return [fill(t[0]), fill(t[1])];
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
  defaultSeasonConfig,
  seasonAt,
  seasonPrevious,
  seasonLabel,
  seasonPushDue,
  topUnique,
  SEASON_TEXTS,
  seasonText,
};
