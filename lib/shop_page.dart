import 'package:flutter/material.dart';
import 'design_system.dart';
import 'user_profile.dart';
import 'language_manager.dart';
import 'ad_manager.dart';

class ShopPage extends StatefulWidget {
  final VoidCallback onBack;

  const ShopPage({super.key, required this.onBack});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int _nicknameTickets = 0;
  int _countryTickets = 0;
  bool _adsRemoved = false;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final nicknameTickets = await UserProfileManager.getNicknameTickets();
    final countryTickets = await UserProfileManager.getCountryTickets();
    final adsRemoved = await UserProfileManager.isAdsRemoved();
    setState(() {
      _nicknameTickets = nicknameTickets;
      _countryTickets = countryTickets;
      _adsRemoved = adsRemoved;
    });
  }

  Future<void> _purchaseNicknameTicket() async {
    setState(() => _isPurchasing = true);
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate
    await UserProfileManager.addNicknameTicket(1);
    await _loadData();
    setState(() => _isPurchasing = false);
    if (mounted) _showPurchaseSuccessDialog('Nickname Change Ticket');
  }

  Future<void> _purchaseCountryTicket() async {
    setState(() => _isPurchasing = true);
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate
    await UserProfileManager.addCountryTicket(1);
    await _loadData();
    setState(() => _isPurchasing = false);
    if (mounted) _showPurchaseSuccessDialog('Country Change Ticket');
  }

  Future<void> _purchaseRemoveAds() async {
    if (_adsRemoved) return;
    setState(() => _isPurchasing = true);

    // TODO: Implement In-App Purchase properly
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate

    await UserProfileManager.setAdsRemoved(true);
    await AdManager().refreshAdsStatus(); // Update AdManager
    await _loadData();
    setState(() => _isPurchasing = false);

    if (mounted) {
      showNeonDialog(
        context: context,
        title: "ADS REMOVED!",
        titleColor: const Color(0xFF00FF88),
        message: "Thank you for your purchase.\nAds will no longer appear.",
        actions: [
          NeonButton(
            text: LanguageManager.of(context).translate('ok'),
            onPressed: () {
              Navigator.pop(context);
              // Optionally trigger AdManager update/refresh
            },
          ),
        ],
      );
    }
  }

  void _showPurchaseSuccessDialog(String itemName) {
    showNeonDialog(
      context: context,
      title: LanguageManager.of(context).translate('purchase_success'),
      titleColor: const Color(0xFF00FF88),
      message:
          "${LanguageManager.of(context).translate('purchase_message')}$itemName",
      actions: [
        NeonButton(
          text: LanguageManager.of(context).translate('ok'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      title: LanguageManager.of(context).translate('shop_title'),
      showBackButton: true,
      onBack: widget.onBack,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // My Tickets Section (Compact)
            Text(
              LanguageManager.of(context).translate('my_tickets'),
              style: TextStyle(
                color: const Color(0xFFFFD700),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOwnedTicket(
                    LanguageManager.of(context).translate('nickname'),
                    _nicknameTickets,
                    Icons.badge,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOwnedTicket(
                    LanguageManager.of(context).translate('country'),
                    _countryTickets,
                    Icons.flag,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Shop Items Section
            Text(
              LanguageManager.of(context).translate('shop'),
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            // Remove Ads
            _buildShopItem(
              title: "REMOVE ADS",
              description: "Play without interruptions",
              icon: Icons.block,
              price: _adsRemoved ? "OWNED" : "\$1.99",
              isPurchased: _adsRemoved,
              onPurchase: _purchaseRemoveAds,
              color: const Color(0xFFFF4081), // Pinkish Red
            ),
            const SizedBox(height: 12),

            // Nickname Change Ticket
            _buildShopItem(
              title: LanguageManager.of(context).translate('ticket_nickname'),
              description: LanguageManager.of(
                context,
              ).translate('ticket_nickname_desc'),
              icon: Icons.badge,
              price: "\$0.99",
              onPurchase: _purchaseNicknameTicket,
            ),
            const SizedBox(height: 12),

            // Country Change Ticket
            _buildShopItem(
              title: LanguageManager.of(context).translate('ticket_country'),
              description: LanguageManager.of(
                context,
              ).translate('ticket_country_desc'),
              icon: Icons.flag,
              price: "\$0.99",
              onPurchase: _purchaseCountryTicket,
            ),
            const SizedBox(height: 32),
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
    required String title,
    required String description,
    required IconData icon,
    required String price,
    required VoidCallback onPurchase,
    bool isPurchased = false,
    Color? color,
  }) {
    final itemColor = color ?? AppColors.primary;

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
          _isPurchasing && !isPurchased
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
                  onTap: isPurchased ? null : onPurchase,
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
