import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 백오피스 관리자 확인 — Google 로그인 + 이메일 허용 목록.
// firestore.rules 의 isAdmin() 과 같은 목록을 쓴다(바꾸면 둘 다 고칠 것).
// 익명·다른 계정은 관리 화면을 볼 수 없고, 규칙상 다른 사람 문서도 못 고친다.
// ─────────────────────────────────────────────────────────────
const Set<String> kAdminEmails = {'herokt851103@gmail.com'};

bool isAdminUser(User? u) =>
    u != null && !u.isAnonymous && u.emailVerified && kAdminEmails.contains((u.email ?? '').toLowerCase());

class AdminGate extends StatelessWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  Future<void> _signIn(BuildContext context) async {
    try {
      final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        // 저장된 로그인 세션을 되살리는 중 — 로그인 창을 잠깐 띄웠다 바꾸지 않고 기다린다
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: Bo.bg, body: const BoLoading());
        }
        final user = snap.data;
        if (isAdminUser(user)) return child;
        final signedInOther = user != null && !user.isAnonymous;
        return Scaffold(
          backgroundColor: Bo.bg,
          body: Center(
            child: Container(
              width: 400,
              margin: const EdgeInsets.all(24),
              child: BoCard(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF6366F1), Bo.accent]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Z', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
                    ),
                    const SizedBox(height: 16),
                    Text('ZONBER Admin', style: Bo.h1),
                    const SizedBox(height: 8),
                    Text(
                      signedInOther ? '${user.email ?? ''} 은(는) 관리자 계정이 아닙니다.' : '관리자 Google 계정으로 로그인하세요.',
                      textAlign: TextAlign.center,
                      style: Bo.body.copyWith(color: signedInOther ? Bo.red : Bo.text2),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: signedInOther
                          ? OutlinedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('로그아웃'))
                          : FilledButton.icon(
                              onPressed: () => _signIn(context),
                              icon: const Icon(Icons.login_rounded, size: 18),
                              label: const Text('Google 로그인'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
