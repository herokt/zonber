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
