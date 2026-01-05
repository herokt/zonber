import 'dart:io';

class AdHelper {
  // ============================================================
  // [Release Configuration]
  // Change this to TRUE before building for Production Release!
  static const bool isReleaseMode = false;

  // PRODUCTION AD IDS:
  static const String androidAppId = 'ca-app-pub-6473787525002068~6688045231';
  static const String androidBannerId =
      'ca-app-pub-6473787525002068/3635163028';
  static const String androidInterstitialId =
      'ca-app-pub-6473787525002068/3498581598';
  static const String androidRewardedId =
      'ca-app-pub-6473787525002068/6452047990';

  // iOS PRODUCTION AD IDS:
  static const String iosAppId = 'ca-app-pub-6473787525002068~6193043609';
  static const String iosBannerId = 'ca-app-pub-6473787525002068/8037442465';
  static const String iosInterstitialId =
      'ca-app-pub-6473787525002068/7246254917';
  static const String iosRewardedId =
      'ca-app-pub-6473787525002068/7710139403';
  // ============================================================

  static String get bannerAdUnitId {
    if (isReleaseMode) {
      if (Platform.isAndroid) return androidBannerId;
      if (Platform.isIOS) return iosBannerId;
    }
    // Test IDs
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    throw UnsupportedError('Unsupported platform');
  }

  static String get interstitialAdUnitId {
    if (isReleaseMode) {
      if (Platform.isAndroid) return androidInterstitialId;
      if (Platform.isIOS) return iosInterstitialId;
    }
    // Test IDs
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/1033173712';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910';
    throw UnsupportedError('Unsupported platform');
  }
}
