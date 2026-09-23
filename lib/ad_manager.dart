import 'dart:async';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';

import 'user_profile.dart';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  bool _adsDisabled = false;

  // Counter to show interstitial every N times
  int _gameOverCounter = 0;
  final int _interstitialFrequency = 5;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 동의(UMP)·ATT 를 거쳐 SDK 초기화까지 끝났을 때만 true. 그 전엔 어떤 광고도 요청하지 않는다.
  bool _sdkReady = false;
  final Completer<void> _readyCompleter = Completer<void>();

  /// initialize() 가 끝나면(성공·실패·광고 제거 무관) 완료된다. 배너는 이걸 기다린 뒤 요청한다.
  Future<void> get whenReady => _readyCompleter.future;

  /// 초기화 순서: 광고 제거 확인 → UMP 동의(EEA·영국 등 필요한 지역에서만 폼 표시)
  /// → iOS ATT 요청 → canRequestAds 일 때만 SDK 초기화.
  /// 폼이 떠 있는 동안 기다리므로 호출부는 await 하지 말고 [whenReady] 를 쓴다.
  Future<void> initialize() async {
    try {
      await _initialize();
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> _initialize() async {
    if (!_isMobile) return;

    AdHelper.printAdMode();

    await _checkAdsStatus();
    if (_adsDisabled) {
      debugPrint('🚫 Ads disabled - user purchased ad removal');
      return;
    }

    await _gatherConsent();
    if (Platform.isIOS) await _requestTrackingAuthorization();

    // 동의 정보 갱신이 실패해도(오프라인) 이전 세션의 동의로 요청 가능할 수 있다
    if (!await ConsentInformation.instance.canRequestAds()) {
      debugPrint('🚫 Ads not requested - consent not obtained');
      return;
    }

    RequestConfiguration configuration = RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
    );
    await MobileAds.instance.updateRequestConfiguration(configuration);

    await MobileAds.instance.initialize();
    _sdkReady = true;
    _loadInterstitial();
    _loadRewardedAd();
  }

  // --- 동의(UMP) · 추적 허용(ATT) ---

  /// Google UMP. 동의가 필요한 지역이면 AdMob 콘솔(개인정보 보호 및 메시지)에서 만든 폼을 띄우고 닫힐 때까지 기다린다.
  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) debugPrint('Consent form error: ${error.errorCode} ${error.message}');
        });
        if (!done.isCompleted) done.complete();
      },
      (FormError error) {
        debugPrint('Consent info update failed: ${error.errorCode} ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  /// iOS 14.5+ 추적 허용. 이미 결정된 경우 팝업 없이 지나간다.
  /// (UMP 에 IDFA 안내 메시지를 설정했다면 UMP 가 먼저 띄우고, 여기서는 notDetermined 가 아니게 된다)
  Future<void> _requestTrackingAuthorization() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // 앱이 완전히 활성화된 뒤 요청해야 팝업이 무시되지 않는다
        await Future.delayed(const Duration(milliseconds: 300));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('ATT request failed: $e');
    }
  }

  /// 설정 화면의 "광고 개인정보 설정" 버튼을 보여야 하는지 (UMP 가 요구하는 지역에서만 true)
  Future<bool> isPrivacyOptionsRequired() async {
    if (!_isMobile) return false;
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// 사용자가 동의를 다시 고를 수 있는 UMP 폼
  Future<void> showPrivacyOptions() async {
    if (!_isMobile) return;
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) debugPrint('Privacy options form error: ${error.errorCode} ${error.message}');
    });
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
  BannerAd? loadBannerAd(Function() onLoaded, {Function()? onFailed}) {
    if (!_isMobile || _adsDisabled || !_sdkReady) return null;
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
          debugPrint('Banner Ad loaded.');
          onLoaded();
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner Ad failed to load: $err');
          ad.dispose();
          onFailed?.call();
        },
      ),
    )..load();
  }

  // --- Interstitial Ad Logic ---

  bool _isInterstitialLoading = false;

  void _loadInterstitial() {
    if (!_isMobile || !_sdkReady || _adsDisabled || _isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Interstitial Ad loaded.');
          _isInterstitialLoading = false;
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  debugPrint('Interstitial Ad dismissed.');
                  ad.dispose();
                  _loadInterstitial(); // Preload next one
                },
                onAdFailedToShowFullScreenContent: (ad, err) {
                  debugPrint('Interstitial Ad failed to show: $err');
                  ad.dispose();
                  _loadInterstitial();
                },
              );
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial Ad failed to load: $err');
          _isInterstitialLoading = false;
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  /// Called when Game Over happens.
  /// Returns true if ad was shown, false otherwise.
  bool showInterstitialIfReady() {
    if (!_isMobile || _adsDisabled) return false;

    _gameOverCounter++;
    debugPrint("Game Over Count: $_gameOverCounter / $_interstitialFrequency");

    if (_gameOverCounter >= _interstitialFrequency) {
      if (_isInterstitialAdLoaded && _interstitialAd != null) {
        final ad = _interstitialAd!;
        _interstitialAd = null;
        _isInterstitialAdLoaded = false;
        ad.show();
        _gameOverCounter = 0; // Reset counter
        return true;
      } else {
        debugPrint("Interstitial Ad not ready yet or failed to load.");
        // 로드 실패(오프라인 등) 후에는 재시도가 없었다 — 여기서 다시 요청한다
        _loadInterstitial();
      }
    }
    return false;
  }

  // --- Rewarded Ad Logic ---

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  bool _isRewardedLoading = false;

  void _loadRewardedAd() {
    if (!_isMobile || !_sdkReady || _isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId, // Ensure this exists in AdHelper
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Rewarded Ad loaded.');
          _isRewardedLoading = false;
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('Rewarded Ad dismissed.');
              ad.dispose();
              _loadRewardedAd(); // Preload next one
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              debugPrint('Rewarded Ad failed to show: $err');
              ad.dispose();
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded Ad failed to load: $err');
          _isRewardedLoading = false;
          _isRewardedAdLoaded = false;
        },
      ),
    );
  }

  /// Shows a rewarded ad. Returns true if shown, false otherwise.
  /// [onReward] is called only if the user earned the reward.
  bool showRewardedAd(VoidCallback onReward) {
    if (!_isMobile) {
      // For testing on web/desktop, just grant reward immediately
      debugPrint("Dev/Web: Granting reward immediately.");
      onReward();
      return true;
    }

    if (_isRewardedAdLoaded && _rewardedAd != null) {
      final ad = _rewardedAd!;
      _rewardedAd = null;
      _isRewardedAdLoaded = false;
      ad.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('User earned reward: ${reward.amount} ${reward.type}');
          onReward();
        },
      );
      return true;
    } else {
      debugPrint("Rewarded Ad not ready yet.");
      // Try to load again for next time
      _loadRewardedAd();
      return false;
    }
  }
}
