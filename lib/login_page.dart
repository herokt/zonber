import 'package:flutter/material.dart';
import 'design_system.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);
    if (user != null) {
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
    final user = await _authService.signInWithApple();
    setState(() => _isLoading = false);
    if (user != null) {
      widget.onLoginSuccess();
    } else {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Apple Sign In failed or cancelled')),
         );
      }
    }
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
                "SIGN IN TO CONTINUE",
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
              ]
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
}
