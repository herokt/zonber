import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'user_profile.dart';
import 'ad_manager.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Android Product IDs
  static const String _androidRemoveAdsId = 'remove_ads';
  static const String _androidNicknameTicketId = 'nickname_ticket';
  static const String _androidCountryTicketId = 'country_ticket';

  // iOS Product IDs
  static const String _iosRemoveAdsId = 'com.zonber.game.remove_ads';
  static const String _iosNicknameTicketId = 'com.zonber.game.nickname_ticket';
  static const String _iosCountryTicketId = 'com.zonber.game.country_ticket';

  static String get removeAdsId => Platform.isIOS ? _iosRemoveAdsId : _androidRemoveAdsId;
  static String get nicknameTicketId => Platform.isIOS ? _iosNicknameTicketId : _androidNicknameTicketId;
  static String get countryTicketId => Platform.isIOS ? _iosCountryTicketId : _androidCountryTicketId;

  static Set<String> get _productIds => {
    removeAdsId,
    nicknameTicketId,
    countryTicketId,
  };

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  int _restoredCount = 0;
  bool _isRestoring = false;

  // 구매 완료 콜백
  Function(String productId)? onPurchaseSuccess;
  Function(String error)? onPurchaseError;
  Function(int restoredCount)? onRestoreComplete;

  Future<void> initialize() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      _isAvailable = false;
      return;
    }

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('IAP not available');
      return;
    }

    // 구매 스트림 리스닝 (미완료 구매도 자동으로 이 스트림으로 전달됨)
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (error) {
        debugPrint('IAP stream error: $error');
      },
    );

    // 상품 정보 로드
    await loadProducts();

    // 앱 시작 시 미완료 구매 처리 (Android/iOS 모두)
    // 결제는 했지만 앱 크래시 등으로 완료되지 않은 구매 처리
    await _handlePendingPurchases();

    // 앱 재설치 후 자동 복원 (비소모성 상품)
    // 사용자가 앱 재설치 후에도 광고 제거 상태 유지
    await _checkAndRestorePreviousPurchases();
  }

  Future<void> loadProducts() async {
    if (!_isAvailable) {
      debugPrint('IAP not available, skipping product load');
      return;
    }

    try {
      final response = await _iap.queryProductDetails(_productIds);

      if (response.error != null) {
        debugPrint('Error loading products: ${response.error}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('WARNING: Products not found in store: ${response.notFoundIDs}');
        debugPrint('These products must be registered in Google Play Console / App Store Connect');
      }

      _products = response.productDetails;
      debugPrint('Successfully loaded ${_products.length} products');
      for (var product in _products) {
        debugPrint('  - ${product.id}: ${product.title} (${product.price})');
      }
    } catch (e) {
      debugPrint('Exception while loading products: $e');
    }
  }

  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> buyProduct(String productId) async {
    if (!_isAvailable) {
      debugPrint('Purchase failed: IAP not available');
      onPurchaseError?.call('In-app purchases are not available on this device');
      return false;
    }

    final product = getProduct(productId);
    if (product == null) {
      debugPrint('Purchase failed: Product $productId not found in loaded products');
      debugPrint('Available products: ${_products.map((p) => p.id).toList()}');
      onPurchaseError?.call('Product not available. Please make sure products are registered in the store.');
      return false;
    }

    debugPrint('Starting purchase for: ${product.id} (${product.title})');

    final purchaseParam = PurchaseParam(productDetails: product);

    try {
      // 비소모성 (광고 제거) vs 소모성 (티켓)
      if (productId == removeAdsId) {
        return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        return await _iap.buyConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      onPurchaseError?.call(e.toString());
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      onRestoreComplete?.call(0);
      return;
    }

    _isRestoring = true;
    _restoredCount = 0;

    try {
      await _iap.restorePurchases();
      // Wait a bit for restore stream to complete
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Restore error: $e');
      onPurchaseError?.call(e.toString());
    } finally {
      _isRestoring = false;
      onRestoreComplete?.call(_restoredCount);
      _restoredCount = 0;
    }
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('Purchase pending: ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Verify receipt (TODO: implement server-side verification)
          final verified = await _verifyReceipt(purchase);
          if (!verified) {
            debugPrint('Receipt verification failed for: ${purchase.productID}');
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            if (purchase.status == PurchaseStatus.purchased) {
              onPurchaseError?.call('Purchase verification failed');
            }
            break;
          }

          // 구매 완료 처리
          final delivered = await _deliverProduct(purchase);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

          if (delivered) {
            // Track restored purchases separately
            if (purchase.status == PurchaseStatus.restored && _isRestoring) {
              _restoredCount++;
            } else if (purchase.status == PurchaseStatus.purchased) {
              onPurchaseSuccess?.call(purchase.productID);
            }
          } else {
            debugPrint('Failed to deliver product: ${purchase.productID}');
            if (purchase.status == PurchaseStatus.purchased) {
              onPurchaseError?.call('Failed to process purchase');
            }
          }
          break;

        case PurchaseStatus.error:
          debugPrint('Purchase error: ${purchase.error}');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          onPurchaseError?.call(purchase.error?.message ?? 'Purchase failed');
          break;

        case PurchaseStatus.canceled:
          debugPrint('Purchase canceled');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  // TODO: Implement server-side receipt verification for production
  // This method should send the purchase receipt to your backend server
  // and verify it with Apple/Google servers before delivering the product
  Future<bool> _verifyReceipt(PurchaseDetails purchase) async {
    // TODO: Send receipt to your backend server for verification
    // Example:
    // final response = await http.post(
    //   Uri.parse('https://your-backend.com/api/verify-receipt'),
    //   body: {
    //     'receipt': purchase.verificationData.serverVerificationData,
    //     'productId': purchase.productID,
    //     'platform': Platform.isAndroid ? 'android' : 'ios',
    //   },
    // );
    // return response.statusCode == 200;

    // For now, we skip verification (NOT SECURE FOR PRODUCTION)
    debugPrint('WARNING: Receipt verification not implemented. Implement server-side verification before production!');
    return true;
  }

  Future<bool> _deliverProduct(PurchaseDetails purchase) async {
    try {
      if (purchase.productID == removeAdsId) {
        await UserProfileManager.setAdsRemoved(true);
        await AdManager().refreshAdsStatus();
        debugPrint('Ads removed!');
      } else if (purchase.productID == nicknameTicketId) {
        await UserProfileManager.addNicknameTicket(1);
        debugPrint('Nickname ticket added!');
      } else if (purchase.productID == countryTicketId) {
        await UserProfileManager.addCountryTicket(1);
        debugPrint('Country ticket added!');
      } else {
        debugPrint('Unknown product ID: ${purchase.productID}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error delivering product ${purchase.productID}: $e');
      return false;
    }
  }

  // 앱 시작 시 미완료 구매 처리
  // 결제는 했지만 완료되지 않은 트랜잭션 처리 (Android/iOS 모두)
  // in_app_purchase 3.x: restorePurchases 호출 시 구매 내역이 자동으로 purchaseStream으로 전달됨
  Future<void> _handlePendingPurchases() async {
    try {
      debugPrint('Checking for pending purchases...');
      // restorePurchases를 호출하면 미완료 구매도 함께 스트림으로 전달됨
      // 스트림 리스너가 이미 설정되어 있으므로 자동으로 처리됨
      await _iap.restorePurchases();
      debugPrint('Pending purchases check initiated');
    } catch (e) {
      debugPrint('Error handling pending purchases: $e');
    }
  }

  // 앱 재설치 후 자동 복원 (비소모성 상품만)
  // SharedPreferences는 앱 재설치 시 삭제되므로, 실제 구매 상태와 동기화
  Future<void> _checkAndRestorePreviousPurchases() async {
    try {
      // 현재 로컬에 저장된 광고 제거 상태 확인
      final localAdsRemoved = await UserProfileManager.isAdsRemoved();

      // 이미 광고가 제거된 상태면 스킵
      if (localAdsRemoved) {
        debugPrint('Ads already removed locally, skipping auto-restore');
        return;
      }

      debugPrint('Checking for previous non-consumable purchases...');

      // in_app_purchase 3.x: restorePurchases 호출 시 구매 내역이 purchaseStream으로 전달됨
      // _isRestoring 플래그는 사용하지 않고, 복원된 구매는 자동으로 _onPurchaseUpdated에서 처리됨
      // 단, 여기서는 조용히 복원만 하고 사용자에게 알림은 표시하지 않음
      await _iap.restorePurchases();

      debugPrint('Previous purchases restore initiated');
    } catch (e) {
      debugPrint('Error checking previous purchases: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
