part of 'main.dart';

// 스토어 스크린샷 모드의 진행 — 언어 4개 × 화면 6개를 차례로 띄우고 화면마다 `STORESHOT <언어>/<이름>` 로그를 찍는다.
// 설명·사용법은 store_shot.dart · scripts/store_shots.sh
extension _StoreShotRun on _ZonberAppState {
  /// 로그인·광고·분석 없이 시작한다. 기기에 저장된 데이터는 읽기만 하고 바꾸지 않는다(언어만 끝나고 되돌린다)
  Future<void> _startStoreShots() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Firebase.initializeApp(); // FirebaseAuth 를 부르는 화면이 있어서 켜 둔다(랭킹은 가짜 기록)
      } catch (e) {
        debugPrint('StoreShot: Firebase init failed: $e');
      }
    }
    await AudioManager().initialize();
    await LanguageManager().init();
    await _loadProgress();
    CoinStore.storeShotReset();
    _bestTimes = {};
    _rankCache = {};
    if (!mounted) return;
    _showPage('Menu');
    await _runStoreShots();
  }

  Future<void> _runStoreShots() async {
    final original = LanguageManager().currentLanguage;
    Future<void> shot(String name) async {
      await Future<void>.delayed(const Duration(milliseconds: 1800)); // 화면·그림이 자리 잡을 때까지
      debugPrint('STORESHOT ${LanguageManager().currentLanguage}/$name');
      await Future<void>.delayed(const Duration(seconds: 3)); // 호스트가 캡처하는 동안
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    for (final lang in StoreShot.langs) {
      await LanguageManager().changeLanguage(lang);
      int i = 1;
      for (final (worldId, t) in StoreShot.games) {
        _currentWorldId = worldId;
        _navigateTo('Game');
        final game = _currentGame!;
        while (!game.isLoaded || !game.player.isMounted) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        game.pauseEngine();
        await game.storeShotAdvance(t);
        // 한두 프레임만 돌려 멈춘 모습을 화면에 그린다
        game.resumeEngine();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        game.pauseEngine();
        await shot('${i++}_${worldId == 'cyber' ? 'galaxy' : worldId}');
      }
      _currentWorldId = WorldData.defaultWorld.id;
      _navigateTo('Ranking');
      await shot('4_ranking');
      _navigateTo('Shop');
      await shot('5_bag');
      _navigateTo('Menu');
      await shot('6_home');
    }
    await LanguageManager().changeLanguage(original);
    debugPrint('STORESHOT done');
  }
}
