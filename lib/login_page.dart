import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'design_system.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';
import 'user_profile.dart';
import 'language_manager.dart';

/// 로그인 단일 출처 — 구글·애플 로그인 → 프로필 동기화 → 분석(sign_up/login).
/// 로그인 화면([LoginPage])과 판 끝 로그인 창([showLoginPrompt])이 같이 쓴다. 성공하면 true, 취소·실패는 false.
/// 프로필은 여기서 만들지 않는다 — 없으면 main 의 _checkProfile() 이 가입(닉네임·국가) 화면으로 보낸다
Future<bool> signInWith(String method) async {
  final auth = AuthService();
  final UserCredential? credential;
  if (method == 'apple') {
    final result = await auth.signInWithApple();
    credential = result == null ? null : result['credential'] as UserCredential?;
  } else {
    credential = await auth.signInWithGoogle();
  }
  if (credential == null) return false;
  await UserProfileManager.syncProfile();
  AnalyticsService().logLogin(method, isNewUser: credential.additionalUserInfo?.isNewUser ?? false);
  return true;
}

/// 애플 로그인은 AuthService 가 iOS 에서만 지원한다 — Android 에는 보여 주지 않는다
bool get appleSignInAvailable => !kIsWeb && Platform.isIOS;

/// 판 끝 로그인 창 — 게스트가 판을 끝낼 때마다 결과 화면 위에 띄운다(ResultPage).
/// 구글·애플 로그인 버튼 + 작은 [닫기]. [rank] = 이 기록이면 세계 몇 위였나, [gift] = 로그인 선물 문구(있을 때).
/// 로그인하면 창에 스피너를 띄운 채 [onLoginSuccess](가입 화면·홈으로 바꾸기)를 기다렸다가 닫는다
Future<void> showLoginPrompt(
  BuildContext context, {
  required Future<void> Function() onLoginSuccess,
  int? rank,
  String? gift,
}) async {
  AnalyticsService().logLoginPrompt('shown');
  final loggedIn = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LoginPrompt(onLoginSuccess: onLoginSuccess, rank: rank, gift: gift),
  );
  if (loggedIn != true) AnalyticsService().logLoginPrompt('close');
}

class _LoginPrompt extends StatefulWidget {
  final Future<void> Function() onLoginSuccess;
  final int? rank;
  final String? gift;

  const _LoginPrompt({required this.onLoginSuccess, this.rank, this.gift});

  @override
  State<_LoginPrompt> createState() => _LoginPromptState();
}

class _LoginPromptState extends State<_LoginPrompt> {
  bool _busy = false;

  Future<void> _signIn(String method) async {
    setState(() => _busy = true);
    if (!await signInWith(method)) {
      if (mounted) setState(() => _busy = false); // 취소·실패 — 창은 그대로(다시 고르거나 닫기)
      return;
    }
    await widget.onLoginSuccess();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final rank = widget.rank, gift = widget.gift;
    return PopScope(
      canPop: !_busy,
      child: NeonDialog(
        title: lm.translate('login_prompt_title'),
        message: lm.translate('login_prompt_body'),
        barrierDismissible: false,
        content: rank == null && gift == null
            ? null
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (rank != null)
                      OneLineText(
                        lm.translate('guest_login_rank').replaceAll('{rank}', formatCount(rank)),
                        style: AppTextStyles.text(13, weight: FontWeight.w700),
                      ),
                    if (rank != null && gift != null) const SizedBox(height: 3),
                    if (gift != null)
                      OneLineText(
                        lm.translate('guest_login_gift').replaceAll('{reward}', gift),
                        style: AppTextStyles.text(12, color: AppColors.coin, weight: FontWeight.w800),
                      ),
                  ],
                ),
              ),
        actions: [
          if (_busy)
            const SizedBox(height: 120, child: Center(child: AppSpinner(size: 32, stroke: 3))) // 버튼들과 비슷한 높이
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                NeonButton(
                  text: lm.translate('signin_google'),
                  icon: Icons.g_mobiledata_rounded,
                  onPressed: () => _signIn('google'),
                ),
                if (appleSignInAvailable) ...[
                  const SizedBox(height: 8),
                  NeonButton(
                    text: lm.translate('signin_apple'),
                    icon: Icons.apple,
                    onPressed: () => _signIn('apple'),
                  ),
                ],
                const SizedBox(height: 6),
                // 그냥 닫기 — 작게
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(lm.translate('close'), style: AppTextStyles.text(13, color: AppColors.textDim, weight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

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
  bool _isLoading = false;

  Future<void> _signIn(String method) async {
    setState(() => _isLoading = true);
    if (await signInWith(method)) {
      widget.onLoginSuccess(); // 스피너는 그대로 — 화면이 바뀔 때까지
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${method == 'apple' ? 'Apple' : 'Google'} Sign In failed or cancelled')),
    );
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
                const AppSpinner(size: 36, stroke: 3.4)
              else ...[
                _buildLoginButton(
                  LanguageManager.of(context).translate('signin_google'),
                  () => _signIn('google'),
                  Icons.g_mobiledata_rounded,
                ),
                if (appleSignInAvailable)
                  _buildLoginButton(
                    LanguageManager.of(context).translate('signin_apple'),
                    () => _signIn('apple'),
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
