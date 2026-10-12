import 'package:package_info_plus/package_info_plus.dart';

// ─────────────────────────────────────────────────────────────
// 앱 버전 안내 — 백오피스가 정하는 "지금 스토어에 나가 있는 버전"(2026-10-12)
//
// Firestore config/app_release 한 문서. 백오피스 › 앱 버전 에서 쓰고(관리자만), 앱이 읽는다(누구나 — 게스트도).
//   { android: {version: '2.1.0', build: 210, minBuild: 0}, ios: {...}, updatedAt, updatedBy }
// 앱은 자기 빌드 번호(pubspec version 의 + 뒤)가
//   build    보다 낮으면 → 업데이트 안내(나중에 가능)
//   minBuild 보다 낮으면 → 필수 업데이트(닫을 수 없다). 0 이면 안 쓴다
// 스토어 심사가 끝나 실제로 받을 수 있게 된 뒤에 백오피스에서 올린다 — 먼저 올리면 받을 게 없는 안내가 뜬다.
// 앱 쪽 동작·창은 lib/services/update_service.dart.
// ─────────────────────────────────────────────────────────────

/// 이 앱의 버전 — pubspec.yaml `version: 이름+빌드`(예 2.1.0+210). 앱 시작 때 [load] 한 번
class AppVersion {
  final String name; // 2.1.0
  final int build; // 210
  const AppVersion(this.name, this.build);

  /// 화면 표시 — v2.1.0 (210)
  String get label => build > 0 ? 'v$name ($build)' : 'v$name';

  /// 유저 문서에 남기는 값(못 읽었으면 비운다)
  Map<String, Object> get fields => build > 0 ? {'appVersion': name, 'appBuild': build} : const {};

  static AppVersion? _current;

  /// 읽어 둔 값(앱 시작 때 [load]) — 아직이면 null
  static AppVersion? get current => _current;

  static Future<AppVersion> load() async {
    if (_current != null) return _current!;
    try {
      final p = await PackageInfo.fromPlatform();
      _current = AppVersion(p.version, int.tryParse(p.buildNumber) ?? 0);
    } catch (_) {
      _current = const AppVersion('', 0);
    }
    return _current!;
  }
}

enum UpdateNeed { none, optional, required }

class PlatformRelease {
  /// 사람이 읽는 버전 이름(안내 창에 보인다)
  final String version;
  /// 스토어에 나가 있는 빌드 번호 — 이보다 낮은 앱에 안내
  final int build;
  /// 이보다 낮으면 필수 업데이트(0 = 안 씀)
  final int minBuild;
  const PlatformRelease({required this.version, required this.build, this.minBuild = 0});

  static PlatformRelease? fromMap(Object? m) {
    if (m is! Map) return null;
    final build = (m['build'] as num?)?.toInt() ?? 0;
    if (build <= 0) return null;
    return PlatformRelease(
      version: (m['version'] as String? ?? '').trim(),
      build: build,
      minBuild: (m['minBuild'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object> toMap() => {'version': version, 'build': build, 'minBuild': minBuild};

  /// 빌드 [current] 인 앱에 무엇을 보일지
  UpdateNeed needFor(int current) {
    if (current <= 0) return UpdateNeed.none; // 버전을 못 읽었으면 묻지 않는다
    if (minBuild > 0 && current < minBuild) return UpdateNeed.required;
    if (current < build) return UpdateNeed.optional;
    return UpdateNeed.none;
  }
}

class AppRelease {
  static const String collection = 'config';
  static const String docId = 'app_release';

  final PlatformRelease? android;
  final PlatformRelease? ios;
  final DateTime? updatedAt;
  final String updatedBy;
  const AppRelease({this.android, this.ios, this.updatedAt, this.updatedBy = ''});

  static const empty = AppRelease();

  /// [updatedAt] 은 Firestore Timestamp · DateTime 무엇이든 — 여기서는 DateTime 으로만 받는다(호출하는 쪽에서 바꾼다)
  factory AppRelease.fromMap(Map<String, dynamic>? d, {DateTime? updatedAt}) => d == null
      ? empty
      : AppRelease(
          android: PlatformRelease.fromMap(d['android']),
          ios: PlatformRelease.fromMap(d['ios']),
          updatedAt: updatedAt,
          updatedBy: d['updatedBy'] as String? ?? '',
        );

  /// 'android' · 'ios'
  PlatformRelease? of(String platform) => platform == 'ios' ? ios : (platform == 'android' ? android : null);
}
