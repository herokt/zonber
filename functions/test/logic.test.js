// node --test functions/test — 순수 로직(친구 기록 알림 판정 · 하루 한도 · 문구)
const test = require('node:test');
const assert = require('node:assert');
const L = require('../logic');

test('친구 기록을 처음 넘은 순간만', () => {
  assert.equal(L.crossed(90, 100, 95), true); // 이전 90 < 친구 95 < 이번 100
  assert.equal(L.crossed(96, 100, 95), false); // 이미 넘었던 기록
  assert.equal(L.crossed(90, 94, 95), false); // 아직 못 넘음
  assert.equal(L.crossed(0, 100, 0), false); // 친구 기록 없음
  assert.equal(L.crossed(0, 100, undefined), false);
});

test('하루 한도 — 친구 한 명당 1번 · 모두 3번', () => {
  let s = null;
  s = L.allowBeat(s, 'a', '2026-10-01');
  assert.ok(s);
  assert.equal(L.allowBeat(s, 'a', '2026-10-01'), null); // 같은 친구 두 번째
  s = L.allowBeat(s, 'b', '2026-10-01');
  s = L.allowBeat(s, 'c', '2026-10-01');
  assert.equal(s.count, 3);
  assert.equal(L.allowBeat(s, 'd', '2026-10-01'), null); // 네 번째
  assert.ok(L.allowBeat(s, 'a', '2026-10-02')); // 다음 날은 새로
});

test('문구 — 4개 언어 · 모르는 언어는 영어 · 자리표시자 채움', () => {
  for (const kind of Object.keys(L.TEXTS)) {
    for (const lang of L.LANGS) {
      const t = L.textFor(kind, lang, { name: 'Neo', zone: 'dodgeball', time: 96.2121 });
      assert.ok(t[0] && t[1], `${kind} ${lang}`);
      assert.ok(!/[{}]/.test(t[0] + t[1]), `${kind} ${lang} 자리표시자 남음`);
    }
  }
  const [, body] = L.textFor('friend_beat', 'ko', { name: 'Neo', zone: 'dodgeball', time: 96.2121 });
  assert.equal(body, 'Neo님이 피구에서 내 기록(96.212초)을 넘었어요. 되찾으러 가기!');
  assert.deepEqual(L.textFor('friend_request', 'fr', { name: 'X' }), L.textFor('friend_request', 'en', { name: 'X' }));
});

test('친구 코드 정리 — 대문자 · 4~5자만', () => {
  assert.equal(L.normalizeCode(' ab12 '), 'AB12');
  assert.equal(L.normalizeCode('ABCDEF'), '');
  assert.equal(L.normalizeCode('a-12'), '');
});

test('하루 경계는 한국 시간', () => {
  assert.equal(L.kstDay(Date.UTC(2026, 8, 30, 14, 59)), '2026-09-30');
  assert.equal(L.kstDay(Date.UTC(2026, 8, 30, 15, 0)), '2026-10-01');
});

// ── 시즌(2026-10-26) — lib/season.dart 와 같은 식인지 test/logic_test.dart 의 같은 경우들로 맞춘다 ──
test('시즌 — 연간: 첫 시즌은 시즌 1 시작부터, 그 뒤는 1월 1일마다 · 프리시즌', () => {
  const cfg = { ...L.defaultSeasonConfig(), firstStartMs: Date.UTC(2026, 10, 1) }; // 2026-11-01 UTC
  const pre = L.seasonAt(cfg, Date.UTC(2026, 9, 31, 23));
  assert.equal(pre.number, 0);
  assert.equal(pre.id, 'S0');
  assert.equal(pre.endMs, Date.UTC(2026, 10, 1));
  const s1 = L.seasonAt(cfg, Date.UTC(2026, 11, 15));
  assert.deepEqual([s1.number, s1.id, s1.startMs, s1.endMs], [1, '2026', Date.UTC(2026, 10, 1), Date.UTC(2027, 0, 1)]);
  const s2 = L.seasonAt(cfg, Date.UTC(2027, 5, 1));
  assert.deepEqual([s2.number, s2.id, s2.startMs, s2.endMs], [2, '2027', Date.UTC(2027, 0, 1), Date.UTC(2028, 0, 1)]);
  assert.equal(L.seasonPrevious(cfg, s2).id, '2026');
  assert.equal(L.seasonPrevious(cfg, s1).id, 'S0');
  assert.equal(L.seasonPrevious(cfg, pre), null);
});

test('시즌 — 분기 · 월간 · N일 · 시간대(한국 자정)', () => {
  const q = { ...L.defaultSeasonConfig(), mode: 'quarter', firstStartMs: Date.UTC(2026, 9, 1), offsetHours: 0 };
  const q4 = L.seasonAt(q, Date.UTC(2026, 10, 26));
  assert.deepEqual([q4.number, q4.id, q4.startMs, q4.endMs], [1, '2026Q4', Date.UTC(2026, 9, 1), Date.UTC(2027, 0, 1)]);
  assert.equal(L.seasonAt(q, Date.UTC(2027, 3, 2)).id, '2027Q2');
  assert.equal(L.seasonAt(q, Date.UTC(2027, 3, 2)).number, 3);
  assert.equal(L.seasonLabel(q4), '2026 Q4');

  const m = { ...L.defaultSeasonConfig(), mode: 'month', firstStartMs: Date.UTC(2026, 9, 15) };
  const m1 = L.seasonAt(m, Date.UTC(2026, 9, 20));
  assert.deepEqual([m1.id, m1.startMs, m1.endMs], ['2026-10', Date.UTC(2026, 9, 15), Date.UTC(2026, 10, 1)]);
  assert.equal(L.seasonAt(m, Date.UTC(2026, 11, 31)).number, 3);
  assert.equal(L.seasonLabel(m1), '2026.10');

  const d = { ...L.defaultSeasonConfig(), mode: 'days', periodDays: 14, firstStartMs: Date.UTC(2026, 10, 1) };
  const d3 = L.seasonAt(d, Date.UTC(2026, 10, 1) + 29 * L.DAY_MS);
  assert.deepEqual([d3.number, d3.id, d3.startMs, d3.endMs], [3, 'S3', Date.UTC(2026, 10, 29), Date.UTC(2026, 11, 13)]);

  // 한국 자정(UTC+9) 경계 — 12월 31일 24:00 KST = 12월 31일 15:00 UTC
  const k = { ...L.defaultSeasonConfig(), firstStartMs: Date.UTC(2026, 9, 31, 15), offsetHours: 9 };
  const k1 = L.seasonAt(k, Date.UTC(2026, 11, 31, 14, 59));
  assert.equal(k1.id, '2026');
  assert.equal(k1.endMs, Date.UTC(2026, 11, 31, 15));
  assert.equal(L.seasonAt(k, Date.UTC(2026, 11, 31, 15)).id, '2027');
});

test('시즌 — 마감 전 푸시는 pushHour 시에, 남은 날이 pushDays 에 있을 때만', () => {
  const cfg = { ...L.defaultSeasonConfig(), firstStartMs: Date.UTC(2026, 10, 1), offsetHours: 9, pushHour: 18 };
  const s = L.seasonAt(cfg, Date.UTC(2026, 11, 1));
  // 마감 2027-01-01 00:00 KST → 30일 전 = 2026-12-02 18:00 KST = 09:00 UTC
  assert.equal(L.seasonPushDue(cfg, s, Date.UTC(2026, 11, 2, 9, 20)), 30);
  assert.equal(L.seasonPushDue(cfg, s, Date.UTC(2026, 11, 2, 10, 0)), null); // 다른 시간
  assert.equal(L.seasonPushDue(cfg, s, Date.UTC(2026, 11, 3, 9, 0)), null); // 29일 전
  assert.equal(L.seasonPushDue(cfg, s, Date.UTC(2026, 11, 22, 9, 0)), 10);
  assert.equal(L.seasonPushDue(cfg, s, Date.UTC(2026, 11, 29, 9, 0)), 3);
  for (const lang of L.LANGS) {
    for (const d of [30, 10, 3, 7]) {
      const [t, b] = L.seasonText(lang, d, '2026');
      assert.ok(t && b && !t.includes('{') && !b.includes('{'), `${lang} ${d}`);
    }
  }
  assert.ok(L.seasonText('ko', 7, '2026')[1].includes('7일'));
});

test('시즌 — TOP 3 는 사람마다 한 번', () => {
  const rows = [
    { userId: 'a', survivalTime: 100 }, { userId: 'a', survivalTime: 90 }, { userId: 'b', survivalTime: 80 },
    { nickname: 'old', flag: '🇰🇷', survivalTime: 70 }, { userId: 'c', survivalTime: 60 },
  ];
  assert.deepEqual(L.topUnique(rows, 3).map((r) => r.userId || r.nickname), ['a', 'b', 'old']);
});
