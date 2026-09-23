import 'package:flutter/material.dart';

import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 플레이 기록 표 — 플레이 기록 화면(scroll)과 유저 상세 플레이 기록 탭이 같이 쓴다
// ─────────────────────────────────────────────────────────────
class RunsTable extends StatelessWidget {
  final List<RunRow> runs;
  final bool showUser;
  final bool scroll;
  final Widget? footer;
  final Widget? empty;
  const RunsTable({super.key, required this.runs, this.showUser = true, this.scroll = false, this.footer, this.empty});

  @override
  Widget build(BuildContext context) {
    final cols = [
      const BoCol('일시', width: 128),
      if (showUser) const BoCol('유저', flex: 3, minWidth: 150),
      const BoCol('스테이지', width: 128),
      const BoCol('생존', width: 92, numeric: true),
      const BoCol('레벨', width: 56, numeric: true),
      const BoCol('추가 기록', width: 108),
      const BoCol('코인', width: 88, numeric: true, tooltip: '획득 코인 (+보너스)'),
      const BoCol('부활', width: 56, numeric: true),
      const BoCol('캐릭터', width: 88),
      BoCol('장비 / 스킨', flex: 3, minWidth: showUser ? 140 : 200),
      const BoCol('신기록', width: 52),
    ];
    return BoTable(
      columns: cols,
      scroll: scroll,
      rowCount: runs.length,
      footer: footer,
      empty: empty,
      onRowTap: showUser ? (i) => BoNav.openUser(runs[i].uid) : null,
      cells: (i) {
        final r = runs[i];
        return [
          BoTable.text(fmtDateTime(r.at), style: Bo.muted, tooltip: '${fmtDateTimeSec(r.at)} · ${timeAgo(r.at)}'),
          if (showUser) BoUserCell(uid: r.uid, data: BoData.cached(r.uid), charId: r.character),
          BoStageCell(r.mapId),
          BoTable.text(r.time.toStringAsFixed(3), style: Bo.cellStrong),
          BoTable.text('${r.level}'),
          BoTable.text(r.statText, style: Bo.muted),
          BoTable.text(r.coinText, color: Bo.coin),
          BoTable.text(r.revive == 0 ? '-' : '${r.revive}', color: r.revive == 0 ? Bo.text3 : null),
          Row(children: [
            CharDot(r.character),
            const SizedBox(width: 6),
            Flexible(child: Text(charName(r.character), style: Bo.cell, overflow: TextOverflow.ellipsis)),
          ]),
          BoTable.text(r.gearText, style: Bo.muted, tooltip: [...r.gear, if (r.skin.isNotEmpty) r.skin].join(', ')),
          r.best ? Icon(Icons.star_rounded, color: Bo.amber, size: 17) : const SizedBox(),
        ];
      },
    );
  }
}
