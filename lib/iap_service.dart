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

  // 상품 ID - Google Play Console에서 동일하게 설정 필요
  static const String removeAdsId = 'remove_ads';
  static const String nicknameTicketId = 'nickname_ticket';
  static const String countryTicketId = 'country_ticket';

  static const Set<String> _productIds = {
    removeAdsId,
    nicknameTicketId,
    countryTicketId,
  };

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  // 구매 완료 콜백
  Function(String productId)? onPurchaseSuccess;
  Function(String error)? onPurchaseError;

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

    // 구매 스트림 리스닝
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (error) {
        debugPrint('IAP stream error: $error');
      },
    );

    // 상품 정보 로드
    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (!_isAvailable) {
      debugPrint('IAP: Store not available');
      return;
    }

    debugPrint('IAP: Querying products: $_productIds');
    final response = await _iap.queryProductDetails(_productIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('IAP ERROR: Products not found: ${response.notFoundIDs}');
      debugPrint('IAP ERROR: Make sure products are registered in App Store Connect or use StoreKit Configuration in Xcode');
    }

    _products = response.productDetails;
    debugPrint('IAP: Loaded ${_products.length} products');
    for (var product in _products) {
      debugPrint('IAP: Product available: ${product.id} - ${product.price} ${product.currencyCode}');
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
      onPurchaseError?.call('Store not available');
      return false;
    }

    final product = getProduct(productId);
    if (product == null) {
      onPurchaseError?.call('Product not found');
      return false;
    }

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
    if (!_isAvailable) return;
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('Purchase pending: ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // 구매 완료 처리
          await _deliverProduct(purchase);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          onPurchaseSuccess?.call(purchase.productID);
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

  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    switch (purchase.productID) {
      case removeAdsId:
        await UserProfileManager.setAdsRemoved(true);
        await AdManager().refreshAdsStatus();
        debugPrint('Ads removed!');
        break;

      case nicknameTicketId:
        await UserProfileManager.addNicknameTicket(1);
        debugPrint('Nickname ticket added!');
        break;

      case countryTicketId:
        await UserProfileManager.addCountryTicket(1);
        debugPrint('Country ticket added!');
        break;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
