// 공유용 페이지 — stayzone-88364.web.app/get/{ko,en,ja,zh}/
//
// 앱의 공유 문구(lib/services/share_service.dart · ShareLinks)가 이 주소를 붙인다.
//   · 휴대폰에서 열면 OS 에 맞는 스토어로 바로 보낸다 — Android → Play, iPhone·iPad → App Store
//   · 스토어 주소에 출처를 붙인다 — Play: referrer=utm_source=share&utm_medium={src} (Firebase 가 설치 캠페인으로 잡는다)
//                                   App Store: ct=share_{src} (APPLE_PT 를 채워야 App Store Connect 캠페인으로 잡힌다)
//   · 카톡·디스코드·X 에 붙이면 미리보기(og:)가 뜬다 — 그림은 Play 그래픽 이미지(store/feature_graphic/{lang}.png)
//   · 컴퓨터에서 열면 두 스토어 버튼만 보인다
//   · ?c=친구코드 가 붙어 오면(공유 문구의 링크) 바로 넘기지 않고 코드를 크게 보여 준다 —
//     설치 버튼을 누르면 코드를 복사하고 스토어로 간다(친구가 코드를 외울 필요 없게). Play 에는 utm_content=코드 로도 넘긴다
//
// hosting_root 는 git 에 없으니 배포 때마다 만든다 — deploy_admin.bat 이 부른다.
//   node scripts/make_share_page.mjs
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'hosting_root', 'get');
const base = 'https://stayzone-88364.web.app/get';

const PACKAGE = 'com.zonber.game';
const APPLE_ID = '6757195275';
// App Store Connect › 앱 분석 › 획득 › 캠페인 링크 만들기 에 나오는 pt 값(제공자 토큰). 비어 있으면 ct 도 붙이지 않는다
const APPLE_PT = '';

// 친구 코드를 넣은 사람이 받는 코인 — 앱 값(lib/promotions.dart FriendCodes.newcomerCoins)을 그대로 읽는다
const FRIEND_COINS = Number(
  /newcomerCoins\s*=\s*(\d+)/.exec(readFileSync(join(root, 'lib', 'promotions.dart'), 'utf8'))?.[1] ?? 0,
);
if (!FRIEND_COINS) throw new Error('FriendCodes.newcomerCoins 를 lib/promotions.dart 에서 못 찾았다');

const L = {
  ko: {
    locale: 'ko_KR',
    title: 'ZONBER — 탄막 피하기 생존 게임',
    desc: '좁은 존에서 끝까지 버텨라! 갤럭시·피구·프리킥, 손가락 하나로 피하고 막는 생존 게임. 친구 기록 깨러 가기',
    cta: '설치하고 도전하기',
    going: '스토어로 이동 중…',
    codeLabel: '친구 코드',
    codeHint: '설치하고 로그인한 뒤 이벤트 화면에 넣으면 코인 {n}',
    codeCta: '코드 복사하고 설치하기',
    copied: '코드를 복사했어요',
  },
  en: {
    locale: 'en_US',
    title: 'ZONBER — Dodge & Survive',
    desc: 'Stay in the zone and survive! Galaxy, Dodgeball and FreeKick — dodge and block with one finger. Come beat my record.',
    cta: 'Install & take the challenge',
    going: 'Opening the store…',
    codeLabel: 'Friend code',
    codeHint: 'Install, log in and enter it under Events for {n} coins',
    codeCta: 'Copy code & install',
    copied: 'Code copied',
  },
  ja: {
    locale: 'ja_JP',
    title: 'ZONBER — 弾幕よけサバイバル',
    desc: '狭いゾーンで最後まで耐えろ！ギャラクシー・ドッジボール・フリーキック、指1本でかわして止めるサバイバルゲーム。友だちの記録を超えよう。',
    cta: 'インストールして挑戦',
    going: 'ストアを開いています…',
    codeLabel: '友だちコード',
    codeHint: 'インストールしてログイン後、イベント画面で入力するとコイン{n}',
    codeCta: 'コードをコピーしてインストール',
    copied: 'コードをコピーしました',
  },
  zh: {
    locale: 'zh_CN',
    title: 'ZONBER — 躲弹幕生存挑战',
    desc: '待在狭小区域里，坚持到最后！银河、躲避球、任意球，一根手指闪避与扑救的生存游戏。来打破好友的记录吧。',
    cta: '安装并挑战',
    going: '正在打开商店…',
    codeLabel: '好友码',
    codeHint: '安装并登录后，在活动页面输入即可获得 {n} 金币',
    codeCta: '复制好友码并安装',
    copied: '已复制好友码',
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
  #code { display: none; background: var(--surface); border: 1px solid var(--accent); border-radius: 16px;
          padding: 14px 16px; margin: 0 0 14px; }
  #code .label { font-size: 12px; color: var(--dim); font-weight: 700; }
  #code .value { font-size: 34px; font-weight: 900; letter-spacing: 6px; color: var(--accent); margin: 4px 0; }
  #code .hint { font-size: 13px; color: var(--dim); line-height: 1.45; }
</style>
</head>
<body>
<main>
  <img class="icon" src="${base}/icon.png" alt="ZONBER">
  <h1>ZONBER</h1>
  <p>${esc(t.desc)}</p>
  <div id="code">
    <div class="label">${esc(t.codeLabel)}</div>
    <div class="value" id="codeValue"></div>
    <div class="hint">${esc(t.codeHint.replace('{n}', String(FRIEND_COINS)))}</div>
  </div>
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
  // 친구 코드 — 앱과 같은 형식(영문 대문자·숫자 4~5자)만 받는다
  var code = (q.get('c') || '').toUpperCase();
  if (!/^[A-Z0-9]{4,5}$/.test(code)) code = '';
  var play = 'https://play.google.com/store/apps/details?id=${PACKAGE}&referrer=' +
    encodeURIComponent('utm_source=share&utm_medium=' + src + '&utm_campaign=share_' + lang +
      (code ? '&utm_content=' + code : ''));
  var pt = ${JSON.stringify(APPLE_PT)};
  var ios = 'https://apps.apple.com/app/apple-store/id${APPLE_ID}' +
    (pt ? '?pt=' + pt + '&ct=' + encodeURIComponent('share_' + src) + '&mt=8' : '');
  var ua = navigator.userAgent || '';
  var isIOS = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var isAndroid = /Android/.test(ua);
  document.getElementById('play').href = play;
  document.getElementById('ios').href = ios;
  var cta = document.getElementById('cta');
  var going = document.getElementById('going');

  function copy(text) {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) return navigator.clipboard.writeText(text).catch(fallback);
    } catch (e) {}
    fallback();
    return Promise.resolve();
    function fallback() {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); } catch (e) {}
      document.body.removeChild(ta);
    }
  }

  if (code) {
    // 코드가 있으면 바로 넘기지 않는다 — 코드를 보여 주고, 설치 버튼(누르는 순간)에 복사한다
    document.getElementById('code').style.display = 'block';
    document.getElementById('codeValue').textContent = code;
    cta.textContent = ${JSON.stringify(t.codeCta)};
    var links = isIOS ? [cta] : isAndroid ? [cta] : [document.getElementById('play'), document.getElementById('ios')];
    if (isIOS || isAndroid) {
      cta.href = isIOS ? ios : play;
      document.getElementById('play').style.display = 'none';
      document.getElementById('ios').style.display = 'none';
    } else {
      cta.style.display = 'none';
    }
    links.forEach(function (a) {
      a.addEventListener('click', function (ev) {
        ev.preventDefault();
        var href = a.href;
        copy(code).then(function () {
          going.textContent = ${JSON.stringify(t.copied)};
          setTimeout(function () { location.href = href; }, 350);
        });
      });
    });
    return;
  }

  if (isIOS || isAndroid) {
    var target = isIOS ? ios : play;
    cta.href = target;
    document.getElementById(isIOS ? 'play' : 'ios').style.display = 'none';
    document.getElementById(isIOS ? 'ios' : 'play').style.display = 'none';
    going.textContent = ${JSON.stringify(t.going)};
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
