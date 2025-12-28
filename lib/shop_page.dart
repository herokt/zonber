import 'package:flutter/material.dart';
import 'design_system.dart';
import 'user_profile.dart';
import 'language_manager.dart';

class ShopPage extends StatefulWidget {
  final VoidCallback onBack;

  const ShopPage({super.key, required this.onBack});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int _nicknameTickets = 0;
  int _countryTickets = 0;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final nicknameTickets = await UserProfileManager.getNicknameTickets();
    final countryTickets = await UserProfileManager.getCountryTickets();
    setState(() {
      _nicknameTickets = nicknameTickets;
      _countryTickets = countryTickets;
    });
  }

  Future<void> _purchaseNicknameTicket() async {
    setState(() => _isPurchasing = true);

    // TODO: Implement actual in-app purchase here
    // For now, simulate purchase with a delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulate successful purchase
    await UserProfileManager.addNicknameTicket(1);
    await _loadTickets();

    setState(() => _isPurchasing = false);

    if (mounted) {
      _showPurchaseSuccessDialog('Nickname Change Ticket');
    }
  }

  Future<void> _purchaseCountryTicket() async {
    setState(() => _isPurchasing = true);

    // TODO: Implement actual in-app purchase here
    await Future.delayed(const Duration(milliseconds: 500));

    await UserProfileManager.addCountryTicket(1);
    await _loadTickets();

    setState(() => _isPurchasing = false);

    if (mounted) {
      _showPurchaseSuccessDialog('Country Change Ticket');
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
            // My Tickets Section
            NeonCard(
              borderColor: const Color(0xFFFFD700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: const Color(0xFFFFD700),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        LanguageManager.of(context).translate('my_tickets'),
                        style: TextStyle(
                          color: const Color(0xFFFFD700),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOwnedTicket(
                          "Nickname",
                          _nicknameTickets,
                          Icons.badge,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOwnedTicket(
                          "Country",
                          _countryTickets,
                          Icons.flag,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Shop Items Section
            Text(
              LanguageManager.of(context).translate('change_tickets'),
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
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
            const SizedBox(height: 24),

            // Info Text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.textDim.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textDim, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      LanguageManager.of(context).translate('ticket_info'),
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnedTicket(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: count > 0
              ? const Color(0xFFFFD700).withOpacity(0.5)
              : AppColors.textDim.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: count > 0 ? const Color(0xFFFFD700) : AppColors.textDim,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            "$count",
            style: TextStyle(
              color: count > 0 ? const Color(0xFFFFD700) : AppColors.textDim,
              fontSize: 24,
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
  }) {
    return NeonCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: AppColors.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _isPurchasing
              ? SizedBox(
                  width: 80,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: const Color(0xFF00FF88),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: onPurchase,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00FF88)),
                    ),
                    child: Text(
                      price,
                      style: TextStyle(
                        color: const Color(0xFF00FF88),
                        fontSize: 14,
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
