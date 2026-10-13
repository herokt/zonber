import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_release.dart';
import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 앱 버전 — 스토어에 나가 있는 버전 이름을 적는다(config/app_release · lib/app_release.dart).
//   이 버전보다 낮은 앱은 홈에서 업데이트 안내를 띄운다(lib/services/update_service.dart). 필수 버전보다 낮으면 닫을 수 없다.
//   앱은 빌드 번호로 견주므로 저장할 때 빌드를 같이 적는다 — 이 백오피스와 같은 버전이면 그 빌드, 아니면 그 버전을 쓰는 회원 기록의 빌드
//   (PlatformRelease.buildFor). 화면에는 빌드 칸이 없다.
//   스토어 심사가 끝나 실제로 받을 수 있게 된 **뒤에** 그 플랫폼만 올린다 — 먼저 올리면 받을 게 없는 안내가 뜬다.
//   아래 "유저 앱 버전"은 로그인한 유저 문서의 appVersion·appBuild(2.1.0 부터 기록) — 안내를 받을 사람 수를 미리 본다.
// ─────────────────────────────────────────────────────────────
class AppReleasePage extends StatefulWidget {
  const AppReleasePage({super.key});

  @override
  State<AppReleasePage> createState() => _AppReleasePageState();
}

class _PlatformForm {
  final String platform; // 'android' · 'ios'
  _PlatformForm(this.platform);
  final version = TextEditingController();
  final minVersion = TextEditingController();

  void fill(PlatformRelease? r) {
    version.text = r?.version ?? '';
    minVersion.text = r == null || r.minBuild <= 0 ? '' : r.minVersion;
  }

  void dispose() {
    version.dispose();
    minVersion.dispose();
  }
}

class _AppReleasePageState extends State<AppReleasePage> with BoReloadable {
  AppRelease _saved = AppRelease.empty;
  List<BoUser> _users = const [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  AppVersion? _boVersion; // 이 백오피스 빌드(같은 저장소에서 만든 앱과 같은 버전)
  final _android = _PlatformForm('android');
  final _ios = _PlatformForm('ios');

  @override
  void dispose() {
    _android.dispose();
    _ios.dispose();
    super.dispose();
  }

  @override
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await BoData.src.appRelease();
      final users = await BoData.users();
      final v = await AppVersion.load();
      if (!mounted) return;
      setState(() {
        _saved = r;
        _users = users;
        _boVersion = v.build > 0 ? v : null;
        _android.fill(r.android);
        _ios.fill(r.ios);
      });
      BoData.markLoaded();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// [name] 버전으로 알려진 [platform] 빌드들 — 이 백오피스 · 저장된 값 · 회원 기록
  Iterable<int> _knownBuilds(String platform, String name) sync* {
    if (_boVersion?.name == name) yield _boVersion!.build;
    final saved = _saved.of(platform);
    if (saved != null && saved.version == name) yield saved.build;
    if (saved != null && saved.minVersion == name && saved.minBuild > 0) yield saved.minBuild;
    for (final u in _users) {
      final b = (u.data['appBuild'] as num?)?.toInt();
      if (b != null && u.data['platform'] == platform && u.data['appVersion'] == name) yield b;
    }
  }

  int? _buildOf(String platform, String name, {required bool lowest}) =>
      name.isEmpty ? null : PlatformRelease.buildFor(_knownBuilds(platform, name), lowest: lowest);

  /// 빈 칸이면 null(그 플랫폼은 안내하지 않음). 문제가 있으면 [_problem] 이 알려 준다
  PlatformRelease? _value(_PlatformForm f) {
    final v = f.version.text.trim();
    final b = _buildOf(f.platform, v, lowest: false);
    if (b == null) return null;
    final mv = f.minVersion.text.trim();
    final mb = mv.isEmpty ? 0 : (_buildOf(f.platform, mv, lowest: true) ?? 0);
    return PlatformRelease(version: v, build: b, minBuild: mb, minVersion: mb > 0 ? mv : '');
  }

  String? _problem(_PlatformForm f) {
    final v = f.version.text.trim();
    final mv = f.minVersion.text.trim();
    final ok = RegExp(r'^\d+\.\d+\.\d+$');
    if (v.isEmpty) return mv.isEmpty ? null : '스토어 버전을 넣어 주세요';
    if (!ok.hasMatch(v)) return '버전은 2.1.0 처럼 적어 주세요';
    if (mv.isNotEmpty && !ok.hasMatch(mv)) return '필수 버전은 2.1.0 처럼 적어 주세요';
    final b = _buildOf(f.platform, v, lowest: false);
    if (b == null) return _unknown(v);
    if (mv.isNotEmpty) {
      final mb = _buildOf(f.platform, mv, lowest: true);
      if (mb == null) return _unknown(mv);
      if (mb > b) return '필수 버전이 스토어 버전보다 높을 수 없습니다';
    }
    return null;
  }

  String _unknown(String v) => 'v$v 를 쓰는 앱 기록이 없어 아직 저장할 수 없습니다'
      '${_boVersion == null ? '' : ' — 이 백오피스는 v${_boVersion!.name} 입니다(새 버전이면 백오피스를 다시 배포)'}';

  bool get _dirty {
    String sig(PlatformRelease? r) => r == null ? '-' : '${r.version}/${r.build}/${r.minBuild}';
    return sig(_value(_android)) != sig(_saved.android) || sig(_value(_ios)) != sig(_saved.ios);
  }

  Future<void> _save() async {
    final problem = _problem(_android) ?? _problem(_ios);
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    final android = _value(_android), ios = _value(_ios);
    String line(String name, String platform, PlatformRelease? r) => r == null
        ? '$name: 안내 안 함'
        : '$name: v${r.version} 보다 낮은 앱에 안내${r.minBuild > 0 ? ' · v${r.minVersion} 보다 낮으면 필수' : ''}'
            ' — 지금 기록상 ${_below(platform, r.build)}명';
    final ok = await confirmCode(
      context,
      '앱 버전 저장',
      '${line('Android', 'android', android)}\n${line('iOS', 'ios', ios)}\n\n스토어에서 실제로 받을 수 있게 된 뒤에 저장하세요.',
      ok: '저장',
      okColor: Bo.blue,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await BoData.src.saveAppRelease(AppRelease(android: android, ios: ios));
      if (mounted) toast(context, '저장했습니다 — 앱은 켜거나 돌아올 때 읽습니다(최대 3시간 캐시)');
      await reload();
    } catch (e) {
      if (mounted) toast(context, '저장 실패: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 이 플랫폼에서 [build] 보다 낮은 빌드로 기록된 회원 수(기록 없는 옛 버전은 빼고 센다)
  int _below(String platform, int build) => _users.where((u) {
        final b = (u.data['appBuild'] as num?)?.toInt();
        return u.data['platform'] == platform && b != null && b < build;
      }).length;

  @override
  Widget build(BuildContext context) {
    return BoPage(
      topBar: BoTopBar(
        title: '앱 버전',
        breadcrumb: const ['운영'],
        subtitle: '스토어에 나가 있는 버전 — 이 버전보다 낮은 앱은 홈에서 업데이트 안내를 띄웁니다',
        actions: [
          FilledButton.icon(
            onPressed: _loading || _saving || !_dirty ? null : _save,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? '저장 중…' : '저장'),
          ),
        ],
      ),
      child: _error != null
          ? Center(child: Text('불러오지 못했습니다: $_error', style: Bo.muted))
          : _loading
              ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _guide(),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, c) {
                      final wide = c.maxWidth > 900;
                      final a = _platformCard('Android', _android, _saved.android);
                      final i = _platformCard('iOS', _ios, _saved.ios);
                      return wide
                          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: i)])
                          : Column(children: [a, const SizedBox(height: 16), i]);
                    }),
                    const SizedBox(height: 16),
                    _distribution(),
                  ],
                ),
    );
  }

  Widget _guide() => BoCard(
        title: '쓰는 법',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '1) 새 버전을 스토어에 올리고 심사가 끝나 받을 수 있게 되면, 그 플랫폼의 스토어 버전(예 2.1.1)을 적고 저장합니다.\n'
            '2) 이 버전보다 낮은 앱은 홈에서 "새 버전이 나왔어요" 창을 띄웁니다. [나중에] 를 누르면 3일 동안 다시 묻지 않습니다.\n'
            '3) 꼭 업데이트해야 할 때만 필수 버전을 적습니다 — 그보다 낮은 앱은 창을 닫을 수 없습니다(조심).\n'
            'Android · iOS 는 심사 시간이 달라서 따로 올립니다. 빈 칸으로 저장하면 그 플랫폼은 안내하지 않습니다.',
            style: Bo.cell.copyWith(height: 1.6),
          ),
          if (_saved.updatedAt != null) ...[
            const SizedBox(height: 10),
            Text('마지막 저장 ${fmtDateTime(_saved.updatedAt)} · ${_saved.updatedBy.isEmpty ? '-' : _saved.updatedBy}', style: Bo.muted),
          ],
        ]),
      );

  Widget _platformCard(String name, _PlatformForm f, PlatformRelease? saved) {
    final v = _value(f);
    final problem = _problem(f);
    return BoCard(
      title: name,
      subtitle: saved == null
          ? '저장된 값 없음 — 안내 안 함'
          : '저장됨 v${saved.version}${saved.minBuild > 0 ? ' · 필수 ${saved.minVersion.isEmpty ? '(빌드 ${saved.minBuild})' : 'v${saved.minVersion}'}' : ''}',
      trailing: _boVersion == null
          ? null
          : TextButton(
              onPressed: () => setState(() => f.version.text = _boVersion!.name),
              child: Text('이 버전으로 채우기 · v${_boVersion!.name}'),
            ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _field(f.version, '스토어 버전', hint: '2.1.1')),
          const SizedBox(width: 10),
          Expanded(child: _field(f.minVersion, '필수 버전(선택)', hint: '비우면 없음')),
        ]),
        const SizedBox(height: 10),
        if (problem != null)
          Text(problem, style: Bo.muted.copyWith(color: Bo.red))
        else if (v == null)
          Text('안내하지 않습니다', style: Bo.muted)
        else
          Text(
            'v${v.version} 보다 낮은 $name 앱에 안내 — 지금 기록상 ${_below(f.platform, v.build)}명'
            '${v.minBuild > 0 ? ' · 그중 ${_below(f.platform, v.minBuild)}명은 필수(닫을 수 없음)' : ''}',
            style: Bo.muted,
          ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: (_) => setState(() {}),
      );

  /// 유저 앱 버전 분포 — 플랫폼 × 버전(빌드). 기록 없는 문서는 "2.1.0 전"
  Widget _distribution() {
    final counts = <String, int>{};
    final order = <String, int>{};
    for (final u in _users) {
      final p = (u.data['platform'] as String?) ?? '?';
      final b = (u.data['appBuild'] as num?)?.toInt();
      final key = b == null ? '$p · 2.1.0 전(기록 없음)' : '$p · v${u.data['appVersion'] ?? '?'} ($b)';
      counts[key] = (counts[key] ?? 0) + 1;
      order[key] = b ?? -1;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final pa = a.split(' · ').first, pb = b.split(' · ').first;
        if (pa != pb) return pa.compareTo(pb);
        return order[b]!.compareTo(order[a]!);
      });
    return BoCard(
      title: '유저 앱 버전',
      subtitle: '로그인한 회원 문서 기준(앱을 켜고 동기화할 때 적힘) · 총 ${fmtNum(_users.length)}명',
      child: keys.isEmpty
          ? Text('기록이 없습니다', style: Bo.muted)
          : Column(children: [
              for (final k in keys) BoKv(k, v: '${fmtNum(counts[k]!)}명', keyWidth: 260),
            ]),
    );
  }
}
