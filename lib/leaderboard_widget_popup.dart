
part of 'leaderboard_widget.dart';

// ---------------------------------------------------------------------------
// Emblem widget
// ---------------------------------------------------------------------------

class _AchievementEmblem extends StatelessWidget {
  final AchievementDef achievement;
  final double size;

  const _AchievementEmblem({required this.achievement, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final color = achievement.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.8), width: size * 0.07),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Icon(achievement.icon, color: color, size: size * 0.58),
    );
  }
}

// ---------------------------------------------------------------------------
// Popup widget
// ---------------------------------------------------------------------------

class _UserProfilePopup extends StatefulWidget {
  final Map<String, dynamic> userData;

  const _UserProfilePopup({
    required this.userData,
  });

  @override
  State<_UserProfilePopup> createState() => _UserProfilePopupState();
}

class _UserProfilePopupState extends State<_UserProfilePopup> {
  List<AchievementDef> _earned = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final double survivalTime =
        (widget.userData['survivalTime'] as num?)?.toDouble() ?? 0.0;
    final String? userId = widget.userData['userId'] as String?;

    List<String> storedKeys = [];

    if (userId != null && userId.isNotEmpty) {
      // Load permanent achievements from Firestore
      storedKeys = await AchievementManager.getForUser(userId);
    }

    final earned = earnedFromKeys(storedKeys, survivalTime);

    if (mounted) {
      setState(() {
        _earned = earned;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double survivalTime =
        (widget.userData['survivalTime'] as num?)?.toDouble() ?? 0.0;
    final lang = LanguageManager.of(context);

    if (_loading) {
      return NeonCard(
        padding: const EdgeInsets.all(40),
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final highest = highestFrom(_earned);

    return NeonCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile header — flag · nickname · record on one line
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                (widget.userData['flag'] as String? ?? '').isNotEmpty
                    ? widget.userData['flag'] as String
                    : '🏳️',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.userData['nickname'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${survivalTime.toStringAsFixed(3)}s",
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Highest emblem (large)
          _AchievementEmblem(achievement: highest, size: 72),
          const SizedBox(height: 10),
          Text(
            lang.translate(highest.key).toUpperCase(),
            style: TextStyle(
              color: highest.color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
              shadows: [Shadow(color: highest.color, blurRadius: 12)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.translate(highest.descKey),
            style: const TextStyle(color: AppColors.textDim, fontSize: 11),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.textDim, height: 1),
          const SizedBox(height: 12),

          Text(
            lang.translate('achievements').toUpperCase(),
            style: const TextStyle(
              color: AppColors.textDim,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _earned.map((ach) {
              final isTop = ach.key == highest.key;
              // 순위 업적은 한 번 달성하면 영구 보존되므로 "현재 순위"가 아니라
              // "역대 최고"임을 명시한다. 생존 업적은 실력 증명이라 그대로 둔다.
              final isRank = ach.category != AchievementCategory.survival;
              return Tooltip(
                message: isRank
                    ? '${lang.translate('peak_record')} · ${lang.translate(ach.descKey)}'
                    : lang.translate(ach.descKey),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: ach.color.withValues(alpha: isTop ? 0.15 : 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ach.color.withValues(alpha: isTop ? 0.9 : 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ach.icon, color: ach.color, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        lang.translate(ach.key),
                        style: TextStyle(
                          color: ach.color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isRank) ...[
                        const SizedBox(width: 4),
                        Text(
                          lang.translate('peak_record'),
                          style: TextStyle(
                            color: ach.color.withValues(alpha: 0.6),
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              text: lang.translate('close'),
              onPressed: () => Navigator.pop(context),
              isPrimary: false,
            ),
          ),
        ],
      ),
    );
  }
}
