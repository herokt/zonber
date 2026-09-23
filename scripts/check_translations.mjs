/**
 * check_translations.mjs
 * translations.dart에서 EN/KO 키 누락을 검사합니다.
 * 사용법: node scripts/check_translations.mjs
 */

import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const filePath = resolve(__dirname, '../lib/translations.dart');

let content;
try {
  content = readFileSync(filePath, 'utf-8');
} catch (e) {
  console.error(`❌ translations.dart 읽기 실패: ${e.message}`);
  process.exit(1);
}

/**
 * 특정 언어 섹션 내의 모든 키를 추출합니다.
 */
function extractKeys(content, lang) {
  const langIdx = content.indexOf(`'${lang}':`);
  if (langIdx === -1) return new Set();

  const braceStart = content.indexOf('{', langIdx);
  let depth = 0;
  let pos = braceStart;

  while (pos < content.length) {
    if (content[pos] === '{') depth++;
    else if (content[pos] === '}') {
      depth--;
      if (depth === 0) break;
    }
    pos++;
  }

  const section = content.slice(braceStart, pos + 1);
  const keyPattern = /'([^']+)':\s*['"`]/g; // 한 줄에 키가 여러 개여도 모두
  const keys = new Set();
  let match;
  while ((match = keyPattern.exec(section)) !== null) {
    keys.add(match[1]);
  }
  return keys;
}

const enKeys = extractKeys(content, 'en');
const koKeys = extractKeys(content, 'ko');

const missingInKo = [...enKeys].filter(k => !koKeys.has(k)).sort();
const missingInEn = [...koKeys].filter(k => !enKeys.has(k)).sort();

console.log('\n=== translations.dart 키 검사 ===');
console.log(`EN 키: ${enKeys.size}개 | KO 키: ${koKeys.size}개`);

// 준비 중인 언어(중국어·일본어) — 채운 비율만 알려 준다(비어 있는 키는 앱에서 영어로 보인다)
for (const lang of ['zh', 'ja']) {
  const keys = extractKeys(content, lang);
  if (keys.size === 0) continue;
  const extra = [...keys].filter(k => !enKeys.has(k));
  console.log(`${lang.toUpperCase()} 준비 중: ${keys.size}/${enKeys.size}개 번역` + (extra.length ? ` · EN에 없는 키 ${extra.join(', ')}` : ''));
}

if (missingInKo.length === 0 && missingInEn.length === 0) {
  console.log('✅ EN/KO 키가 모두 일치합니다.\n');
  process.exit(0);
} else {
  if (missingInKo.length > 0) {
    console.log(`\n❌ KO에 없는 키 (${missingInKo.length}개):`);
    missingInKo.forEach(k => console.log(`   - '${k}'`));
  }
  if (missingInEn.length > 0) {
    console.log(`\n❌ EN에 없는 키 (${missingInEn.length}개):`);
    missingInEn.forEach(k => console.log(`   - '${k}'`));
  }
  console.log('');
  process.exit(1);
}
