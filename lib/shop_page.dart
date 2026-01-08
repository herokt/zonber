import 'package:flutter/material.dart';
import 'dart:io';
import 'design_system.dart';
import 'user_profile.dart';
import 'language_manager.dart';
import 'iap_service.dart';
import 'ad_manager.dart';

class ShopPage extends StatefulWidget {
  final VoidCallback onBack;
  final Future<void> Function()? onPurchaseReset;

  const ShopPage({
    super.key,
    required this.onBack,
    this.onPurchaseReset,
  });

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int _nicknameTickets = 0;
  int _countryTickets = 0;
  bool _adsRemoved = false;
  bool _isPurchasing = false;
  String? _purchasingProductId;

  final IAPService _iapService = IAPService();

  @override
  void initState() {
    super.initState();
    // _loadData();
    // _setupIAPCallbacks();
  }

  void _setupIAPCallbacks() {
    _iapService.onPurchaseSuccess = (productId) {
      _loadData();
      setState(() {
        _isPurchasing = false;
        _purchasingProductId = null;
      });
      if (mounted) {
        _showPurchaseSuccessDialog(_getProductName(productId));
      }
    };

    _iapService.onPurchaseError = (error) {
      setState(() {
        _isPurchasing = false;
        _purchasingProductId = null;
      });
      if (mounted) {
        _showErrorDialog(error);
      }
    };

    _iapService.onRestoreComplete = (restoredCount) {
      _loadData();
      setState(() => _isPurchasing = false);
      if (mounted) {
        _showRestoreResultDialog(restoredCount);
      }
    };
  }

  String _getProductName(String productId) {
    if (productId == IAPService.removeAdsId) {
      return 'Remove Ads';
    } else if (productId == IAPService.nicknameTicketId) {
      return 'Nickname Change Ticket';
    } else if (productId == IAPService.countryTicketId) {
      return 'Country Change Ticket';
    } else {
      return productId;
    }
  }

  Future<void> _loadData() async {
    final nicknameTickets = await UserProfileManager.getNicknameTickets();
    final countryTickets = await UserProfileManager.getCountryTickets();
    final adsRemoved = await UserProfileManager.isAdsRemoved();
    if (mounted) {
      setState(() {
        _nicknameTickets = nicknameTickets;
        _countryTickets = countryTickets;
        _adsRemoved = adsRemoved;
      });
    }
  }

  Future<void> _purchaseProduct(String productId) async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _purchasingProductId = productId;
    });

    final success = await _iapService.buyProduct(productId);
    if (!success && mounted) {
      setState(() {
        _isPurchasing = false;
        _purchasingProductId = null;
      });
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isPurchasing = true);
    await _iapService.restorePurchases();
    // Result will be handled by onRestoreComplete callback
  }

  Future<void> _resetPurchases() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '⚠️ RESET PURCHASES (TEST)',
          style: TextStyle(color: AppColors.secondary, fontSize: 16),
        ),
        content: Text(
          'This will reset all purchases and tickets.\nThis is for testing only.',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('RESET', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPurchasing = true);

    print('📍 RESET: Starting purchase reset');

    // Mark all products as manually reset (to prevent auto-restoration)
    await UserProfileManager.markPurchaseAsManuallyReset(IAPService.removeAdsId);
    await UserProfileManager.markPurchaseAsManuallyReset(IAPService.nicknameTicketId);
    await UserProfileManager.markPurchaseAsManuallyReset(IAPService.countryTicketId);
    print('📍 RESET: Marked all purchases as manually reset');

    // Reset all purchases
    await UserProfileManager.setAdsRemoved(false);
    print('📍 RESET: Ads removed set to false');

    await UserProfileManager.setNicknameTickets(0);
    print('📍 RESET: Nickname tickets reset');

    await UserProfileManager.setCountryTickets(0);
    print('📍 RESET: Country tickets reset');

    // Small delay to ensure Firebase writes complete
    await Future.delayed(Duration(milliseconds: 500));
    print('📍 RESET: Waited for Firebase sync');

    // Refresh AdManager status to re-enable ads
    await AdManager().refreshAdsStatus();
    print('📍 RESET: AdManager refreshed');

    // Notify parent to refresh purchase status and reload banner ad
    if (widget.onPurchaseReset != null) {
      await widget.onPurchaseReset!();
      print('📍 RESET: Parent notified to refresh ads');
    }

    await _loadData();
    setState(() => _isPurchasing = false);

    print('📍 RESET: Reset complete');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔄 All purchases reset successfully',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.secondary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showPurchaseSuccessDialog(String itemName) {
    final langManager = LanguageManager.of(context, listen: false);
    showNeonDialog(
      context: context,
      title: langManager.translate('purchase_success'),
      titleColor: const Color(0xFF00FF88),
      message:
          "${langManager.translate('purchase_message')}$itemName",
      actions: [
        NeonButton(
          text: langManager.translate('ok'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showErrorDialog(String error) {
    // During development, products may not be registered in the store
    // Log the error but don't show intrusive dialogs for "product not available"
    if (error.contains('not available') || error.contains('registered in the store')) {
      print('IAP Error (expected during development): $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Platform.isIOS
                ? 'Shop features require products to be registered in App Store Connect'
                : 'Shop features require products to be registered in Google Play Console',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: AppColors.surface,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show dialog for other errors
    final langManager = LanguageManager.of(context, listen: false);
    showNeonDialog(
      context: context,
      title: 'Error',
      titleColor: AppColors.secondary,
      message: error,
      actions: [
        NeonButton(
          text: langManager.translate('ok'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showRestoreResultDialog(int restoredCount) {
    final langManager = LanguageManager.of(context, listen: false);
    final String title;
    final Color titleColor;
    final String message;

    if (restoredCount > 0) {
      title = langManager.translate('restore_success');
      titleColor = const Color(0xFF00FF88);
      message = restoredCount == 1
          ? langManager.translate('restore_success_message_single')
          : langManager.translate('restore_success_message_multiple').replaceAll('{count}', restoredCount.toString());
    } else {
      title = langManager.translate('restore_complete');
      titleColor = AppColors.textDim;
      message = langManager.translate('restore_no_items');
    }

    showNeonDialog(
      context: context,
      title: title,
      titleColor: titleColor,
      message: message,
      actions: [
        NeonButton(
          text: langManager.translate('ok'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  String _getPrice(String productId, String defaultPrice) {
    final product = _iapService.getProduct(productId);
    return product?.price ?? defaultPrice;
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      title: LanguageManager.of(context).translate('shop_title'),
      showBackButton: true,
      onBack: widget.onBack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart, size: 64, color: AppColors.textDim),
            const SizedBox(height: 16),
            Text(
              "COMING SOON",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Shop is currently unavailable.",
              style: TextStyle(color: AppColors.textDim),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnedTicket(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: count > 0
              ? const Color(0xFFFFD700).withOpacity(0.5)
              : AppColors.textDim.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: count > 0 ? const Color(0xFFFFD700) : AppColors.textDim,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textDim,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "$count",
            style: TextStyle(
              color: count > 0 ? const Color(0xFFFFD700) : AppColors.textDim,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItem({
    required String productId,
    required String title,
    required String description,
    required IconData icon,
    required String defaultPrice,
    bool isPurchased = false,
    Color? color,
  }) {
    final itemColor = color ?? AppColors.primary;
    final isLoading = _isPurchasing && _purchasingProductId == productId;
    final price = isPurchased ? "OWNED" : _getPrice(productId, defaultPrice);

    return NeonCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: itemColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: itemColor.withOpacity(0.3)),
            ),
            child: Icon(icon, color: itemColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(color: AppColors.textDim, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          isLoading
              ? SizedBox(
                  width: 60,
                  height: 30,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: const Color(0xFF00FF88),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: isPurchased || _isPurchasing
                      ? null
                      : () => _purchaseProduct(productId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPurchased
                          ? Colors.grey.withOpacity(0.2)
                          : const Color(0xFF00FF88).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPurchased
                            ? Colors.grey
                            : const Color(0xFF00FF88),
                      ),
                    ),
                    child: Text(
                      price,
                      style: TextStyle(
                        color: isPurchased
                            ? Colors.grey
                            : const Color(0xFF00FF88),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
