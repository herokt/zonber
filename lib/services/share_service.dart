import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'analytics_service.dart';

/// 공유 링크 단일 출처 — 공유 문구에 붙는 주소는 여기서만 만든다.
///
/// 링크는 스토어가 아니라 공유용 페이지(stayzone-88364.web.app/get/{lang}/)다.
/// 그 페이지가 OS 를 보고 Play / App Store 로 보내면서 출처(UTM·캠페인)를 붙이고,
/// 카톡·디스코드에는 미리보기(og:)가 뜬다. 페이지는 `node scripts/make_share_page.mjs` 가 만든다.
class ShareLinks {
  static const String landing = 'https://stayzone-88364.web.app/get';
  static const Set<String> _langs = {'ko', 'en', 'ja', 'zh'};

  /// [src] = 어디서 공유했나(result · promo) — 스토어 캠페인 이름으로 넘어간다.
  /// [code] = 내 친구 코드 — 페이지가 코드를 크게 보여 주고, 설치 버튼을 누르면 복사해 준다(친구가 외울 필요 없게)
  static String url({required String lang, required String src, String? code}) =>
      '$landing/${_langs.contains(lang) ? lang : 'en'}/?src=$src${code == null ? '' : '&c=$code'}';
}

enum ShareOutcome { shared, dismissed, copied }

/// OS 공유 창(카톡·인스타·메신저)을 띄운다. 못 띄우는 기기는 문구를 복사한다.
/// 공유 창을 닫기만 하면 [ShareOutcome.dismissed] — 보상을 주지 않는다.
/// Android 는 공유했는지 알려 주지 않아 닫은 게 아니면 공유한 것으로 친다.
///
/// [image] 를 주면 그림 + 문구로 보낸다. 그림을 받으면 문구를 버리는 앱(인스타·카톡 일부)이 있어
/// 그때는 문구(링크)를 클립보드에도 넣어 둔다 — 붙여넣기로 링크를 살린다.
class ShareService {
  static Future<ShareOutcome> share({
    required String text,
    required String src,
    required String itemId,
    Rect? origin,
    XFile? image,
  }) async {
    try {
      if (image != null) await Clipboard.setData(ClipboardData(text: text));
      // iPad 는 공유 창을 띄울 자리(버튼 위치)가 있어야 한다
      final r = await SharePlus.instance.share(ShareParams(
        text: text,
        subject: 'ZONBER',
        files: image == null ? null : [image],
        sharePositionOrigin: origin,
      ));
      if (r.status == ShareResultStatus.dismissed) return ShareOutcome.dismissed;
      AnalyticsService().logShare(src: src, itemId: itemId, method: r.raw.isEmpty ? 'os' : r.raw, withImage: image != null);
      return ShareOutcome.shared;
    } catch (e) {
      debugPrint('share failed: $e');
      await Clipboard.setData(ClipboardData(text: text));
      AnalyticsService().logShare(src: src, itemId: itemId, method: 'clipboard');
      return ShareOutcome.copied;
    }
  }
}
