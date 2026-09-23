import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'design_system.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';
import 'user_profile.dart';
import 'language_manager.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback? onGuestContinue;

  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    this.onGuestContinue,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final credential = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (credential != null) {
      // Sync existing profile from Firestore (returning user).
      // Do NOT auto-create a profile here — let _checkProfile() route to
      // InitialSetupPage if no profile exists, so the user can pick a country.
      await UserProfileManager.syncProfile();
      AnalyticsService().logLogin('google');

      widget.onLoginSuccess();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign In failed or cancelled')),
        );
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    final result = await _authService.signInWithApple();
    setState(() => _isLoading = false);

    if (result != null) {
      final credential = result['credential'] as UserCredential?;

      if (credential != null) {
        // Sync existing profile from Firestore (returning user).
        // Do NOT auto-create a profile here — let _checkProfile() route to
        // InitialSetupPage if no profile exists, so the user can pick a country.
        await UserProfileManager.syncProfile();
        AnalyticsService().logLogin('apple');

        widget.onLoginSuccess();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple Sign In failed or cancelled')),
        );
      }
    }
  }

  /// 게스트로 계속 — 로그인 없이 게임 맛보기만(아무것도 저장하지 않는다)
  void _handleGuestContinue() {
    AnalyticsService().logLoginSkipped();
    widget.onGuestContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      title: '',
      showBackButton: true,
      onBack: widget.onGuestContinue,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 40),
              const SizedBox(height: 16),
              Text(
                LanguageManager.of(context).translate('login_title'),
                textAlign: TextAlign.center,
                style: AppTextStyles.display(24).copyWith(height: 1.3),
              ),
              const SizedBox(height: 10),
              Text(
                LanguageManager.of(context).translate('login_subtitle'),
                textAlign: TextAlign.center,
                style: AppTextStyles.text(14, color: AppColors.textDim, height: 1.5),
              ),
              const SizedBox(height: 60),
              if (_isLoading)
                CircularProgressIndicator(color: AppColors.primary)
              else ...[
                _buildLoginButton(
                  LanguageManager.of(context).translate('signin_google'),
                  _handleGoogleSignIn,
                  Icons.g_mobiledata_rounded,
                ),
                // Apple 로그인은 AuthService가 iOS에서만 지원한다 — Android에는 노출하지 않는다.
                if (!kIsWeb && Platform.isIOS)
                  _buildLoginButton(
                    LanguageManager.of(context).translate('signin_apple'),
                    _handleAppleSignIn,
                    Icons.apple,
                  ),
                ...[
                  const SizedBox(height: 32),
                  // 게스트로 계속하기 — 모든 플랫폼. 게스트는 랭킹 등록만 불가하다.
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: AppColors.textDim.withValues(alpha: 0.3)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          LanguageManager.of(context).translate('or'),
                          style: TextStyle(
                            color: AppColors.textDim,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: AppColors.textDim.withValues(alpha: 0.3)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildGuestButton(),
                  const SizedBox(height: 12),
                  Text(
                    LanguageManager.of(context).translate('guest_no_ranking_note'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(String text, VoidCallback onPressed, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 300),
      child: NeonButton(
        text: text,
        onPressed: onPressed,
        icon: icon,
        isCompact: false,
      ),
    );
  }

  Widget _buildGuestButton() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 300),
      child: NeonButton(
        text: LanguageManager.of(context).translate('continue_guest'),
        onPressed: _handleGuestContinue,
        icon: Icons.person_outline,
        isPrimary: false,
        isCompact: true,
      ),
    );
  }
}
