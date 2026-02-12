import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  // ============================================================
  // ⚙️ AD MODE CONFIGURATION
  // ============================================================
  // Set to true for PRODUCTION ads (real revenue)
  // Set to false for TEST ads (no revenue, shows "Test Ad" label)
  //
  // ⚠️ CHANGE THIS BEFORE SUBMITTING TO APP STORE:
  // - true  = Production ads (REAL revenue)
  // - false = Test ads (NO revenue, for development)
  // ============================================================
  static const bool isReleaseMode = kReleaseMode; // 👈 Auto-detects mode
  // ============================================================

  // 📱 PRODUCTION AD IDS (Real Ads)
  // Android
  static const String androidAppId = 'ca-app-pub-2067804993393343~6812656981';
  static const String androidBannerId =
      'ca-app-pub-2067804993393343/7647867139';
  static const String androidInterstitialId =
      'ca-app-pub-2067804993393343/2890557994';
  static const String androidRewardedId =
      'ca-app-pub-2067804993393343/7032982983';

  // iOS
  static const String iosAppId = 'ca-app-pub-2067804993393343~6579695026';
  static const String iosBannerId = 'ca-app-pub-2067804993393343/8298797345';
  static const String iosInterstitialId =
      'ca-app-pub-2067804993393343/1274030470';
  static const String iosRewardedId = 'ca-app-pub-2067804993393343/8960948805';

  // 🧪 TEST AD IDS (Google's official test IDs)
  // These will show "Test Ad" label
  static const String testAndroidBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testIOSBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String testIOSInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
  static const String testAndroidRewarded =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testIOSRewarded =
      'ca-app-pub-3940256099942544/1712485313';
  // ============================================================

  // Get current mode as string for debugging
  static String get currentMode => isReleaseMode ? '🔴 PRODUCTION' : '🟢 TEST';

  // Print mode info on startup
  static void printAdMode() {
    debugPrint('');
    debugPrint('═══════════════════════════════════════');
    debugPrint('  AD MODE: $currentMode');
    if (!isReleaseMode) {
      debugPrint('  ⚠️ Using TEST ads (no revenue)');
      debugPrint('  💡 Set isReleaseMode = true for production');
    } else {
      debugPrint('  ✓ Using PRODUCTION ads');
    }
    debugPrint('═══════════════════════════════════════');
    debugPrint('');
  }

  static String get bannerAdUnitId {
    if (isReleaseMode) {
      // Production mode - use real ad IDs
      if (Platform.isAndroid) return androidBannerId;
      if (Platform.isIOS) return iosBannerId;
    } else {
      // Test mode - use Google's test ad IDs
      if (Platform.isAndroid) return testAndroidBanner;
      if (Platform.isIOS) return testIOSBanner;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get interstitialAdUnitId {
    if (isReleaseMode) {
      // Production mode - use real ad IDs
      if (Platform.isAndroid) return androidInterstitialId;
      if (Platform.isIOS) return iosInterstitialId;
    } else {
      // Test mode - use Google's test ad IDs
      if (Platform.isAndroid) return testAndroidInterstitial;
      if (Platform.isIOS) return testIOSInterstitial;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get rewardedAdUnitId {
    if (isReleaseMode) {
      // Production mode - use real ad IDs
      if (Platform.isAndroid) return androidRewardedId;
      if (Platform.isIOS) return iosRewardedId;
    } else {
      // Test mode - use Google's test ad IDs
      if (Platform.isAndroid) return testAndroidRewarded;
      if (Platform.isIOS) return testIOSRewarded;
    }
    throw UnsupportedError('Unsupported platform');
  }
}
