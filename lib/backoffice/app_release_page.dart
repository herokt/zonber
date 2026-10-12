import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_release.dart';
import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 앱 버전 — 스토어에 나가 있는 버전을 적는다(config/app_release · lib/app_release.dart).
//   이 빌드보다 낮은 앱은 홈에서 업데이트 안내를 띄운다(lib/services/update_service.dart). 필수 빌드보다 낮으면 닫을 수 없다.
//   스토어 심사가 끝나 실제로 받을 수 있게 된 **뒤에** 그 플랫폼만 올린다 — 먼저 올리면 받을 게 없는 안내가 뜬다.
//   아래 "유저 앱 버전"은 로그인한 유저 문서의 appVersion·appBuild(2.1.0 부터 기록) — 안내를 받을 사람 수를 미리 본다.
// ─────────────────────────────────────────────────────────────
class AppReleasePage extends StatefulWidget {
  const AppReleasePage({super.key});

  @override
  State<AppReleasePage> createState() => _AppReleasePageState();
}

class _PlatformForm {
  final version = TextEditingController();
  final build = TextEditingController();
  final minBuild = TextEditingController();

  void fill(PlatformRelease? r) {
    version.text = r?.version ?? '';
    build.text = r == null ? '' : '${r.build}';
    minBuild.text = r == null || r.minBuild <= 0 ? '' : '${r.minBuild}';
  }

  /// 빈 칸이면 null(그 플랫폼은 안내하지 않음)
  PlatformRelease? get value {
    final b = int.tryParse(build.text.trim()) ?? 0;
    if (b <= 0) return null;
    return PlatformRelease(version: version.text.trim(), build: b, minBuild: int.tryParse(minBuild.text.trim()) ?? 0);
  }

  String? get problem {
    final b = int.tryParse(build.text.trim()) ?? 0;
    final m = int.tryParse(minBuild.text.trim()) ?? 0;
    if (build.text.trim().isEmpty && (version.text.trim().isNotEmpty || m > 0)) return '빌드 번호를 넣어 주세요';
    if (b > 0 && version.text.trim().isEmpty) return '버전 이름을 넣어 주세요(안내 창에 보입니다)';
    if (m > b && b > 0) return '필수 빌드가 스토어 빌드보다 클 수 없습니다';
    return null;
  }

  void dispose() {
    version.dispose();
    build.dispose();
    minBuild.dispose();
  }
}

class _AppReleasePageState extends State<AppReleasePage> with BoReloadable {
  AppRelease _saved = AppRelease.empty;
  List<BoUser> _users = const [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  AppVersion? _boVersion; // 이 백오피스 빌드(같은 저장소에서 만든 앱과 같은 버전)
  final _android = _PlatformForm();
  final _ios = _PlatformForm();

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

  bool get _dirty {
    String sig(PlatformRelease? r) => r == null ? '-' : '${r.version}/${r.build}/${r.minBuild}';
    return sig(_android.value) != sig(_saved.android) || sig(_ios.value) != sig(_saved.ios);
  }

  Future<void> _save() async {
    final problem = _android.problem ?? _ios.problem;
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    String line(String name, PlatformRelease? r) => r == null
        ? '$name: 안내 안 함'
        : '$name: v${r.version} (${r.build}) 보다 낮은 앱에 안내${r.minBuild > 0 ? ' · ${r.minBuild} 보다 낮으면 필수' : ''}'
            ' — 지금 기록상 ${_below(name == 'Android' ? 'android' : 'ios', r.build)}명';
    final ok = await confirmCode(
      context,
      '앱 버전 저장',
      '${line('Android', _android.value)}\n${line('iOS', _ios.value)}\n\n스토어에서 실제로 받을 수 있게 된 뒤에 저장하세요.',
      ok: '저장',
      okColor: Bo.blue,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await BoData.src.saveAppRelease(AppRelease(android: _android.value, ios: _ios.value));
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
        subtitle: '스토어에 나가 있는 버전 — 이 빌드보다 낮은 앱은 홈에서 업데이트 안내를 띄웁니다',
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
                      final a = _platformCard('Android', 'android', _android, _saved.android);
                      final i = _platformCard('iOS', 'ios', _ios, _saved.ios);
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
            '1) 새 버전을 스토어에 올리고 심사가 끝나 받을 수 있게 되면, 그 플랫폼의 버전 이름 · 빌드를 적고 저장합니다.\n'
            '2) 이 빌드보다 낮은 앱은 홈에서 "새 버전이 나왔어요" 창을 띄웁니다. [나중에] 를 누르면 3일 동안 다시 묻지 않습니다.\n'
            '3) 꼭 업데이트해야 할 때만 필수 빌드를 적습니다 — 그보다 낮은 앱은 창을 닫을 수 없습니다(조심).\n'
            'Android · iOS 는 심사 시간이 달라서 따로 올립니다. 빈 칸으로 저장하면 그 플랫폼은 안내하지 않습니다.',
            style: Bo.cell.copyWith(height: 1.6),
          ),
          if (_saved.updatedAt != null) ...[
            const SizedBox(height: 10),
            Text('마지막 저장 ${fmtDateTime(_saved.updatedAt)} · ${_saved.updatedBy.isEmpty ? '-' : _saved.updatedBy}', style: Bo.muted),
          ],
        ]),
      );

  Widget _platformCard(String name, String platform, _PlatformForm f, PlatformRelease? saved) {
    final v = f.value;
    final problem = f.problem;
    return BoCard(
      title: name,
      subtitle: saved == null ? '저장된 값 없음 — 안내 안 함' : '저장됨 v${saved.version} (${saved.build})${saved.minBuild > 0 ? ' · 필수 ${saved.minBuild}' : ''}',
      trailing: _boVersion == null
          ? null
          : TextButton(
              onPressed: () => setState(() {
                f.version.text = _boVersion!.name;
                f.build.text = '${_boVersion!.build}';
              }),
              child: Text('이 빌드로 채우기 · ${_boVersion!.label}'),
            ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(flex: 3, child: _field(f.version, '버전 이름', hint: '2.1.0')),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _field(f.build, '스토어 빌드', hint: '210', number: true)),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _field(f.minBuild, '필수 빌드(선택)', hint: '비우면 없음', number: true)),
        ]),
        const SizedBox(height: 10),
        if (problem != null)
          Text(problem, style: Bo.muted.copyWith(color: Bo.red))
        else if (v == null)
          Text('안내하지 않습니다', style: Bo.muted)
        else
          Text(
            '빌드 ${v.build} 보다 낮은 $name 앱에 안내 — 지금 기록상 ${_below(platform, v.build)}명'
            '${v.minBuild > 0 ? ' · 그중 ${_below(platform, v.minBuild)}명은 필수(닫을 수 없음)' : ''}',
            style: Bo.muted,
          ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint, bool number = false}) => TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : null,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
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
