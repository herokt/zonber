import 'package:flutter/material.dart';

import '../design_system.dart';
import '../inbox.dart';
import '../language_manager.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// 알림 페이지 — 친구 알림(요청·수락·새 친구·기록 넘음) + 이벤트·소식. 최근 순, 안 읽은 것은 점 + 굵게.
//   누르면 읽음. 친구 알림은 친구 화면으로 간다. 오른쪽 위 [모두 읽음]
// 데이터는 lib/inbox.dart. 게스트는 소식만(읽음 표시 없음).
// ─────────────────────────────────────────────────────────────
class InboxPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onOpenFriends;
  const InboxPage({super.key, required this.onBack, required this.onOpenFriends});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<InboxItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final lang = LanguageManager.of(context, listen: false).currentLanguage;
    final items = await Inbox.load(lang: lang);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _tap(int i) async {
    final item = _items[i];
    if (!item.read) {
      setState(() => _items = [..._items]..[i] = item.asRead());
      Inbox.markRead(item);
    }
    if (!item.isNews) widget.onOpenFriends();
  }

  Future<void> _readAll() async {
    await Inbox.markAllRead(_items);
    if (mounted) setState(() => _items = [for (final i in _items) i.asRead()]);
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final hasUnread = _items.any((i) => !i.read);
    return NeonScaffold(
      title: lm.translate('inbox_title'),
      showBackButton: true,
      onBack: widget.onBack,
      actions: [
        if (hasUnread && !AuthService.isGuest)
          TextButton(
            onPressed: _readAll,
            child: Text(lm.translate('inbox_read_all'), style: AppTextStyles.text(13, color: AppColors.primary, weight: FontWeight.w800)),
          ),
      ],
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 120),
                      Icon(Icons.notifications_none_rounded, size: 44, color: AppColors.textDim),
                      const SizedBox(height: 12),
                      Text(lm.translate('inbox_empty'), textAlign: TextAlign.center, style: AppTextStyles.text(14, color: AppColors.textDim)),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _row(lm, i),
                    ),
            ),
    );
  }

  (IconData, Color) _icon(InboxItem it) => switch (it.kind) {
        'friend_request' => (Icons.person_add_alt_1_rounded, AppColors.primary),
        'friend_accepted' || 'friend_added' => (Icons.people_alt_rounded, AppColors.primary),
        'friend_beat' => (Icons.local_fire_department_rounded, AppColors.secondary),
        _ => (Icons.campaign_rounded, AppColors.coin),
      };

  (String, String) _texts(LanguageManager lm, InboxItem it) {
    if (it.isNews) return (it.newsTitle(lm.currentLanguage), it.newsBody(lm.currentLanguage));
    String fill(String s) => s
        .replaceAll('{name}', it.name.isEmpty ? '?' : it.name)
        .replaceAll('{zone}', it.zone.isEmpty ? '' : lm.translate('world_${it.zone}'))
        .replaceAll('{time}', it.time == null ? '' : formatSurvival(it.time!));
    return (fill(lm.translate('inbox_${it.kind}_t')), fill(lm.translate('inbox_${it.kind}_b')));
  }

  String _ago(LanguageManager lm, DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return lm.translate('ago_now');
    if (d.inHours < 1) return lm.translate('ago_min').replaceAll('{n}', '${d.inMinutes}');
    if (d.inDays < 1) return lm.translate('ago_hour').replaceAll('{n}', '${d.inHours}');
    return lm.translate('ago_day').replaceAll('{n}', '${d.inDays}');
  }

  Widget _row(LanguageManager lm, int i) {
    final it = _items[i];
    final (icon, color) = _icon(it);
    final (title, body) = _texts(lm, it);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(i),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: it.read ? AppColors.background : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: it.read ? AppColors.line : color.withValues(alpha: 0.45)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: it.read ? 0.08 : 0.16), shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: it.read ? AppColors.textDim : color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.text(14, color: it.read ? AppColors.textDim : null, weight: it.read ? FontWeight.w600 : FontWeight.w900)),
                ),
                const SizedBox(width: 8),
                Text(_ago(lm, it.at), style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w600)),
              ]),
              const SizedBox(height: 3),
              Text(body, style: AppTextStyles.text(12.5, color: AppColors.textDim, weight: it.read ? FontWeight.w500 : FontWeight.w700)),
            ]),
          ),
          if (!it.read) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
            ),
          ],
        ]),
      ),
    );
  }
}
