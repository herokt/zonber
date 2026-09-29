part of 'main.dart';

// 스토어 스크린샷 모드의 진행 — 언어 4개 × 화면 10개를 차례로 띄우고 화면마다 `STORESHOT <언어>/<이름>` 로그를 찍는다.
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
        await shot('0${i++}_${worldId == 'cyber' ? 'galaxy' : worldId}');
      }
      _currentWorldId = WorldData.defaultWorld.id;
      _currentGame = null;

      // 결과 — 회원 모습으로 신기록 · 세계 순위 · 상대 돌파 · 새 뱃지 · 자랑하기
      StoreShot.member = true;
      _previousBest = StoreShot.resultPrevBest;
      _reviveCount = 1; // 부활 버튼은 빼고 다시 하기 · 자랑하기만
      _lastGameResult = {
        'survivalTime': StoreShot.resultTime,
        'mapId': _currentWorld.rankingMapId,
        'level': 15,
        'graze': 38,
        'coinsEarned': 58,
        'coinsBonus': 6,
        'rivalName': StoreShot.resultRivalName,
        'rivalTime': StoreShot.resultRivalTime,
      };
      Badges.fresh.value = [for (final k in StoreShot.freshBadges) if (Badges.byKey(k) case final b?) b];
      CoinStore.balance.value = StoreShot.shownCoins;
      _showPage('Result');
      await shot('04_result');
      StoreShot.member = false;
      CoinStore.balance.value = 0;

      // 이 기록 깨러 가기 — 랭킹에서 1위를 눌러 연 프로필 창
      _navigateTo('Ranking');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final ctx = _latestContext;
      if (ctx != null && ctx.mounted) {
        showPlayerCard(ctx, uid: StoreShot.rivalUid(), zone: _currentWorldId, challenge: (time: StoreShot.rivalTime(), onTap: () {}));
      }
      await shot('05_rival');
      if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      await shot('06_ranking');
      _navigateTo('Shop');
      await shot('07_bag');
      _navigateTo('Badges');
      await shot('08_badges');
      CoinStore.balance.value = StoreShot.shownCoins;
      _navigateTo('Promo');
      await shot('09_events');
      CoinStore.balance.value = 0;
      _navigateTo('Menu');
      await shot('10_home');
    }
    await LanguageManager().changeLanguage(original);
    debugPrint('STORESHOT done');
  }
}
