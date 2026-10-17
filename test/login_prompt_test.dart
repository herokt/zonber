import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zonber/language_manager.dart';
import 'package:zonber/login_page.dart';
import 'package:zonber/translations.dart';

// 판 끝 로그인 창(showLoginPrompt) — 게스트가 판을 끝낼 때마다 결과 화면 위에 뜬다
void main() {
  String t(String key) => appTranslations['en']![key]!;

  Future<void> open(WidgetTester tester, {int? rank, String? gift}) async {
    await tester.pumpWidget(ChangeNotifierProvider<LanguageManager>.value(
      value: LanguageManager(),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showLoginPrompt(context, onLoginSuccess: () async {}, rank: rank, gift: gift),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('구글 로그인 버튼과 작은 닫기 — 닫기를 누르면 사라진다', (tester) async {
    await open(tester);
    expect(find.text(t('login_prompt_title')), findsOneWidget);
    expect(find.text(t('signin_google')), findsOneWidget);
    expect(find.text(t('signin_apple')), findsNothing); // 애플은 iOS 에서만
    expect(find.textContaining(t('guest_login_gift').split('{')[0]), findsNothing); // 선물 없으면 줄도 없다

    await tester.tap(find.text(t('close')));
    await tester.pumpAndSettle();
    expect(find.text(t('login_prompt_title')), findsNothing);
  });

  testWidgets('바깥을 눌러도 닫히지 않는다', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text(t('login_prompt_title')), findsOneWidget);
  });

  testWidgets('이 기록의 순위 · 로그인 선물을 싣는다', (tester) async {
    await open(tester, rank: 1234, gift: '100 coins');
    expect(find.text(t('guest_login_rank').replaceAll('{rank}', '1,234')), findsOneWidget);
    expect(find.text(t('guest_login_gift').replaceAll('{reward}', '100 coins')), findsOneWidget);
  });
}
