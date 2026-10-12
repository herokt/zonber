part of 'main.dart';

// 광고 영상 모드의 진행 — 장면(존)마다 판을 띄워 자동 플레이로 두고, 호스트가 프레임을 넘기며 캡처한다.
// 설명·사용법은 ad_video.dart · scripts/ad_video_capture.mjs
extension _AdVideoRun on _ZonberAppState {
  Future<void> _runAdVideo() async {
    await LanguageManager().changeLanguage(AdVideo.lang);
    await Future<void>.delayed(const Duration(seconds: 2));
    for (final (name, worldId, start) in AdVideo.scenes) {
      _currentWorldId = worldId;
      _navigateTo('Game');
      final game = _currentGame!;
      while (!game.isLoaded || !game.player.isMounted) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      game.pauseEngine();
      await game.storeShotAdvance(start);
      game.storeShot = false; // 여기부터는 실제 판처럼 — 맞으면 맞고 펫도 쳐낸다(판은 끝나지 않는다)
      game.autoPilot = AutoPilot();
      AdVideo.frameInfo(0, null); // 앞으로 감는 동안 쌓인 효과음은 버린다
      game.stepEngine();
      await Future<void>.delayed(const Duration(milliseconds: 1500)); // 그림(스프라이트)·글꼴이 다 뜨도록
      debugPrint('ADVIDEO scene $name');
      await AdVideoBridge.serve((steps) async {
        for (int i = 0; i < steps; i++) {
          game.stepEngine();
        }
        await WidgetsBinding.instance.endOfFrame;
        return AdVideo.frameInfo(game.survivalTime, game.playerScreenPosition());
      });
    }
    _currentGame = null;
    debugPrint('ADVIDEO done');
  }
}
