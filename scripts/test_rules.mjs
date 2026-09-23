// firestore.rules 를 배포하지 않고 Firebase Rules API(projects:test)로 시험한다. 읽기 전용 — 아무것도 바뀌지 않는다.
//   gcloud auth login   (프로젝트 소유 계정)
//   node scripts/test_rules.mjs
// 기록 생성의 서버 시각 검사(timestamp == request.time)는 API 로 값을 만들 수 없어 그 줄만 빼고 시험한다.
import { execSync } from 'child_process';
import { readFileSync } from 'fs';

const PROJECT = 'stayzone-88364';
const token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
let source = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
source = source.replace(/\n\s*&& request\.resource\.data\.timestamp == request\.time\);/, ');');
source = source.replace(/\n\s*&& request\.resource\.data\.timestamp == request\.time\n/, '\n');

const P = (p) => `/databases/(default)/documents/${p}`;
const anon = { uid: 'guest1', token: { firebase: { sign_in_provider: 'anonymous' } } };
const member = { uid: 'u1', token: { email: 'a@b.com', email_verified: true, firebase: { sign_in_provider: 'google.com' } } };
const admin = { uid: 'adm', token: { email: 'herokt851103@gmail.com', email_verified: true, firebase: { sign_in_provider: 'google.com' } } };

const cases = [
  // [설명, 기대, 요청, 기존 문서 data]
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
];

const testCases = cases.map(([, expectation, request, existing]) => ({
  expectation,
  request: { time: '2026-09-22T00:00:00Z', ...request },
  ...(existing ? { resource: { data: existing } } : {}),
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
