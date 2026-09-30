import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────
// 푸시(FCM) 단일 출처 — 앱(services/push_service.dart) · 백오피스(backoffice/push_page.dart) ·
// 서버 함수(functions/index.js)가 같은 약속을 쓴다. 바꾸면 functions/index.js 도 같이 고친다.
//
// 보내는 길: 백오피스가 push_campaigns/{id} 문서를 만든다(status: pending) → 서버 함수가 언어별로
//   토픽 조건에 맞춰 보내고 status 를 sent/failed 로, results 에 언어별 결과를 적는다.
// 받는 길: 앱이 토픽을 구독한다 — 언어 하나(lang_ko …) + 회원/게스트 하나 + (관리자 기기면) tester.
//   알림을 끄면(설정 › 이벤트·소식 알림) 전부 구독 해제. 기기 토큰은 서버에 저장하지 않는다.
// 기획·운영법: docs/PUSH.md
// ─────────────────────────────────────────────────────────────

/// 누구에게 — 언어 토픽과 함께 조건으로 묶는다
enum PushAudience {
  /// 알림을 켜 둔 모든 기기
  all,

  /// 로그인한 회원만
  members,

  /// 게스트만(로그인 유도)
  guests,

  /// 관리자 기기만(보내기 전 시험)
  testers,
}

PushAudience _audienceOf(String? s) => PushAudience.values.firstWhere((a) => a.name == s, orElse: () => PushAudience.all);

class PushTopics {
  static const List<String> langs = ['ko', 'en', 'ja', 'zh'];
  static const String member = 'member';
  static const String guest = 'guest';
  static const String tester = 'tester';

  /// 앱 언어 → 토픽. 모르는 언어는 영어
  static String lang(String code) => 'lang_${langs.contains(code) ? code : 'en'}';

  /// 이 기기가 구독할 토픽 전부
  static Set<String> forDevice({required String lang, required bool member, required bool tester}) => {
        PushTopics.lang(lang),
        member ? PushTopics.member : PushTopics.guest,
        if (tester) PushTopics.tester,
      };

  /// 한 언어 · 대상의 FCM 조건 — functions/index.js 의 condition() 과 같다
  static String condition(String lang, PushAudience a) {
    final base = "'${PushTopics.lang(lang)}' in topics";
    return switch (a) {
      PushAudience.all => base,
      PushAudience.members => "$base && '$member' in topics",
      PushAudience.guests => "$base && '$guest' in topics",
      PushAudience.testers => "$base && '$tester' in topics",
    };
  }
}

enum PushStatus { pending, sending, sent, failed }

PushStatus _statusOf(String? s) => PushStatus.values.firstWhere((a) => a.name == s, orElse: () => PushStatus.pending);

/// 보낸(보낼) 푸시 한 건 — push_campaigns/{id}
@immutable
class PushCampaign {
  final String id;

  /// 언어별 제목·본문. ko·en 은 반드시, ja·zh 가 비면 그 언어 기기에는 영어로 간다
  final Map<String, String> title;
  final Map<String, String> body;

  /// 보낼 언어(기기 언어 기준). 비면 전부
  final List<String> langs;
  final PushAudience audience;

  /// 어느 템플릿에서 시작했나(기록용, 없으면 '')
  final String templateId;

  final PushStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? sentAt;

  /// 언어별 결과 — "ok projects/…/messages/…" · "error: …" · "skip: …"
  final Map<String, String> results;

  const PushCampaign({
    required this.id,
    required this.title,
    required this.body,
    this.langs = const [],
    this.audience = PushAudience.all,
    this.templateId = '',
    this.status = PushStatus.pending,
    this.createdBy = '',
    this.createdAt,
    this.sentAt,
    this.results = const {},
  });

  List<String> get targetLangs => langs.isEmpty ? PushTopics.langs : langs;

  /// 그 언어 기기에 실제로 가는 문구(없으면 영어)
  String titleFor(String lang) => _pick(title, lang);
  String bodyFor(String lang) => _pick(body, lang);
  static String _pick(Map<String, String> m, String lang) =>
      (m[lang]?.trim().isNotEmpty ?? false) ? m[lang]!.trim() : (m['en'] ?? '').trim();

  /// 새로 만들 때 문서 — status 는 pending, 시각은 서버 시각(규칙이 검사한다)
  Map<String, dynamic> toNewDoc() => {
        'title': title,
        'body': body,
        'langs': langs,
        'audience': audience.name,
        'templateId': templateId,
        'status': PushStatus.pending.name,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory PushCampaign.fromDoc(String id, Map<String, dynamic> d) => PushCampaign(
        id: id,
        title: _texts(d['title']),
        body: _texts(d['body']),
        langs: (d['langs'] as List?)?.whereType<String>().toList() ?? const [],
        audience: _audienceOf(d['audience'] as String?),
        templateId: d['templateId'] as String? ?? '',
        status: _statusOf(d['status'] as String?),
        createdBy: d['createdBy'] as String? ?? '',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
        sentAt: (d['sentAt'] as Timestamp?)?.toDate(),
        results: _texts(d['results']),
      );

  static Map<String, String> _texts(Object? v) => {
        if (v is Map)
          for (final e in v.entries)
            if (e.value is String) '${e.key}': e.value as String,
      };
}

/// 자주 쓰는 문구 — 백오피스에서 골라 고쳐 보낸다. 4개 언어 모두 채운다(제목 짧게, 본문 한두 줄)
@immutable
class PushTemplate {
  final String id;

  /// 백오피스에 보이는 이름
  final String name;
  final Map<String, String> title;
  final Map<String, String> body;
  const PushTemplate({required this.id, required this.name, required this.title, required this.body});
}

class PushTemplates {
  static const List<PushTemplate> all = [
    PushTemplate(
      id: 'new_event',
      name: '새 이벤트',
      title: {'ko': '🎉 새 이벤트가 열렸어요', 'en': '🎉 A new event is live', 'ja': '🎉 新しいイベント開催中', 'zh': '🎉 新活动开始了'},
      body: {
        'ko': '지금 들어오면 선물을 받을 수 있어요. 기간 한정!',
        'en': 'Jump in now to grab your gift. Limited time only!',
        'ja': '今すぐ開いてギフトを受け取ろう。期間限定！',
        'zh': '现在进入即可领取礼物，限时活动！',
      },
    ),
    PushTemplate(
      id: 'weekly_gift',
      name: '주간 선물',
      title: {'ko': '🎁 이번 주 선물이 도착했어요', 'en': '🎁 Your weekly gift is here', 'ja': '🎁 今週のギフトが届きました', 'zh': '🎁 本周礼物到了'},
      body: {
        'ko': '이벤트 화면에서 코인 받고 한 판 어때요?',
        'en': 'Grab your coins on the Events screen and play a round.',
        'ja': 'イベント画面でコインを受け取って1回遊ぼう。',
        'zh': '在活动页面领取金币，来一局吧。',
      },
    ),
    PushTemplate(
      id: 'weekly_ranking',
      name: '주간 랭킹 마감',
      title: {'ko': '🏆 주간 랭킹이 곧 마감돼요', 'en': '🏆 Weekly rankings close soon', 'ja': '🏆 週間ランキングがまもなく締め切り', 'zh': '🏆 周榜即将结算'},
      body: {
        'ko': '마지막 기회! 기록을 1초만 더 늘려 볼까요?',
        'en': 'Last chance — can you add one more second?',
        'ja': 'ラストチャンス！あと1秒記録を伸ばそう。',
        'zh': '最后机会！再多坚持一秒吧？',
      },
    ),
    PushTemplate(
      id: 'comeback',
      name: '복귀 유도',
      title: {'ko': '👋 존버가 기다리고 있어요', 'en': '👋 Your Zonber misses you', 'ja': '👋 ZONBERが待っています', 'zh': '👋 ZONBER 在等你'},
      body: {
        'ko': '오랜만이에요! 오늘은 몇 초 버틸 수 있을까요?',
        'en': "It's been a while! How long can you last today?",
        'ja': 'おひさしぶり！今日は何秒耐えられる？',
        'zh': '好久不见！今天能坚持几秒？',
      },
    ),
    PushTemplate(
      id: 'new_code',
      name: '이벤트 코드 공개',
      title: {'ko': '🎟 새 이벤트 코드 공개', 'en': '🎟 New event code dropped', 'ja': '🎟 新しいイベントコード公開', 'zh': '🎟 新兑换码发布'},
      body: {
        'ko': '공식 SNS에서 코드를 확인하고 이벤트 화면에 입력하세요.',
        'en': 'Find the code on our socials and enter it on the Events screen.',
        'ja': '公式SNSでコードを確認して、イベント画面で入力してね。',
        'zh': '在官方社媒查看兑换码，并在活动页面输入。',
      },
    ),
    PushTemplate(
      id: 'update',
      name: '업데이트 안내',
      title: {'ko': '✨ ZONBER가 업데이트됐어요', 'en': '✨ ZONBER just got an update', 'ja': '✨ ZONBERがアップデートされました', 'zh': '✨ ZONBER 更新啦'},
      body: {
        'ko': '새로워진 존을 만나 보세요. 스토어에서 업데이트해 주세요.',
        'en': 'Check out what’s new — update from the store.',
        'ja': '新しくなったゾーンを遊んでみよう。ストアからアップデートしてね。',
        'zh': '快来体验新内容，请在应用商店更新。',
      },
    ),
    PushTemplate(
      id: 'login_gift',
      name: '게스트 로그인 유도',
      title: {'ko': '🎁 로그인하면 선물이 있어요', 'en': '🎁 A gift is waiting for you', 'ja': '🎁 ログインでギフトがもらえる', 'zh': '🎁 登录即可领取礼物'},
      body: {
        'ko': '로그인하면 기록이 랭킹에 올라가고 환영 선물도 받아요.',
        'en': 'Log in to put your records on the rankings and get a welcome gift.',
        'ja': 'ログインすると記録がランキングに載り、ようこそギフトももらえます。',
        'zh': '登录后记录会上榜，还能领取欢迎礼包。',
      },
    ),
    PushTemplate(
      id: 'maintenance',
      name: '점검 안내',
      title: {'ko': '🔧 잠시 점검이 있어요', 'en': '🔧 Short maintenance ahead', 'ja': '🔧 メンテナンスのお知らせ', 'zh': '🔧 维护通知'},
      body: {
        'ko': '더 나은 게임을 위해 잠시 점검합니다. 기록은 안전하게 지켜져요.',
        'en': "We'll be down briefly to make things better. Your records are safe.",
        'ja': 'より良いゲームのため、少しの間メンテナンスします。記録は安全です。',
        'zh': '为了更好的体验将进行短暂维护，你的记录会安全保存。',
      },
    ),
  ];
}
