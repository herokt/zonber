import 'dart:io'; // Add dart:io
import 'package:flutter/foundation.dart'; // Add kIsWeb
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  // Counter to show interstitial every N times
  int _gameOverCounter = 0;
  final int _interstitialFrequency = 3;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_isMobile) {
      await MobileAds.instance.initialize();
      _loadInterstitial();
    }
  }

  // --- Banner Ad Logic ---

  /// Loads a banner ad and returns the BannerAd object.
  /// If using in a Widget, remember to dispose it!
  BannerAd? loadBannerAd(Function() onLoaded) {
    if (!_isMobile) return null;
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
    if (!_isMobile) return false;
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
