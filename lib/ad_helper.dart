import 'dart:io';

class AdHelper {
  // ============================================================
  // [Release Configuration]
  // Change this to TRUE before building for Production Release!
  static const bool isReleaseMode = false;

  // ENTER YOUR REAL IDS HERE:
  static const String androidAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY';
  static const String androidBannerId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String androidInterstitialId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ';

  static const String iosBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/AAAAAAAAAA';
  static const String iosInterstitialId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB';
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
