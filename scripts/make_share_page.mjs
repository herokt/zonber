// 공유용 페이지 — stayzone-88364.web.app/get/{ko,en,ja,zh}/
//
// 앱의 공유 문구(lib/services/share_service.dart · ShareLinks)가 이 주소를 붙인다.
//   · 휴대폰에서 열면 OS 에 맞는 스토어로 바로 보낸다 — Android → Play, iPhone·iPad → App Store
//   · 스토어 주소에 출처를 붙인다 — Play: referrer=utm_source=share&utm_medium={src} (Firebase 가 설치 캠페인으로 잡는다)
//                                   App Store: ct=share_{src} (APPLE_PT 를 채워야 App Store Connect 캠페인으로 잡힌다)
//   · 카톡·디스코드·X 에 붙이면 미리보기(og:)가 뜬다 — 그림은 Play 그래픽 이미지(store/feature_graphic/{lang}.png)
//   · 컴퓨터에서 열면 두 스토어 버튼만 보인다
//
// hosting_root 는 git 에 없으니 배포 때마다 만든다 — deploy_admin.bat 이 부른다.
//   node scripts/make_share_page.mjs
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'hosting_root', 'get');
const base = 'https://stayzone-88364.web.app/get';

const PACKAGE = 'com.zonber.game';
const APPLE_ID = '6757195275';
// App Store Connect › 앱 분석 › 획득 › 캠페인 링크 만들기 에 나오는 pt 값(제공자 토큰). 비어 있으면 ct 도 붙이지 않는다
const APPLE_PT = '';

const L = {
  ko: {
    locale: 'ko_KR',
    title: 'ZONBER — 탄막 피하기 생존 게임',
    desc: '좁은 존에서 끝까지 버텨라! 갤럭시·피구·프리킥, 손가락 하나로 피하고 막는 생존 게임. 친구 기록 깨러 가기',
    cta: '설치하고 도전하기',
    going: '스토어로 이동 중…',
  },
  en: {
    locale: 'en_US',
    title: 'ZONBER — Dodge & Survive',
    desc: 'Stay in the zone and survive! Galaxy, Dodgeball and FreeKick — dodge and block with one finger. Come beat my record.',
    cta: 'Install & take the challenge',
    going: 'Opening the store…',
  },
  ja: {
    locale: 'ja_JP',
    title: 'ZONBER — 弾幕よけサバイバル',
    desc: '狭いゾーンで最後まで耐えろ！ギャラクシー・ドッジボール・フリーキック、指1本でかわして止めるサバイバルゲーム。友だちの記録を超えよう。',
    cta: 'インストールして挑戦',
    going: 'ストアを開いています…',
  },
  zh: {
    locale: 'zh_CN',
    title: 'ZONBER — 躲弹幕生存挑战',
    desc: '待在狭小区域里，坚持到最后！银河、躲避球、任意球，一根手指闪避与扑救的生存游戏。来打破好友的记录吧。',
    cta: '安装并挑战',
    going: '正在打开商店…',
  },
};

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function page(lang, dir) {
  const t = L[lang];
  const url = dir ? `${base}/${lang}/` : `${base}/`;
  const og = `${base}/og_${lang}.png`;
  return `<!DOCTYPE html>
<html lang="${lang}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(t.title)}</title>
<meta name="description" content="${esc(t.desc)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="ZONBER">
<meta property="og:locale" content="${t.locale}">
<meta property="og:url" content="${url}">
<meta property="og:title" content="${esc(t.title)}">
<meta property="og:description" content="${esc(t.desc)}">
<meta property="og:image" content="${og}">
<meta property="og:image:width" content="1024">
<meta property="og:image:height" content="500">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(t.title)}">
<meta name="twitter:description" content="${esc(t.desc)}">
<meta name="twitter:image" content="${og}">
<meta name="apple-itunes-app" content="app-id=${APPLE_ID}">
<link rel="icon" type="image/png" href="${base}/icon.png">
<style>
  :root { --bg: #0b0d12; --surface: #151922; --line: #262c38; --text: #f2f4f8; --dim: #9aa3b2; --accent: #37e0ff; }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; background: var(--bg); color: var(--text);
         font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
         display: flex; align-items: center; justify-content: center; padding: 24px 16px; }
  main { width: 100%; max-width: 420px; text-align: center; }
  img.icon { width: 96px; height: 96px; border-radius: 22px; }
  h1 { font-size: 26px; margin: 18px 0 6px; letter-spacing: 1px; }
  p { color: var(--dim); line-height: 1.55; margin: 0 0 24px; font-size: 15px; }
  a.btn { display: block; padding: 15px 16px; border-radius: 14px; margin-top: 10px; text-decoration: none;
          font-weight: 800; font-size: 16px; background: var(--surface); color: var(--text); border: 1px solid var(--line); }
  a.btn.main { background: var(--accent); color: #041018; border-color: var(--accent); }
  #going { font-size: 13px; margin-top: 16px; color: var(--dim); min-height: 1em; }
</style>
</head>
<body>
<main>
  <img class="icon" src="${base}/icon.png" alt="ZONBER">
  <h1>ZONBER</h1>
  <p>${esc(t.desc)}</p>
  <a class="btn main" id="cta" href="#">${esc(t.cta)}</a>
  <a class="btn" id="play" href="#">Google Play</a>
  <a class="btn" id="ios" href="#">App Store</a>
  <div id="going"></div>
</main>
<script>
(function () {
  var q = new URLSearchParams(location.search);
  var src = (q.get('src') || 'link').replace(/[^a-z0-9_]/gi, '').slice(0, 20) || 'link';
  var lang = ${JSON.stringify(lang)};
  var play = 'https://play.google.com/store/apps/details?id=${PACKAGE}&referrer=' +
    encodeURIComponent('utm_source=share&utm_medium=' + src + '&utm_campaign=share_' + lang);
  var pt = ${JSON.stringify(APPLE_PT)};
  var ios = 'https://apps.apple.com/app/apple-store/id${APPLE_ID}' +
    (pt ? '?pt=' + pt + '&ct=' + encodeURIComponent('share_' + src) + '&mt=8' : '');
  var ua = navigator.userAgent || '';
  var isIOS = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var isAndroid = /Android/.test(ua);
  document.getElementById('play').href = play;
  document.getElementById('ios').href = ios;
  var cta = document.getElementById('cta');
  if (isIOS || isAndroid) {
    var target = isIOS ? ios : play;
    cta.href = target;
    document.getElementById(isIOS ? 'play' : 'ios').style.display = 'none';
    document.getElementById(isIOS ? 'ios' : 'play').style.display = 'none';
    document.getElementById('going').textContent = ${JSON.stringify(t.going)};
    location.replace(target);
  } else {
    cta.style.display = 'none';
  }
})();
</script>
</body>
</html>
`;
}

mkdirSync(out, { recursive: true });
for (const lang of Object.keys(L)) {
  mkdirSync(join(out, lang), { recursive: true });
  writeFileSync(join(out, lang, 'index.html'), page(lang, true));
  copyFileSync(join(root, 'store', 'feature_graphic', `${lang}.png`), join(out, `og_${lang}.png`));
}
writeFileSync(join(out, 'index.html'), page('en', false)); // 언어 없는 /get/ 은 영어
copyFileSync(join(root, 'store', 'play_icon_512.png'), join(out, 'icon.png'));
console.log(`share page → ${out} (ko · en · ja · zh)`);
