import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'admin_gate.dart';
import 'backoffice_home.dart';
import 'bo_common.dart';
import 'bo_firestore.dart';
import 'bo_mock.dart';
import '../firebase_options.dart';

// ─────────────────────────────────────────────────────────────
// 백오피스 진입점.
//  - 기본: Firebase 초기화 → 관리자 Google 로그인(AdminGate) → 화면. 데이터는 Firestore.
//  - 미리보기(--dart-define=BO_PREVIEW=true): Firebase·로그인 없이 가짜 데이터(bo_mock.dart).
//    주소 ?page=dashboard|users|ranking|runs|economy, ?page=user&uid=mock_102&tab=1, &theme=dark|light 로 바로 열 수 있다.
// ─────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BoTheme.load(); // 저장된 밝은/어두운 선택(없으면 시스템)

  if (kBoPreview) {
    BoData.src = MockSource();
    _applyPreviewRoute();
    runApp(const BackofficeApp());
    return;
  }

  String? errorMessage;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Backoffice: Firebase Initialized");
  } catch (e) {
    debugPrint("Backoffice: Initialization/Auth Error: $e");
    errorMessage = e.toString();
  }

  BoData.src = FirestoreSource();
  runApp(BackofficeApp(initError: errorMessage));
}

/// 미리보기 전용 — 주소의 ?page= / &uid= 로 첫 화면을 고른다
void _applyPreviewRoute() {
  final q = Uri.base.queryParameters;
  final page = q['page'] ?? '';
  final section = switch (page) {
    'users' || 'user' => BoSection.users,
    'ranking' => BoSection.ranking,
    'runs' => BoSection.runs,
    'economy' => BoSection.economy,
    _ => BoSection.dashboard,
  };
  BoNav.go(section);
  final theme = q['theme'];
  if (theme == 'dark') BoTheme.mode.value = ThemeMode.dark;
  if (theme == 'light') BoTheme.mode.value = ThemeMode.light;
  if (page == 'user') {
    BoNav.initialUserTab = (int.tryParse(q['tab'] ?? '') ?? 0).clamp(0, 3);
    BoNav.openUser(q['uid'] ?? 'mock_102');
  }
}

class BackofficeApp extends StatefulWidget {
  final String? initError;
  const BackofficeApp({super.key, this.initError});

  @override
  State<BackofficeApp> createState() => _BackofficeAppState();
}

/// 테마 모드(BoTheme.mode)·시스템 밝기를 듣고 팔레트(Bo.p)를 바꾼 뒤 화면 전체를 다시 그린다(상태는 유지)
class _BackofficeAppState extends State<BackofficeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BoTheme.mode.addListener(_apply);
    _resolve();
  }

  @override
  void dispose() {
    BoTheme.mode.removeListener(_apply);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply();

  void _resolve() {
    final dark = BoTheme.resolveDark(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    Bo.p = dark ? BoPalette.dark : BoPalette.light;
  }

  void _apply() {
    if (!mounted) return;
    _resolve();
    setState(() {});
    // Bo.* 를 직접 읽는 위젯도 새 색으로 다시 빌드한다
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZONBER Admin',
      debugShowCheckedModeBanner: false,
      theme: boTheme(),
      themeAnimationDuration: Duration.zero,
      home: kBoPreview
          ? const BackofficeHome()
          : widget.initError != null
              ? ErrorScreen(error: widget.initError!)
              : const AdminGate(child: BackofficeHome()), // 관리자 Google 계정만
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          margin: const EdgeInsets.all(32),
          child: BoCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: Bo.red, size: 48),
                const SizedBox(height: 16),
                Text("Firebase 초기화 실패", style: Bo.h1),
                const SizedBox(height: 12),
                Text("웹에서 실행하려면 Firebase 옵션을 설정해야 합니다.", textAlign: TextAlign.center, style: Bo.body.copyWith(color: Bo.text2)),
                const SizedBox(height: 12),
                SelectableText(error, style: TextStyle(color: Bo.red, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Text("실행: flutterfire configure", style: Bo.mono),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
