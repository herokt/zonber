// 고객 지원 페이지 — stayzone-88364.web.app/support/  (App Store Connect 의 지원 URL)
//
// App Store 심사 지침 1.5: 지원 URL 은 문의 방법이 있는 페이지여야 한다(2026-10-01 반려 — 예전엔 / 가 백오피스 로그인으로 갔다).
// 한 페이지에 4개 언어 — 브라우저 언어로 먼저 보이고 위 버튼으로 바꾼다. 문의 메일은 개인정보 처리방침(privacy.html)과 같다.
// 앱 화면 이름(프로필 · 계정 · 계정 삭제)은 lib/translations.dart 와 같게 쓴다. App Store 지원 페이지라 Android·Play 는 적지 않는다(지침 2.3.10).
//
// hosting_root 는 git 에 없으니 배포 때마다 만든다 — deploy_admin.bat 이 부른다.
//   node scripts/make_support_page.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'hosting_root', 'support');

const EMAIL = 'mycrewdeveloper@gmail.com';
const APPLE_ID = '6757195275';

const L = {
  en: {
    name: 'English',
    title: 'ZONBER Support',
    intro: 'Questions, bug reports or account requests? Email us and we will reply within 3 business days.',
    contact: 'Contact us',
    tip: 'Please include your nickname, device model and app version (Profile tab, bottom).',
    faqTitle: 'FAQ',
    faq: [
      ['My records or coins disappeared.',
        'Records, coins and badges are saved only when you are signed in with Google or Apple. Playing as a guest saves nothing. Sign in with the same account you used before to get them back.'],
      ['How do I delete my account?',
        'Go to Profile tab › Account › Delete account. Your profile, records and friends are removed permanently. You can also email us to request deletion.'],
      ['How do I turn off notifications?',
        'Profile tab › Settings — turn off the weekly reminder, event & news notifications or friend notifications.'],
      ['How do I use a friend code or event code?',
        'Sign in, then open the event banner on the home screen and enter the code. Each code can be used once per account.'],
      ['Someone in the rankings is cheating.',
        'Email us with the zone, nickname and period (weekly / monthly / yearly). We review every report.'],
    ],
    privacy: 'Privacy Policy',
  },
  ko: {
    name: '한국어',
    title: 'ZONBER 고객 지원',
    intro: '궁금한 점, 버그 제보, 계정 관련 요청은 메일로 보내 주세요. 영업일 기준 3일 안에 답장드립니다.',
    contact: '문의하기',
    tip: '닉네임, 기기 모델, 앱 버전(프로필 탭 맨 아래)을 함께 적어 주시면 더 빨리 도와드릴 수 있어요.',
    faqTitle: '자주 묻는 질문',
    faq: [
      ['기록이나 코인이 사라졌어요.',
        '기록·코인·뱃지는 Google 또는 Apple 로 로그인했을 때만 저장됩니다. 게스트로 플레이하면 아무것도 저장되지 않아요. 예전에 쓰던 계정으로 다시 로그인하면 돌아옵니다.'],
      ['계정은 어떻게 삭제하나요?',
        '프로필 탭 › 계정 › 계정 삭제에서 지울 수 있습니다. 프로필·기록·친구가 영구히 삭제됩니다. 메일로 삭제를 요청하셔도 됩니다.'],
      ['알림을 끄고 싶어요.',
        '프로필 탭 › 설정에서 주간 알림, 이벤트·소식 알림, 친구 알림을 각각 끌 수 있습니다.'],
      ['친구 코드·이벤트 코드는 어디에 넣나요?',
        '로그인한 뒤 홈 화면의 이벤트 배너를 눌러 코드를 입력하세요. 코드는 계정당 한 번만 쓸 수 있어요.'],
      ['랭킹에 부정 기록이 있어요.',
        '존, 닉네임, 기간(주간·월간·연간)을 적어 메일로 알려 주세요. 모든 제보를 확인합니다.'],
    ],
    privacy: '개인정보 처리방침',
  },
  ja: {
    name: '日本語',
    title: 'ZONBER サポート',
    intro: 'ご質問、不具合の報告、アカウントに関するご依頼はメールでお送りください。3営業日以内に返信します。',
    contact: 'お問い合わせ',
    tip: 'ニックネーム、端末の機種、アプリのバージョン（プロフィールタブの一番下）を書いていただくと、より早く対応できます。',
    faqTitle: 'よくある質問',
    faq: [
      ['記録やコインが消えました。',
        '記録・コイン・バッジは、Google または Apple でログインしているときだけ保存されます。ゲストでプレイすると何も保存されません。以前のアカウントでもう一度ログインすると戻ります。'],
      ['アカウントを削除するには？',
        'プロフィールタブ › アカウント › アカウント削除 から削除できます。プロフィール・記録・フレンドは完全に削除されます。メールで削除をご依頼いただくこともできます。'],
      ['通知をオフにしたい。',
        'プロフィールタブ › 設定 で、週間リマインダー、イベント・お知らせ通知、フレンド通知をそれぞれオフにできます。'],
      ['フレンドコード・イベントコードはどこに入力しますか？',
        'ログイン後、ホーム画面のイベントバナーを開いてコードを入力してください。コードは1アカウントにつき1回使えます。'],
      ['ランキングに不正な記録があります。',
        'ゾーン、ニックネーム、期間（週間・月間・年間）をメールでお知らせください。すべての報告を確認します。'],
    ],
    privacy: 'プライバシーポリシー',
  },
  zh: {
    name: '中文',
    title: 'ZONBER 客户支持',
    intro: '如有疑问、问题反馈或账号相关请求，请发送邮件给我们，我们会在 3 个工作日内回复。',
    contact: '联系我们',
    tip: '请附上你的昵称、设备型号和应用版本（“我的”页面底部），以便我们更快处理。',
    faqTitle: '常见问题',
    faq: [
      ['我的记录或金币不见了。',
        '只有使用 Google 或 Apple 登录时，记录、金币和徽章才会被保存。以游客身份游玩不会保存任何数据。使用之前的账号重新登录即可恢复。'],
      ['如何删除账号？',
        '前往“我的” › 账号 › 删除账号。你的资料、记录和好友将被永久删除。也可以发邮件请求删除。'],
      ['如何关闭通知？',
        '在“我的” › 设置 中，可以分别关闭每周提醒、活动与消息通知、好友通知。'],
      ['好友码或活动码在哪里输入？',
        '登录后，点击主页上的活动横幅并输入代码。每个代码每个账号只能使用一次。'],
      ['排行榜上有作弊记录。',
        '请通过邮件告诉我们区域、昵称和时间段（周榜 / 月榜 / 年榜），我们会核查每一条举报。'],
    ],
    privacy: '隐私政策',
  },
};

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const mail = (lang) => `mailto:${EMAIL}?subject=${encodeURIComponent(`[ZONBER] ${L[lang].title}`)}`;

const sections = Object.entries(L).map(([lang, t]) => `
<section lang="${lang}" data-lang="${lang}">
  <h1>${esc(t.title)}</h1>
  <p>${esc(t.intro)}</p>
  <a class="btn" href="${mail(lang)}">${esc(t.contact)} — ${EMAIL}</a>
  <p class="tip">${esc(t.tip)}</p>
  <h2>${esc(t.faqTitle)}</h2>
  ${t.faq.map(([q, a]) => `<details><summary>${esc(q)}</summary><p>${esc(a)}</p></details>`).join('\n  ')}
  <p class="links"><a href="/privacy.html">${esc(t.privacy)}</a></p>
</section>`).join('\n');

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ZONBER Support</title>
<meta name="description" content="ZONBER: Dodge &amp; Survive — support, FAQ and contact">
<meta name="apple-itunes-app" content="app-id=${APPLE_ID}">
<link rel="icon" type="image/png" href="/get/icon.png">
<style>
  :root { --bg: #0b0d12; --surface: #151922; --line: #262c38; --text: #f2f4f8; --dim: #9aa3b2; --accent: #37e0ff; }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--text); line-height: 1.6;
         font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Apple SD Gothic Neo", "Noto Sans KR", "Hiragino Sans", "PingFang SC", sans-serif; }
  main { max-width: 680px; margin: 0 auto; padding: 32px 16px 64px; }
  header { display: flex; align-items: center; gap: 12px; margin-bottom: 20px; }
  header img { width: 48px; height: 48px; border-radius: 12px; }
  header b { font-size: 20px; letter-spacing: 2px; }
  nav { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 28px; }
  nav button { background: var(--surface); color: var(--dim); border: 1px solid var(--line); border-radius: 999px;
               padding: 6px 14px; font-size: 14px; cursor: pointer; }
  nav button.on { color: #041018; background: var(--accent); border-color: var(--accent); font-weight: 700; }
  h1 { font-size: 24px; margin: 0 0 8px; }
  h2 { font-size: 18px; margin: 32px 0 12px; }
  p { color: var(--dim); margin: 0 0 12px; }
  .tip { font-size: 14px; }
  a { color: var(--accent); }
  a.btn { display: block; text-align: center; padding: 14px 16px; margin: 16px 0 10px; border-radius: 14px;
          background: var(--accent); color: #041018; font-weight: 800; text-decoration: none; word-break: break-all; }
  details { background: var(--surface); border: 1px solid var(--line); border-radius: 12px; padding: 12px 16px; margin-bottom: 8px; }
  summary { cursor: pointer; font-weight: 700; }
  details p { margin: 10px 0 0; }
  .links { margin-top: 28px; font-size: 14px; }
  footer { margin-top: 40px; font-size: 13px; color: var(--dim); }
  footer a { margin-right: 12px; }
</style>
</head>
<body>
<main>
  <header><img src="/get/icon.png" alt=""><b>ZONBER</b></header>
  <nav>${Object.entries(L).map(([lang, t]) => `<button type="button" data-pick="${lang}">${t.name}</button>`).join('')}</nav>
  ${sections}
  <footer>
    <a href="https://apps.apple.com/app/id${APPLE_ID}">App Store</a>
    <span>${EMAIL}</span>
  </footer>
</main>
<script>
  var langs = ${JSON.stringify(Object.keys(L))};
  function show(lang) {
    document.querySelectorAll('section[data-lang]').forEach(function (s) { s.hidden = s.dataset.lang !== lang; });
    document.querySelectorAll('nav button').forEach(function (b) { b.classList.toggle('on', b.dataset.pick === lang); });
    document.documentElement.lang = lang;
  }
  var want = (new URLSearchParams(location.search).get('lang') || navigator.language || 'en').slice(0, 2).toLowerCase();
  show(langs.indexOf(want) >= 0 ? want : 'en');
  document.querySelectorAll('nav button').forEach(function (b) { b.onclick = function () { show(b.dataset.pick); }; });
</script>
</body>
</html>
`;

mkdirSync(out, { recursive: true });
writeFileSync(join(out, 'index.html'), html);
console.log(`support page → ${join(out, 'index.html')}`);
