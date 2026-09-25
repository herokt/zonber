import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bo_common.dart';

/// 보상 편집 — 코인(빠른 선택 버튼) + 아이템(게임 목록에서 고른다 → 오타 없음).
/// 이벤트 창·코드 창이 같이 쓴다. [items] 는 부모가 가진 목록을 그대로 고친다
class BoRewardEditor extends StatelessWidget {
  final TextEditingController coins;
  final List<String> items;
  final VoidCallback onChanged;
  const BoRewardEditor({super.key, required this.coins, required this.items, required this.onChanged});

  static const List<int> presets = [50, 100, 300, 500, 1000];

  @override
  Widget build(BuildContext context) {
    final current = int.tryParse(coins.text.trim()) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          SizedBox(
            width: 150,
            child: TextField(
              controller: coins,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '코인', suffixText: '개'),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final n in presets)
                ChoiceChip(
                  label: Text(fmtNum(n)),
                  selected: current == n,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    coins.text = '$n';
                    onChanged();
                  },
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey(items.length), // 고르면 바로 추가하고 빈 칸으로 돌아온다
          isExpanded: true,
          decoration: const InputDecoration(labelText: '아이템 추가 (선택)'),
          items: [
            for (final id in allGrantableItems())
              if (!items.contains(id))
                DropdownMenuItem(value: id, child: Text('${itemGroupLabel(itemGroup(id))} · ${itemName(id)}')),
          ],
          onChanged: (v) {
            if (v == null) return;
            items.add(v);
            onChanged();
          },
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in items)
              InputChip(
                label: Text(itemName(id)),
                onDeleted: () {
                  items.remove(id);
                  onChanged();
                },
              ),
          ]),
        ],
      ],
    );
  }
}

/// 창 안의 번호 붙은 구역 제목 — ① 종류 ② 보상 …
class BoStep extends StatelessWidget {
  final int n;
  final String title;
  final String? hint;
  const BoStep(this.n, this.title, {super.key, this.hint});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Bo.accent, shape: BoxShape.circle),
            child: Text('$n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Bo.onAccent)),
          ),
          const SizedBox(width: 8),
          Text(title, style: Bo.h2),
          if (hint != null) ...[const SizedBox(width: 8), Flexible(child: Text(hint!, style: Bo.caption))],
        ]),
      );
}
