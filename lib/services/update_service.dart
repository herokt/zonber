import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_release.dart';
import '../design_system.dart';
import '../language_manager.dart';
import '../store_shot.dart';

// ─────────────────────────────────────────────────────────────
// 앱 버전 · 업데이트 안내(2026-10-12)
//
// 버전(AppVersion · lib/app_release.dart)은 pubspec.yaml 의 `version: 이름+빌드` 하나로 정한다(예 2.1.0+210). 화면에는 "v2.1.0 (210)",
// 로그인한 유저 문서에는 appVersion · appBuild 로 남긴다(백오피스 › 유저 상세 · 앱 버전 화면의 버전 분포).
//   이름 = 사람이 읽는 버전(기능이 크게 늘면 가운데 자리, 고친 것만이면 끝자리) · 빌드 = 스토어에 올릴 때마다 +1(줄일 수 없다)
//
// 업데이트 안내 — 백오피스 › 앱 버전 에 적은 스토어 버전의 빌드(config/app_release, lib/app_release.dart)보다 이 앱이 낮으면 홈에서 띄운다.
//   보통 안내: [나중에] 를 누르면 그 빌드는 3일 동안 다시 묻지 않는다.
//   필수(minBuild 보다 낮음): 닫을 수 없다 — [업데이트] 만. 앱을 켤 때마다·돌아올 때마다 다시 뜬다.
//   [업데이트] = 그 기기의 스토어 페이지(in_app_review openStoreListing — Play / App Store).
//   판이 끝나고 돌아올 때(리뷰·알림 창이 뜨는 때)는 띄우지 않는다. 웹·데스크톱·스토어 스크린샷 모드는 아무것도 안 한다.
// ─────────────────────────────────────────────────────────────

class UpdateService {
  static const String appStoreId = '6757195275';
  static const Duration snooze = Duration(days: 3);
  static const Duration recheck = Duration(hours: 3);
  static const _kSkipBuild = 'update_skip_build';
  static const _kSkipAt = 'update_skip_at';

  /// 지금 이 앱에 맞는 스토어 버전 · 필요 정도 — 프로필 › 앱 버전 옆 "업데이트" 표시에 쓴다
  static final ValueNotifier<(PlatformRelease, UpdateNeed)?> state = ValueNotifier(null);

  static DateTime? _checkedAt;
  static bool _shownThisSession = false;
  static bool _showing = false;
  static bool _homeSeen = false; // 이번 실행에 홈을 이미 봤나 — 보통 안내는 첫 홈 · 앱 복귀 때만

  static bool get _supported => !kIsWeb && !kStoreShot && (Platform.isAndroid || Platform.isIOS);
  static String get _platform => Platform.isIOS ? 'ios' : 'android';

  /// 백오피스에 적힌 스토어 버전을 읽어 이 앱과 견준다 — [recheck] 안에는 다시 읽지 않는다
  static Future<(PlatformRelease, UpdateNeed)?> check({bool force = false}) async {
    if (!_supported) return null;
    if (!force && _checkedAt != null && DateTime.now().difference(_checkedAt!) < recheck) return state.value;
    final cur = await AppVersion.load();
    try {
      final d = await FirebaseFirestore.instance
          .collection(AppRelease.collection)
          .doc(AppRelease.docId)
          .get()
          .timeout(const Duration(seconds: 8));
      _checkedAt = DateTime.now();
      final r = AppRelease.fromMap(d.data()).of(_platform);
      final need = r?.needFor(cur.build) ?? UpdateNeed.none;
      state.value = (r == null || need == UpdateNeed.none) ? null : (r, need);
    } catch (e) {
      debugPrint('UpdateService.check: $e'); // 오프라인 등 — 다음에 다시
    }
    return state.value;
  }

  /// 홈에서 부른다. [resumed] = 앱으로 돌아왔을 때(필수 업데이트는 다시 띄운다)
  static Future<void> maybePrompt(BuildContext context, {bool resumed = false}) async {
    final firstHome = !_homeSeen;
    _homeSeen = true;
    if (!_supported || _showing) return;
    final s = await check(force: resumed);
    if (s == null || !context.mounted) return;
    final (release, need) = s;
    final must = need == UpdateNeed.required;
    if (!must) {
      if (_shownThisSession || !(firstHome || resumed)) return;
      final prefs = await SharedPreferences.getInstance();
      final skipAt = prefs.getInt(_kSkipAt) ?? 0;
      if (prefs.getInt(_kSkipBuild) == release.build && DateTime.now().millisecondsSinceEpoch - skipAt < snooze.inMilliseconds) return;
    }
    if (!context.mounted) return;
    // 다른 창(이벤트·설정 등)이 위에 떠 있으면 이번엔 넘긴다
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _shownThisSession = true;
    _showing = true;
    final lm = LanguageManager.of(context, listen: false);
    final cur = AppVersion.current;
    final newLabel = release.version.isEmpty ? '(${release.build})' : 'v${release.version}';
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: !must,
        child: NeonDialog(
          title: lm.translate(must ? 'update_required_title' : 'update_title'),
          message: lm
              .translate(must ? 'update_required_body' : 'update_body')
              .replaceAll('{new}', newLabel)
              .replaceAll('{cur}', cur?.label ?? ''),
          barrierDismissible: !must,
          actions: [
            if (!must)
              NeonButton(text: lm.translate('update_later'), isPrimary: false, isCompact: true, onPressed: () => Navigator.pop(ctx, false)),
            NeonButton(text: lm.translate('update_now'), isCompact: true, onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    _showing = false;
    if (go == true) {
      await openStore();
      if (must) _shownThisSession = false; // 스토어에서 돌아와도 아직 옛 버전이면 다시
    } else if (!must) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kSkipBuild, release.build);
      await prefs.setInt(_kSkipAt, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// 이 기기의 스토어 페이지(Play / App Store)
  static Future<void> openStore() async {
    try {
      await InAppReview.instance.openStoreListing(appStoreId: appStoreId);
    } catch (e) {
      debugPrint('UpdateService.openStore: $e');
    }
  }
}
