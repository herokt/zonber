// 스토어 이미지 문구·색 — Play(compose_store_shots.mjs)와 App Store(compose_ios_shots.mjs)가 같이 쓴다.
// 화면 이름은 스크린샷 모드(lib/store_shot_run.dart)가 찍는 이름과 같다.

// 화면마다 배경(위→아래) · 강조색 · 상태바 글자색(앱 화면 위쪽이 어두우면 light)
export const THEMES = {
  '01_galaxy': { bg: ['#262B45', '#1C2653'], hl: '#3DE3CB', bar: 'light' },
  '02_dodgeball': { bg: ['#EC9A45', '#D35E26'], hl: '#FFE68C', bar: 'dark' },
  '03_keeper': { bg: ['#46B472', '#2F9657'], hl: '#DDF76E', bar: 'dark' },
  '04_result': { bg: ['#E0564A', '#B3302A'], hl: '#FFE08A', bar: 'dark' },
  '05_rival': { bg: ['#4257D8', '#27349E'], hl: '#9FE8FF', bar: 'dark' },
  '06_ranking': { bg: ['#2997B2', '#0F5F7A'], hl: '#FFCC55', bar: 'dark' },
  '07_bag': { bg: ['#8E70F2', '#5537CC'], hl: '#FFBCE8', bar: 'dark' },
  '08_badges': { bg: ['#D39A12', '#A56F05'], hl: '#FFF4B8', bar: 'dark' },
  '09_events': { bg: ['#EE6A9A', '#C23C72'], hl: '#FFE9A6', bar: 'dark' },
  '10_home': { bg: ['#262B45', '#1B2A5A'], hl: '#3DE3CB', bar: 'dark' },
};

// 문구 — [ ] 안은 강조색. \n 은 줄바꿈(iPad 처럼 넓은 틀에서는 부제의 \n 을 한 칸 띄움으로 바꾼다)
export const CAPTIONS = {
  ko: {
    '01_galaxy': ['[존]에서 [버]터라', '사방에서 쏟아지는 탄막,\n몇 초나 버틸 수 있을까?'],
    '02_dodgeball': ['날아오는 [공]을 피해라', '한 턴에 한 번,\n점점 빨라지는 피구공'],
    '03_keeper': ['[골문]을 지켜라', '감아차기, 총알슛,\n무회전까지 막아라'],
    '04_result': ['[신기록]을 자랑하라', '세계 순위와 친구 코드를 담아\n바로 공유'],
    '05_rival': ['[이 기록] 깨러 가기', '랭커를 골라 그 기록을 목표로,\n넘는 순간 바로 알려 줘요'],
    '06_ranking': ['[세계 1위]에 도전하라', '주간·월간·연간 랭킹,\n나라별 순위까지'],
    '07_bag': ['나만의 [존버] 꾸미기', '캐릭터 8종,\n존마다 다른 장비'],
    '08_badges': ['뱃지 [46]종 수집', '생존, 기술, 랭킹,\n수집, 출석까지'],
    '09_events': ['[선물]이 쏟아진다', '환영 선물, 친구 코드,\n매일 공유 보상'],
    '10_home': ['[3]개의 존, [3]가지 생존', '우주, 피구장,\n그리고 페널티 박스'],
  },
  en: {
    '01_galaxy': ['HOLD OUT\nIN THE [ZONE]', 'Bullets from every side.\nHow long can you last?'],
    '02_dodgeball': ['DODGE\nEVERY [THROW]', 'One throw a turn —\nthen faster and faster.'],
    '03_keeper': ['GUARD\nTHE [GOAL]', 'Curlers, rockets\nand knuckleballs.'],
    '04_result': ['SHOW OFF\nYOUR [BEST]', 'Share your time and world rank\nthe moment a run ends.'],
    '05_rival': ['CHASE\nTHEIR [RECORD]', 'Pick any ranked player\nand race their time.'],
    '06_ranking': ['BEAT\nTHE [WORLD]', 'Weekly, monthly and yearly\nrankings — by country, too.'],
    '07_bag': ['DRESS UP\nYOUR [ZONBER]', '8 characters and\ngear for every zone.'],
    '08_badges': ['COLLECT\n[46] BADGES', 'Survival, skill, rankings,\ncollecting and check-ins.'],
    '09_events': ['GIFTS\nEVERY [DAY]', 'Welcome gift, friend codes\nand daily share rewards.'],
    '10_home': ['[3] ZONES,\n[3] WAYS TO SURVIVE', 'Deep space, the dodgeball court\nand the penalty box.'],
  },
  ja: {
    '01_galaxy': ['[ゾーン]で耐え抜け', '四方から迫る弾幕、\n何秒耐えられる？'],
    '02_dodgeball': ['すべての[球]をかわせ', '1ターンに1球、\nどんどん速くなる'],
    '03_keeper': ['[ゴール]を守り抜け', 'カーブ、ロケット、\nそして無回転'],
    '04_result': ['[新記録]を自慢しよう', '世界順位もフレンドコードも\nそのままシェア'],
    '05_rival': ['[この記録]を超えにいく', 'ランカーを選んで\nその記録に挑戦'],
    '06_ranking': ['[世界1位]をめざせ', '週間・月間・年間ランキング、\n国別順位も'],
    '07_bag': ['自分だけの[ZONBER]', 'キャラクター8種、\nゾーンごとの装備'],
    '08_badges': ['バッジ[46]種を集めよう', '生存、テクニック、ランキング、\nコレクション、出席まで'],
    '09_events': ['[ギフト]がどっさり', '歓迎ギフト、フレンドコード、\n毎日のシェア報酬'],
    '10_home': ['[3]つのゾーン、[3]つの戦い', '宇宙、ドッジボールコート、\nそしてペナルティエリア'],
  },
  zh: {
    '01_galaxy': ['在[区域]中坚持住', '弹幕四面袭来，\n你能撑多久？'],
    '02_dodgeball': ['躲开每一[球]', '每回合一球，\n越来越快'],
    '03_keeper': ['守住[球门]', '弧线球、火箭球，\n还有电梯球'],
    '04_result': ['炫耀你的[新纪录]', '全球排名和好友代码\n一键分享'],
    '05_rival': ['去打破[这个记录]', '选一位排行榜玩家，\n以他的成绩为目标'],
    '06_ranking': ['挑战[世界第一]', '周榜、月榜、年榜，\n还有国家排行'],
    '07_bag': ['打造你的[ZONBER]', '8个角色，\n每个区域专属装备'],
    '08_badges': ['收集[46]枚徽章', '生存、技巧、排名、\n收集、签到'],
    '09_events': ['[好礼]送不停', '欢迎礼、好友代码、\n每日分享奖励'],
    '10_home': ['[3]个区域，[3]种挑战', '太空、躲避球场，\n还有禁区'],
  },
};

export const FONT = {
  ko: "'Noto Sans KR'",
  en: "'Sora', 'Noto Sans KR'",
  ja: "'Noto Sans JP'",
  zh: "'Noto Sans SC'",
};

export const FONTS_LINK =
  'https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@500;900&family=Noto+Sans+KR:wght@500;900&family=Noto+Sans+SC:wght@500;900&family=Manrope:wght@600&family=Roboto:wght@500&family=Sora:wght@800&display=block';

export const CHROME_PATHS = [
  process.env.CHROME,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
];
