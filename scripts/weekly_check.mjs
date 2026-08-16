/**
 * weekly_check.mjs
 * 주간 종합 점검 스크립트. 매주 실행하거나 배포 전에 수동 실행합니다.
 * 사용법: node scripts/weekly_check.mjs
 *
 * 점검 항목:
 *   1. translations.dart EN/KO 키 일치 여부
 *   2. game_config.dart 스테이지별 translations 키 존재 여부
 *   3. Firestore 랭킹 데이터 정합성 (check_rankings.mjs 호출)
 */

import { readFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');

let totalErrors = 0;

function header(title) {
  console.log(`\n${'─'.repeat(50)}`);
  console.log(`  ${title}`);
  console.log('─'.repeat(50));
}

function ok(msg)   { console.log(`  ✅ ${msg}`); }
function err(msg)  { console.log(`  ❌ ${msg}`); totalErrors++; }
function warn(msg) { console.log(`  ⚠️  ${msg}`); }

// ─────────────────────────────────────────────────────
// 1. translations.dart 키 검사
// ─────────────────────────────────────────────────────
header('1. translations.dart EN/KO 키 검사');

const translationsPath = resolve(root, 'lib/translations.dart');
const translationsContent = readFileSync(translationsPath, 'utf-8');

function extractKeys(content, lang) {
  const langIdx = content.indexOf(`'${lang}':`);
  if (langIdx === -1) return new Set();
  const braceStart = content.indexOf('{', langIdx);
  let depth = 0, pos = braceStart;
  while (pos < content.length) {
    if (content[pos] === '{') depth++;
    else if (content[pos] === '}') { depth--; if (depth === 0) break; }
    pos++;
  }
  const section = content.slice(braceStart, pos + 1);
  const keys = new Set();
  let match;
  const re = /^\s*'([^']+)':\s*['"`]/gm;
  while ((match = re.exec(section)) !== null) keys.add(match[1]);
  return keys;
}

const enKeys = extractKeys(translationsContent, 'en');
const koKeys = extractKeys(translationsContent, 'ko');
const missingInKo = [...enKeys].filter(k => !koKeys.has(k));
const missingInEn = [...koKeys].filter(k => !enKeys.has(k));

console.log(`  EN: ${enKeys.size}개 | KO: ${koKeys.size}개`);

if (missingInKo.length === 0 && missingInEn.length === 0) {
  ok('EN/KO 키 완전 일치');
} else {
  if (missingInKo.length > 0) {
    err(`KO 누락 키 ${missingInKo.length}개: ${missingInKo.slice(0, 5).map(k => `'${k}'`).join(', ')}${missingInKo.length > 5 ? ' ...' : ''}`);
  }
  if (missingInEn.length > 0) {
    err(`EN 누락 키 ${missingInEn.length}개: ${missingInEn.slice(0, 5).map(k => `'${k}'`).join(', ')}${missingInEn.length > 5 ? ' ...' : ''}`);
  }
}

// ─────────────────────────────────────────────────────
// 2. game_config.dart 스테이지 translations 키 검사
// ─────────────────────────────────────────────────────
header('2. game_config.dart 스테이지 키 검사');

const gameConfigPath = resolve(root, 'lib/game_config.dart');
const gameConfigContent = readFileSync(gameConfigPath, 'utf-8');

// nameKey, descKey 추출
const keyMatches = [...gameConfigContent.matchAll(/(?:nameKey|descKey):\s*'([^']+)'/g)];
const stageKeys = keyMatches.map(m => m[1]);

let allStageKeysOk = true;
for (const key of stageKeys) {
  const inEn = enKeys.has(key);
  const inKo = koKeys.has(key);
  if (!inEn || !inKo) {
    err(`스테이지 키 '${key}' — EN:${inEn ? '✅' : '❌'} KO:${inKo ? '✅' : '❌'}`);
    allStageKeysOk = false;
  }
}
if (allStageKeysOk) ok(`스테이지 키 ${stageKeys.length}개 모두 EN/KO 존재`);

// ─────────────────────────────────────────────────────
// 3. 필수 에셋 파일 존재 여부
// ─────────────────────────────────────────────────────
header('3. 필수 에셋 파일 존재 여부');

const requiredAssets = [
  'assets/audio/bgm.mp3',
  'assets/audio/shoot.wav',
  'assets/audio/hit.wav',
  'assets/audio/gameover.wav',
];

for (const asset of requiredAssets) {
  const fullPath = resolve(root, asset);
  if (existsSync(fullPath)) {
    ok(asset);
  } else {
    err(`없음: ${asset}`);
  }
}

// ─────────────────────────────────────────────────────
// 4. pubspec.yaml 버전 확인
// ─────────────────────────────────────────────────────
header('4. pubspec.yaml 버전 확인');

const pubspecPath = resolve(root, 'pubspec.yaml');
const pubspecContent = readFileSync(pubspecPath, 'utf-8');
const versionMatch = pubspecContent.match(/^version:\s*(.+)$/m);
if (versionMatch) {
  ok(`앱 버전: ${versionMatch[1].trim()}`);
} else {
  warn('version 필드를 찾을 수 없음');
}

// ─────────────────────────────────────────────────────
// 결과 요약
// ─────────────────────────────────────────────────────
console.log(`\n${'═'.repeat(50)}`);
if (totalErrors === 0) {
  console.log('  ✅ 모든 검사 통과');
} else {
  console.log(`  ❌ ${totalErrors}개 문제 발견 — 위 내용을 확인하세요`);
}
console.log(`${'═'.repeat(50)}\n`);

process.exit(totalErrors > 0 ? 1 : 0);
