// firestore.rules 를 배포하지 않고 Firebase Rules API(projects:test)로 시험한다. 읽기 전용 — 아무것도 바뀌지 않는다.
//   gcloud auth login   (프로젝트 소유 계정)
//   node scripts/test_rules.mjs
// 기록 생성의 서버 시각 검사(timestamp == request.time)는 API 로 값을 만들 수 없어 그 줄만 빼고 시험한다.
import { execSync } from 'child_process';
import { readFileSync } from 'fs';
import { createRequire } from 'module';
import { homedir } from 'os';

const PROJECT = 'stayzone-88364';

// gcloud 가 없으면 firebase CLI(firebase login) 계정 토큰을 쓴다
async function accessToken() {
  try {
    return execSync('gcloud auth print-access-token', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    const root = execSync('npm root -g', { encoding: 'utf8' }).trim();
    const auth = createRequire(import.meta.url)(`${root}/firebase-tools/lib/auth.js`);
    const cfg = JSON.parse(readFileSync(`${homedir()}/.config/configstore/firebase-tools.json`, 'utf8'));
    const t = await auth.getAccessToken(cfg.tokens.refresh_token, []);
    return t.access_token;
  }
}
const token = await accessToken();
// 줄바꿈을 LF 로 맞춘 뒤 서버 시각 검사 줄을 뺀다(윈도우 체크아웃은 CRLF 라 정규식이 안 맞았다)
let source = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8').replace(/\r\n/g, '\n');
source = source.replace(/\n\s*&& request\.resource\.data\.timestamp == request\.time\);/, ');');
source = source.replace(/\n\s*&& request\.resource\.data\.timestamp == request\.time\n/, '\n');
source = source.replace(/\n\s*&& request\.resource\.data\.at == request\.time\n/g, '\n'); // 코드 사용 기록·친구 코드 입력의 서버 시각

const P = (p) => `/databases/(default)/documents/${p}`;
const anon = { uid: 'guest1', token: { firebase: { sign_in_provider: 'anonymous' } } };
const member = { uid: 'u1', token: { email: 'a@b.com', email_verified: true, firebase: { sign_in_provider: 'google.com' } } };
const member2 = { uid: 'u2', token: { email: 'c@d.com', email_verified: true, firebase: { sign_in_provider: 'google.com' } } };
const admin = { uid: 'adm', token: { email: 'herokt851103@gmail.com', email_verified: true, firebase: { sign_in_provider: 'google.com' } } };

// get()/exists()/getAfter()/existsAfter() 가짜 응답 — [함수, 문서 경로, 값]
const mock = (fn, path, value) => ({ function: fn, args: [{ exactValue: P(path) }], result: { value } });
const code = { campaign: 'insta', coins: 500, items: [], enabled: true, maxUses: 10, uses: 3 };
const redeemMocks = (usedBefore = false, usedAfter = true) => [
  mock('exists', 'users/u1/codes/ABC', usedBefore),
  mock('existsAfter', 'users/u1/codes/ABC', usedAfter),
];
const counterMocks = (before, after) => [
  mock('get', 'promo_codes/ABC', { data: { ...code, uses: before } }),
  mock('getAfter', 'promo_codes/ABC', { data: { ...code, uses: after } }),
];

// 친구 코드 만들기 — [이벤트 코드와 겹침, 내 유저 문서의 기존 friendCode, 같은 요청 뒤의 friendCode]
const makeFriendMocks = (code, { promoExists = false, before = '', after = code } = {}) => [
  mock('exists', `promo_codes/${code}`, promoExists),
  mock('exists', 'users/u1', true),
  mock('get', 'users/u1', { data: before ? { friendCode: before } : { nickname: 'me' } }),
  mock('getAfter', 'users/u1', { data: { friendCode: after } }),
];
// 친구 코드 K7PQ 의 주인
const friendOwner = (uid) => [mock('get', 'friend_codes/K7PQ', { data: { uid } })];
const invite = { code: 'K7PQ', inviter: 'u2', rewarded: false };

const cases = [
  // [설명, 기대, 요청, 기존 문서 data, 함수 가짜 응답]
  ['비로그인 랭킹 읽기', 'ALLOW', { path: P('maps/cyber/records/r1'), method: 'get' }, { userId: 'u1', survivalTime: 10 }],
  ['게스트 유저 문서 읽기', 'ALLOW', { auth: anon, path: P('users/u1'), method: 'get' }, { nickname: 'x' }],
  ['회원 본인 기록 생성', 'ALLOW', { auth: member, path: P('maps/cyber/records/n1'), method: 'create', resource: { data: { userId: 'u1', survivalTime: 42.123, flag: '🇰🇷', characterId: 'neon_green' } } }],
  ['회원이 남의 uid 로 기록', 'DENY', { auth: member, path: P('maps/cyber/records/n2'), method: 'create', resource: { data: { userId: 'u2', survivalTime: 42 } } }],
  ['기록 시간 3600초 초과', 'DENY', { auth: member, path: P('maps/cyber/records/n3'), method: 'create', resource: { data: { userId: 'u1', survivalTime: 99999 } } }],
  ['게스트 기록 생성', 'DENY', { auth: anon, path: P('maps/cyber/records/n4'), method: 'create', resource: { data: { userId: 'guest1', survivalTime: 10 } } }],
  ['본인 기록 삭제(부활)', 'ALLOW', { auth: member, path: P('maps/cyber/records/r1'), method: 'delete' }, { userId: 'u1', survivalTime: 10 }],
  ['남의 기록 삭제', 'DENY', { auth: member, path: P('maps/cyber/records/r2'), method: 'delete' }, { userId: 'u2', survivalTime: 10 }],
  ['기록 수정(회원)', 'DENY', { auth: member, path: P('maps/cyber/records/r1'), method: 'update', resource: { data: { userId: 'u1', survivalTime: 999 } } }, { userId: 'u1', survivalTime: 10 }],
  ['관리자 기록 수정', 'ALLOW', { auth: admin, path: P('maps/cyber/records/r1'), method: 'update', resource: { data: { userId: 'u1', survivalTime: 10, flag: 'x' } } }, { userId: 'u1', survivalTime: 10 }],
  ['플레이 수 +1', 'ALLOW', { auth: member, path: P('maps/cyber'), method: 'update', resource: { data: { playCount: 11 } } }, { playCount: 10 }],
  ['게스트 플레이 수 +1', 'DENY', { auth: anon, path: P('maps/cyber'), method: 'update', resource: { data: { playCount: 11 } } }, { playCount: 10 }],
  ['플레이 수 +100', 'DENY', { auth: member, path: P('maps/cyber'), method: 'update', resource: { data: { playCount: 110 } } }, { playCount: 10 }],
  ['맵 다른 필드 수정', 'DENY', { auth: member, path: P('maps/cyber'), method: 'update', resource: { data: { playCount: 10, name: 'hack' } } }, { playCount: 10 }],
  ['맵 첫 플레이(생성)', 'ALLOW', { auth: member, path: P('maps/newmap'), method: 'create', resource: { data: { playCount: 1 } } }],
  ['게스트 맵 첫 플레이(생성)', 'DENY', { auth: anon, path: P('maps/newmap'), method: 'create', resource: { data: { playCount: 1 } } }],
  ['본인 유저 문서 수정', 'ALLOW', { auth: member, path: P('users/u1'), method: 'update', resource: { data: { nickname: 'me', coins: 120, equipped: { skin: 'skin_gold' } } } }, { nickname: 'me', coins: 100 }],
  ['게스트 본인 문서 생성', 'DENY', { auth: anon, path: P('users/guest1'), method: 'create', resource: { data: { nickname: 'Guest', totalGamesPlayed: 1 } } }],
  ['게스트 비공개 문서 쓰기', 'DENY', { auth: anon, path: P('users/guest1/private/account'), method: 'create', resource: { data: { email: '' } } }],
  ['게스트 커스텀 맵 생성', 'DENY', { auth: anon, path: P('custom_maps/g1'), method: 'create', resource: { data: { authorUid: 'guest1' } } }],
  ['게스트 본인 문서 수정', 'DENY', { auth: anon, path: P('users/guest1'), method: 'update', resource: { data: { totalGamesPlayed: 3 } } }, { totalGamesPlayed: 2 }],
  ['남의 유저 문서 수정', 'DENY', { auth: member, path: P('users/u2'), method: 'update', resource: { data: { nickname: 'hacked' } } }, { nickname: 'victim' }],
  ['코인 음수', 'DENY', { auth: member, path: P('users/u1'), method: 'update', resource: { data: { coins: -5 } } }, { coins: 100 }],
  ['코인 실수형', 'DENY', { auth: member, path: P('users/u1'), method: 'update', resource: { data: { coins: 1.5 } } }, { coins: 100 }],
  ['관리자 남의 문서 수정', 'ALLOW', { auth: admin, path: P('users/u2'), method: 'update', resource: { data: { nickname: 'fixed' } } }, { nickname: 'victim' }],
  ['관리자 남의 문서 삭제', 'ALLOW', { auth: admin, path: P('users/u2'), method: 'delete' }, { nickname: 'victim' }],
  ['비공개 문서 본인 읽기', 'ALLOW', { auth: member, path: P('users/u1/private/account'), method: 'get' }, { email: 'a@b.com' }],
  ['비공개 문서 남이 읽기', 'DENY', { auth: member, path: P('users/u2/private/account'), method: 'get' }, { email: 'c@d.com' }],
  ['비공개 문서 관리자 읽기', 'ALLOW', { auth: admin, path: P('users/u2/private/account'), method: 'get' }, { email: 'c@d.com' }],
  ['게스트가 비공개 문서 읽기', 'DENY', { auth: anon, path: P('users/u1/private/account'), method: 'get' }, { email: 'a@b.com' }],
  ['인증 안 된 이메일 관리자 사칭', 'DENY', { auth: { uid: 'x', token: { email: 'herokt851103@gmail.com', email_verified: false, firebase: { sign_in_provider: 'password' } } }, path: P('users/u2'), method: 'update', resource: { data: { nickname: 'x' } } }, { nickname: 'victim' }],
  ['회원 본인 플레이 기록 추가', 'ALLOW', { auth: member, path: P('users/u1/runs/x1'), method: 'create', resource: { data: { time: 12.3, stage: 1 } } }],
  ['게스트 플레이 기록 추가', 'DENY', { auth: anon, path: P('users/guest1/runs/x0'), method: 'create', resource: { data: { time: 12.3, stage: 1 } } }],
  ['남의 플레이 기록 추가', 'DENY', { auth: member, path: P('users/u2/runs/x2'), method: 'create', resource: { data: { time: 12.3 } } }],
  ['플레이 기록 시간 이상', 'DENY', { auth: member, path: P('users/u1/runs/x3'), method: 'create', resource: { data: { time: 99999 } } }],
  ['플레이 기록 수정', 'DENY', { auth: member, path: P('users/u1/runs/x4'), method: 'update', resource: { data: { time: 1 } } }, { time: 50 }],
  ['남의 플레이 기록 읽기', 'DENY', { auth: member, path: P('users/u2/runs/x5'), method: 'get' }, { time: 50 }],
  ['관리자 플레이 기록 읽기', 'ALLOW', { auth: admin, path: P('users/u2/runs/x5'), method: 'get' }, { time: 50 }],
  ['커스텀 맵 본인 삭제', 'ALLOW', { auth: member, path: P('custom_maps/m1'), method: 'delete' }, { authorUid: 'u1' }],
  ['커스텀 맵 남이 삭제', 'DENY', { auth: member, path: P('custom_maps/m1'), method: 'delete' }, { authorUid: 'u2' }],
  // ── 이벤트 코드(promo_codes · users/{uid}/codes) ──
  ['회원이 코드 한 건 읽기', 'ALLOW', { auth: member, path: P('promo_codes/ABC'), method: 'get' }, code],
  ['게스트가 코드 읽기', 'DENY', { auth: anon, path: P('promo_codes/ABC'), method: 'get' }, code],
  ['회원이 코드 목록 읽기', 'DENY', { auth: member, path: P('promo_codes/ABC'), method: 'list' }, code],
  ['관리자 코드 목록 읽기', 'ALLOW', { auth: admin, path: P('promo_codes/ABC'), method: 'list' }, code],
  ['회원이 코드 만들기', 'DENY', { auth: member, path: P('promo_codes/NEW1'), method: 'create', resource: { data: { ...code, uses: 0 } } }],
  ['관리자 코드 만들기', 'ALLOW', { auth: admin, path: P('promo_codes/NEW1'), method: 'create', resource: { data: { ...code, uses: 0 } } }],
  ['코드 사용 +1', 'ALLOW', { auth: member, path: P('promo_codes/ABC'), method: 'update', resource: { data: { ...code, uses: 4 } } }, code, redeemMocks()],
  ['이미 쓴 코드 +1', 'DENY', { auth: member, path: P('promo_codes/ABC'), method: 'update', resource: { data: { ...code, uses: 4 } } }, code, redeemMocks(true, true)],
  ['사용 기록 없이 +1', 'DENY', { auth: member, path: P('promo_codes/ABC'), method: 'update', resource: { data: { ...code, uses: 4 } } }, code, redeemMocks(false, false)],
  ['한도 찬 코드 +1', 'DENY', { auth: member, path: P('promo_codes/ABC'), method: 'update', resource: { data: { ...code, uses: 11 } } }, { ...code, uses: 10 }, redeemMocks()],
  ['꺼진 코드 +1', 'DENY', { auth: member, path: P('promo_codes/ABC'), method: 'update', resource: { data: { ...code, enabled: false, uses: 4 } } }, { ...code, enabled: false }, redeemMocks()],
  ['코드 사용 +2', 'DENY', { auth: member, path: P('promo_codes/ABC'), method: 'update', resource: { data: { ...code, uses: 5 } } }, code, redeemMocks()],
  ['회원이 코드 보상 바꾸기', 'DENY', { auth: member, path: P('promo_codes/ABC'), method: 'update', resource: { data: { ...code, coins: 99999, uses: 4 } } }, code, redeemMocks()],
  ['게스트 코드 사용 +1', 'DENY', { auth: anon, path: P('promo_codes/ABC'), method: 'update', resource: { data: { ...code, uses: 4 } } }, code, redeemMocks()],
  ['내 코드 사용 기록 생성', 'ALLOW', { auth: member, path: P('users/u1/codes/ABC'), method: 'create', resource: { data: { code: 'ABC', coins: 500 } } }, null, counterMocks(3, 4)],
  ['사용 수 안 올리고 기록만', 'DENY', { auth: member, path: P('users/u1/codes/ABC'), method: 'create', resource: { data: { code: 'ABC', coins: 500 } } }, null, counterMocks(3, 3)],
  ['다른 코드 이름으로 기록', 'DENY', { auth: member, path: P('users/u1/codes/ABC'), method: 'create', resource: { data: { code: 'XYZ', coins: 500 } } }, null, counterMocks(3, 4)],
  ['남의 코드 사용 기록 생성', 'DENY', { auth: member, path: P('users/u2/codes/ABC'), method: 'create', resource: { data: { code: 'ABC' } } }, null, counterMocks(3, 4)],
  ['코드 사용 기록 수정', 'DENY', { auth: member, path: P('users/u1/codes/ABC'), method: 'update', resource: { data: { code: 'ABC', coins: 9999 } } }, { code: 'ABC', coins: 500 }],
  // ── 친구 코드(friend_codes · friend_invites) ──
  ['회원 친구 코드 만들기', 'ALLOW', { auth: member, path: P('friend_codes/K7PQ'), method: 'create', resource: { data: { uid: 'u1' } } }, null, makeFriendMocks('K7PQ')],
  ['5자 친구 코드 만들기', 'ALLOW', { auth: member, path: P('friend_codes/K7PQ2'), method: 'create', resource: { data: { uid: 'u1' } } }, null, makeFriendMocks('K7PQ2')],
  ['6자 친구 코드', 'DENY', { auth: member, path: P('friend_codes/K7PQ22'), method: 'create', resource: { data: { uid: 'u1' } } }, null, makeFriendMocks('K7PQ22')],
  ['소문자 친구 코드', 'DENY', { auth: member, path: P('friend_codes/k7pq'), method: 'create', resource: { data: { uid: 'u1' } } }, null, makeFriendMocks('k7pq')],
  ['남의 uid 로 친구 코드', 'DENY', { auth: member, path: P('friend_codes/K7PQ'), method: 'create', resource: { data: { uid: 'u2' } } }, null, makeFriendMocks('K7PQ')],
  ['친구 코드 두 번째 만들기', 'DENY', { auth: member, path: P('friend_codes/K7PQ'), method: 'create', resource: { data: { uid: 'u1' } } }, null, makeFriendMocks('K7PQ', { before: 'AAAA' })],
  ['유저 문서에 안 적고 코드만', 'DENY', { auth: member, path: P('friend_codes/K7PQ'), method: 'create', resource: { data: { uid: 'u1' } } }, null, makeFriendMocks('K7PQ', { after: '' })],
  ['이벤트 코드와 같은 친구 코드', 'DENY', { auth: member, path: P('friend_codes/K7PQ'), method: 'create', resource: { data: { uid: 'u1' } } }, null, makeFriendMocks('K7PQ', { promoExists: true })],
  ['친구 코드에 다른 필드', 'DENY', { auth: member, path: P('friend_codes/K7PQ'), method: 'create', resource: { data: { uid: 'u1', coins: 999 } } }, null, makeFriendMocks('K7PQ')],
  ['게스트 친구 코드 만들기', 'DENY', { auth: anon, path: P('friend_codes/K7PQ'), method: 'create', resource: { data: { uid: 'guest1' } } }, null, makeFriendMocks('K7PQ')],
  ['회원 친구 코드 한 건 읽기', 'ALLOW', { auth: member, path: P('friend_codes/K7PQ'), method: 'get' }, { uid: 'u2' }],
  ['게스트 친구 코드 읽기', 'DENY', { auth: anon, path: P('friend_codes/K7PQ'), method: 'get' }, { uid: 'u2' }],
  ['회원 친구 코드 목록', 'DENY', { auth: member, path: P('friend_codes/K7PQ'), method: 'list' }, { uid: 'u2' }],
  ['친구 코드 주인 바꾸기', 'DENY', { auth: member, path: P('friend_codes/K7PQ'), method: 'update', resource: { data: { uid: 'u1' } } }, { uid: 'u2' }],
  ['내 친구 코드 지우기(탈퇴)', 'ALLOW', { auth: member, path: P('friend_codes/K7PQ'), method: 'delete' }, { uid: 'u1' }],
  ['남의 친구 코드 지우기', 'DENY', { auth: member, path: P('friend_codes/K7PQ'), method: 'delete' }, { uid: 'u2' }],
  ['친구 코드 넣기', 'ALLOW', { auth: member, path: P('friend_invites/u1'), method: 'create', resource: { data: invite } }, null, friendOwner('u2')],
  ['주인을 속여 넣기', 'DENY', { auth: member, path: P('friend_invites/u1'), method: 'create', resource: { data: { ...invite, inviter: 'u3' } } }, null, friendOwner('u2')],
  ['내 코드 넣기', 'DENY', { auth: member, path: P('friend_invites/u1'), method: 'create', resource: { data: { ...invite, inviter: 'u1' } } }, null, friendOwner('u1')],
  ['남 대신 친구 코드 넣기', 'DENY', { auth: member, path: P('friend_invites/u3'), method: 'create', resource: { data: invite } }, null, friendOwner('u2')],
  ['보상받은 상태로 넣기', 'DENY', { auth: member, path: P('friend_invites/u1'), method: 'create', resource: { data: { ...invite, rewarded: true } } }, null, friendOwner('u2')],
  ['게스트 친구 코드 넣기', 'DENY', { auth: anon, path: P('friend_invites/guest1'), method: 'create', resource: { data: invite } }, null, friendOwner('u2')],
  ['넣은 사람이 다시 넣기(수정)', 'DENY', { auth: member, path: P('friend_invites/u1'), method: 'update', resource: { data: { ...invite, code: 'ZZZZ' } } }, invite],
  ['넣은 사람이 기록 지우기', 'DENY', { auth: member, path: P('friend_invites/u1'), method: 'delete' }, invite],
  ['코드 주인 보상 표시', 'ALLOW', { auth: member2, path: P('friend_invites/u1'), method: 'update', resource: { data: { ...invite, rewarded: true } } }, invite],
  ['코드 주인 보상 두 번', 'DENY', { auth: member2, path: P('friend_invites/u1'), method: 'update', resource: { data: { ...invite, rewarded: true } } }, { ...invite, rewarded: true }],
  ['코드 주인이 다른 필드 수정', 'DENY', { auth: member2, path: P('friend_invites/u1'), method: 'update', resource: { data: { ...invite, rewarded: true, code: 'ZZZZ' } } }, invite],
  ['남이 보상 표시', 'DENY', { auth: member, path: P('friend_invites/u3'), method: 'update', resource: { data: { ...invite, rewarded: true } } }, invite],
  ['코드 주인이 내 친구 목록', 'ALLOW', { auth: member2, path: P('friend_invites/u1'), method: 'list' }, invite],
  ['남이 친구 목록', 'DENY', { auth: { ...member, uid: 'u9' }, path: P('friend_invites/u1'), method: 'list' }, invite],
  ['관리자 코드 사용자 목록', 'ALLOW', { auth: admin, path: P('users/u2/codes/ABC'), method: 'list' }, { code: 'ABC' }],
];

const testCases = cases.map(([, expectation, request, existing, functionMocks]) => ({
  expectation,
  request: { time: '2026-09-22T00:00:00Z', ...request },
  ...(existing ? { resource: { data: existing } } : {}),
  ...(functionMocks ? { functionMocks } : {}),
}));

const res = await fetch(`https://firebaserules.googleapis.com/v1/projects/${PROJECT}:test`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'x-goog-user-project': PROJECT, 'Content-Type': 'application/json' },
  body: JSON.stringify({ source: { files: [{ name: 'firestore.rules', content: source }] }, testSuite: { testCases } }),
});
const j = await res.json();
if (j.error) { console.log('API 오류', JSON.stringify(j.error, null, 2)); process.exit(1); }
if (j.issues?.length) console.log('규칙 문제', JSON.stringify(j.issues, null, 2));
let fail = 0;
(j.testResults ?? []).forEach((r, i) => {
  const ok = r.state === 'SUCCESS';
  if (!ok) fail++;
  console.log(`${ok ? '✅' : '❌'} ${cases[i][0]} (기대 ${cases[i][1]})${ok ? '' : ' — ' + (r.debugMessages ?? []).join(' / ')}`);
});
console.log(fail ? `\n실패 ${fail}건` : `\n전부 통과 (${cases.length}건)`);
process.exit(fail ? 1 : 0);
