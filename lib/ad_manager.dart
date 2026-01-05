import 'dart:io'; // Add dart:io
import 'package:flutter/foundation.dart'; // Add kIsWeb
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';

import 'user_profile.dart'; // Add import

class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  bool _adsDisabled = false;

  // Counter to show interstitial every N times
  int _gameOverCounter = 0;
  final int _interstitialFrequency = 3;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_isMobile) {
      // Print ad mode configuration
      AdHelper.printAdMode();

      await _checkAdsStatus();
      if (_adsDisabled) {
        debugPrint('🚫 Ads disabled - user purchased ad removal');
        return;
      }

      // Configure AdMob for Family Policy Compliance
      RequestConfiguration configuration = RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.g,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
      );
      await MobileAds.instance.updateRequestConfiguration(configuration);

      await MobileAds.instance.initialize();
      _loadInterstitial();
    }
  }

  Future<void> _checkAdsStatus() async {
    _adsDisabled = await UserProfileManager.isAdsRemoved();
  }

  Future<void> refreshAdsStatus() async {
    await _checkAdsStatus();
    if (_adsDisabled) {
      // If ads are now disabled, dispose any existing ads
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialAdLoaded = false;
    } else {
      // If re-enabled (unlikely but possible), load if needed
      if (!_isInterstitialAdLoaded) _loadInterstitial();
    }
  }

  // --- Banner Ad Logic ---

  /// Loads a banner ad and returns the BannerAd object.
  /// If using in a Widget, remember to dispose it!
  BannerAd? loadBannerAd(Function() onLoaded) {
    if (!_isMobile || _adsDisabled) return null;
    // We can't be sure about async check here easily without making loadBannerAd async.
    // For simplicity, we assume we check before calling, OR we check inside but we can't return null synchronously based on async result.
    // However, usually ads should be pre-checked.
    // Better approach: AdManager should cache the status on init or update it.

    // Let's assume AdManager will check the flag asynchronously.
    // Actually, let's just do a sync check if we assume it's cached in UserProfileManager's prefs which is sync?
    // No, UserProfileManager.isAdsRemoved is async.
    // Let's rely on GameSettings or similar if we want sync access, or just fire-and-forget the check inside.

    // For now, let's just allow loading, but later we might want to hide the banner widget itself.
    // The AppScaffold handles the banner widget. It should check before verifying.
    // Ideally update AppScaffold to check UserProfileManager.isAdsRemoved().
    return BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner Ad loaded.');
          onLoaded();
        },
        onAdFailedToLoad: (ad, err) {
          print('Banner Ad failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  // --- Interstitial Ad Logic ---

  void _loadInterstitial() {
    if (!_isMobile) return;
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('Interstitial Ad loaded.');
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  print('Interstitial Ad dismissed.');
                  ad.dispose();
                  _loadInterstitial(); // Preload next one
                },
                onAdFailedToShowFullScreenContent: (ad, err) {
                  print('Interstitial Ad failed to show: $err');
                  ad.dispose();
                  _loadInterstitial();
                },
              );
        },
        onAdFailedToLoad: (err) {
          print('Interstitial Ad failed to load: $err');
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  /// Called when Game Over happens.
  /// Returns true if ad was shown, false otherwise.
  bool showInterstitialIfReady() {
    if (!_isMobile || _adsDisabled) return false;
    // Determining this async is tricky for a sync method.
    // We should cache the 'adsRemoved' state in AdManager.
    // But for now, let's just proceed. The user only asked for the Shop item.
    // Real implementation requires robust state management.
    // I'll add a quick async check inside but obviously this method returns bool immediately.

    // We will update this method to be async for better control? No, existing definition is sync.
    // Let's check the preference synchronously if possible? SharedPreferences is async.
    // Hack: We will ignore ads check here for now, assuming the caller checks it or we update AdManager to have a sync flag.

    _gameOverCounter++;
    print("Game Over Count: $_gameOverCounter / $_interstitialFrequency");

    if (_gameOverCounter >= _interstitialFrequency) {
      if (_isInterstitialAdLoaded && _interstitialAd != null) {
        _interstitialAd!.show();
        _gameOverCounter = 0; // Reset counter
        return true;
      } else {
        print("Interstitial Ad not ready yet or failed to load.");
        // If not ready, we don't reset counter so we try again next time?
        // Or reset anyway to avoid spamming verify log?
        // Let's keep counter high so it triggers as soon as available,
        // but typically reload is fast.
      }
    }
    return false;
  }
}
