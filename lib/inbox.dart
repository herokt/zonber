import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'admin_emails.dart';
import 'push.dart';
import 'services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// 알림함 — 앱 알림 페이지(pages/inbox_page.dart). 두 곳을 합쳐 최근 순으로 보여 준다.
//   ① 친구 알림  users/{me}/inbox/{id}  {kind, from, name, zone, time, at, read}  — 서버 함수가 쓴다(functions/notify.js)
//   ② 이벤트·소식 news/{id}              {title{}, body{}, langs, audience, at}  — 백오피스 푸시를 보내면 남는다
//      읽음은 users/{me}/inbox_state/news {read: [id…]} 에(모두가 같은 문서라)
// 게스트는 친구 알림이 없고 소식만 본다 — 읽음은 적지 않는다(게스트는 아무것도 저장하지 않는다).
// 문구는 앱이 언어에 맞춰 만든다 — 친구 알림 키 inbox_{kind}(translations.dart), 소식은 문서의 언어별 제목·본문.
// ─────────────────────────────────────────────────────────────

/// 친구 알림 종류 — functions/logic.js TEXTS 와 같다
const List<String> kInboxFriendKinds = ['friend_request', 'friend_accepted', 'friend_added', 'friend_beat'];

@immutable
class InboxItem {
  final String id;

  /// friend_request · friend_accepted · friend_added · friend_beat · news
  final String kind;
  final DateTime? at;
  final bool read;

  // 친구 알림
  final String from;
  final String name;
  final String zone;
  final double? time;

  // 소식
  final Map<String, String> title;
  final Map<String, String> body;

  const InboxItem({
    required this.id,
    required this.kind,
    this.at,
    this.read = false,
    this.from = '',
    this.name = '',
    this.zone = '',
    this.time,
    this.title = const {},
    this.body = const {},
  });

  bool get isNews => kind == 'news';

  InboxItem asRead() => InboxItem(
        id: id,
        kind: kind,
        at: at,
        read: true,
        from: from,
        name: name,
        zone: zone,
        time: time,
        title: title,
        body: body,
      );

  static String _pick(Map<String, String> m, String lang) =>
      (m[lang]?.trim().isNotEmpty ?? false) ? m[lang]!.trim() : (m['en'] ?? m['ko'] ?? '').trim();
  String newsTitle(String lang) => _pick(title, lang);
  String newsBody(String lang) => _pick(body, lang);
}

class Inbox {
  static const int newsDays = 30; // functions/logic.js NEWS_DAYS
  static const int _limit = 50;

  /// 안 읽은 수 — 홈 알림 아이콘의 점
  static final ValueNotifier<int> unread = ValueNotifier(0);

  static String? get _uid {
    try {
      final u = FirebaseAuth.instance.currentUser;
      return (u == null || AuthService.isGuest) ? null : u.uid;
    } catch (_) {
      return null;
    }
  }

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _stateRef(String uid) =>
      _db.collection('users').doc(uid).collection('inbox_state').doc('news');

  static Map<String, String> _texts(Object? v) => {
        if (v is Map)
          for (final e in v.entries)
            if (e.value is String) '${e.key}': e.value as String,
      };

  /// 알림함 전부(최근 순) — 읽고 나서 안 읽은 수도 고친다
  static Future<List<InboxItem>> load({required String lang}) async {
    final me = _uid;
    final items = <InboxItem>[];

    // ① 친구 알림
    if (me != null) {
      try {
        final snap = await _db.collection('users').doc(me).collection('inbox').orderBy('at', descending: true).limit(_limit).get();
        for (final d in snap.docs) {
          final x = d.data();
          final kind = x['kind'] as String? ?? '';
          if (!kInboxFriendKinds.contains(kind)) continue;
          items.add(InboxItem(
            id: d.id,
            kind: kind,
            at: (x['at'] as Timestamp?)?.toDate(),
            read: x['read'] == true,
            from: x['from'] as String? ?? '',
            name: x['name'] as String? ?? '',
            zone: x['zone'] as String? ?? '',
            time: (x['time'] as num?)?.toDouble(),
          ));
        }
      } catch (e) {
        debugPrint('inbox load: $e');
      }
    }

    // ② 이벤트·소식 — 대상(회원·게스트·관리자)과 언어로 거른다
    try {
      final since = DateTime.now().subtract(const Duration(days: newsDays));
      final snap = await _db
          .collection('news')
          .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('at', descending: true)
          .limit(20)
          .get();
      final readIds = me == null ? const <String>{} : await _readNews(me);
      final member = me != null;
      final email = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();
      final tester = member && kAdminEmails.contains(email);
      final myLang = PushTopics.lang(lang).substring(5);
      for (final d in snap.docs) {
        final x = d.data();
        final audience = x['audience'] as String? ?? 'all';
        final ok = switch (audience) {
          'members' => member,
          'guests' => !member,
          'testers' => tester,
          _ => true,
        };
        final langs = (x['langs'] as List?)?.whereType<String>().toList() ?? const [];
        if (!ok || (langs.isNotEmpty && !langs.contains(myLang))) continue;
        items.add(InboxItem(
          id: d.id,
          kind: 'news',
          at: (x['at'] as Timestamp?)?.toDate(),
          read: !member || readIds.contains(d.id), // 게스트는 읽음을 적지 않으니 늘 읽은 것으로
          title: _texts(x['title']),
          body: _texts(x['body']),
        ));
      }
    } catch (e) {
      debugPrint('news load: $e');
    }

    items.sort((a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000)));
    unread.value = items.where((i) => !i.read).length;
    return items;
  }

  static Future<Set<String>> _readNews(String uid) async {
    try {
      final d = await _stateRef(uid).get();
      return ((d.data()?['read'] as List?) ?? const []).whereType<String>().toSet();
    } catch (_) {
      return const {};
    }
  }

  /// 한 건 읽음
  static Future<void> markRead(InboxItem item) async {
    if (item.read) return;
    final me = _uid;
    if (me == null) return;
    unread.value = (unread.value - 1).clamp(0, 999);
    try {
      if (item.isNews) {
        await _writeNewsRead(me, {item.id});
      } else {
        await _db.collection('users').doc(me).collection('inbox').doc(item.id).update({'read': true});
      }
    } catch (e) {
      debugPrint('inbox read: $e');
    }
  }

  /// 모두 읽음
  static Future<void> markAllRead(List<InboxItem> items) async {
    final me = _uid;
    if (me == null) return;
    unread.value = 0;
    try {
      final batch = _db.batch();
      var n = 0;
      for (final i in items.where((i) => !i.read && !i.isNews)) {
        batch.update(_db.collection('users').doc(me).collection('inbox').doc(i.id), {'read': true});
        n++;
      }
      if (n > 0) await batch.commit();
      final news = {for (final i in items.where((i) => !i.read && i.isNews)) i.id};
      if (news.isNotEmpty) await _writeNewsRead(me, news);
    } catch (e) {
      debugPrint('inbox read all: $e');
    }
  }

  /// 읽은 소식 id — 최근 100개만 남긴다(규칙 한도)
  static Future<void> _writeNewsRead(String uid, Set<String> ids) async {
    final have = (await _readNews(uid)).toList();
    final next = [...have.where((i) => !ids.contains(i)), ...ids];
    final keep = next.length > 100 ? next.sublist(next.length - 100) : next;
    await _stateRef(uid).set({'read': keep});
  }

  /// 안 읽은 수만 새로(홈을 열 때) — 가볍게 전부 읽는다(최대 70건)
  static Future<void> refreshUnread({required String lang}) async {
    await load(lang: lang);
  }

  static void clear() => unread.value = 0;
}
