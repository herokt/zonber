import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'design_system.dart';
import 'services/auth_service.dart';
import 'user_profile.dart';

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
      // Try to sync existing profile from Firestore
      await UserProfileManager.syncProfile();

      // Check if profile exists
      bool hasProfile = await UserProfileManager.hasProfile();

      if (!hasProfile) {
        // Auto-create profile from Google account
        final user = credential.user;
        String nickname = user?.displayName?.split(' ').first ?? 'Player';

        // Limit nickname to 8 characters
        if (nickname.length > 8) {
          nickname = nickname.substring(0, 8);
        }

        await UserProfileManager.saveProfile(
          nickname,
          '', // Empty flag, user can set later
          '', // Empty country name
        );

        print('✅ Auto-created profile from Google: $nickname');
      }

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
      final fullName = result['fullName'] as String?;

      if (credential != null) {
        // Try to sync existing profile from Firestore
        await UserProfileManager.syncProfile();

        // Check if profile exists
        bool hasProfile = await UserProfileManager.hasProfile();

        if (!hasProfile) {
          // Auto-create profile from Apple account
          String nickname =
              fullName ?? credential.user?.displayName ?? 'Player';

          // Limit nickname to 8 characters
          if (nickname.length > 8) {
            nickname = nickname.substring(0, 8);
          }

          await UserProfileManager.saveProfile(
            nickname,
            '', // Empty flag, user can set later
            '', // Empty country name
          );

          print('✅ Auto-created profile from Apple: $nickname');
        }

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

  Future<void> _handleGuestContinue() async {
    await UserProfileManager.enableGuestMode();
    widget.onGuestContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "WELCOME",
                style: AppTextStyles.header.copyWith(fontSize: 48),
              ),
              const SizedBox(height: 16),
              Text(
                "SIGN IN TO COMPETE",
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textDim,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 60),
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else ...[
                _buildLoginButton(
                  "SIGN IN WITH GOOGLE",
                  _handleGoogleSignIn,
                  Icons.android, // Using Android icon as placeholder for Google
                ),
                _buildLoginButton(
                  "SIGN IN WITH APPLE",
                  _handleAppleSignIn,
                  Icons.apple,
                ),
                const SizedBox(height: 32),
                // Guest Mode Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: AppColors.textDim.withOpacity(0.3)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "OR",
                        style: TextStyle(
                          color: AppColors.textDim,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: AppColors.textDim.withOpacity(0.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildGuestButton(),
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
        text: "CONTINUE AS GUEST",
        onPressed: _handleGuestContinue,
        icon: Icons.person_outline,
        color: AppColors.textDim,
        isPrimary: false,
        isCompact: false,
      ),
    );
  }
}
