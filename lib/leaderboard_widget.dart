import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ranking_system.dart';
import 'achievement_manager.dart';
import 'user_profile.dart';

import 'design_system.dart';
import 'language_manager.dart';

part 'leaderboard_widget_popup.dart';

class LeaderboardWidget extends StatefulWidget {
  final String mapId;
  final String? highlightRecordId;
  final VoidCallback? onRestart; // Optional (not shown in Map Select)
  final VoidCallback onClose;

  /// 방금 등록한 이번 판의 기록. 상위 리스트 밖이면 하단에 순위 '-'로 보여준다.
  /// (전체 순위는 계산하지 않는다 — 쿼리 비용이 크다)
  final Map<String, dynamic>? currentRecord;

  /// 광고 부활 콜백. 값이 있으면 팝업 하단에 부활 버튼을 노출한다.
  final VoidCallback? onRevive;
  final int revivesLeft;

  const LeaderboardWidget({
    super.key,
    required this.mapId,
    this.highlightRecordId,
    this.onRestart,
    required this.onClose,
    this.currentRecord,
    this.onRevive,
    this.revivesLeft = 0,
  });

  @override
  State<LeaderboardWidget> createState() => _LeaderboardWidgetState();
}

class _LeaderboardWidgetState extends State<LeaderboardWidget> {
  bool _isNational = false; // false = Global, true = National
  RankingPeriod _period = RankingPeriod.weekly; // Default to weekly
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _myRankData;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  String? _myFlag;
  String? _myNickname;
  String? _myUserId;
  String _targetFlag = '🇰🇷'; // Default to a valid flag emoji (Korea)
  bool _isGuest = false;
  // userId → stored achievement keys (loaded after records fetch)
  Map<String, List<String>> _userAchievementKeys = {};

  @override
  void initState() {
    super.initState();
    _loadProfileAndRecords();
  }

  Future<void> _loadProfileAndRecords() async {
    try {
      final profile = await UserProfileManager.getProfile();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (mounted) {
        setState(() {
          _myFlag = profile['flag'];
          _myNickname = profile['nickname'];
          _myUserId = uid.isNotEmpty ? uid : null;

          final isAnon = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
          _isGuest = isAnon || uid.isEmpty;

          if (_myFlag != null && _myFlag!.isNotEmpty && _myFlag != '🏳️') {
            _targetFlag = _myFlag!;
          }
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
    }
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _myRankData = null;
    });

    try {
      List<Map<String, dynamic>> records;
      String currentFilterFlag = _targetFlag;

      if (_isNational) {
        records = await RankingSystem().getNationalRankings(
          widget.mapId,
          currentFilterFlag,
          period: _period,
        );
      } else {
        records = await RankingSystem().getTopRecords(
          widget.mapId,
          period: _period,
        );
      }

      Map<String, dynamic>? myRank;
      if (_myUserId != null) {
        myRank = await RankingSystem().getMyRank(
          widget.mapId,
          _myUserId!,
          period: _period,
        );
        // For national tab, only show my rank if my flag matches the filter
        if (myRank != null && _isNational) {
          final myRecordFlag = (myRank['flag'] as String?) ?? '';
          if (myRecordFlag != currentFilterFlag) myRank = null;
        }
      }

      // Batch-fetch stored achievements for all users in the list
      final allRecords = [
        ...records,
        if (myRank != null) myRank,
      ];
      final achievementKeys = await _fetchUserAchievements(allRecords);

      if (mounted) {
        setState(() {
          _records = records;
          _myRankData = myRank;
          _userAchievementKeys = achievementKeys;
          _isLoading = false;
        });
        _scrollToHighlight();
      }
    } catch (e) {
      print("Error loading records: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Batch-fetches stored achievement keys for all users in the record list.
  Future<Map<String, List<String>>> _fetchUserAchievements(
    List<Map<String, dynamic>> records,
  ) async {
    final userIds = records
        .map((r) => (r['userId'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (userIds.isEmpty) return {};

    final Map<String, List<String>> result = {};
    for (int i = 0; i < userIds.length; i += 30) {
      final batch = userIds.skip(i).take(30).toList();
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          result[doc.id] = List<String>.from(doc.data()['achievements'] ?? []);
        }
      } catch (_) {}
    }
    return result;
  }

  void _scrollToHighlight() {
    if (widget.highlightRecordId == null) return;
    int index = _records.indexWhere((r) => r['id'] == widget.highlightRecordId);
    if (index != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          double position = index * 50.0;
          double maxScroll = _scrollController.position.maxScrollExtent;
          if (position > maxScroll) position = maxScroll;

          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이번 판 기록이 상위 리스트 안에 있는지
    final bool currentInList = widget.highlightRecordId != null &&
        _records.any((r) => r['id'] == widget.highlightRecordId);

    // 하단에 따로 보여줄 행: 이번 판 기록이 리스트 밖이면 그것을, 아니면 내 최고 기록을
    Map<String, dynamic>? bottomRow;
    bool bottomIsCurrent = false;
    if (widget.currentRecord != null && !currentInList) {
      bottomRow = widget.currentRecord;
      bottomIsCurrent = true;
    } else if (_myRankData != null &&
        !_records.any((r) => r['id'] == _myRankData!['id'])) {
      bottomRow = _myRankData;
    }

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width - 20;
    final dialogHeight = screenSize.height * 0.88 > 700
        ? 700.0
        : screenSize.height * 0.88;

    return Center(
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: NeonCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isNational
                            ? LanguageManager.of(
                                context,
                              ).translate('national_ranking')
                            : LanguageManager.of(
                                context,
                              ).translate('global_ranking'),
                        style: AppTextStyles.header.copyWith(
                          fontSize: 22,
                          color: AppColors.primary,
                          shadows: [
                            const Shadow(
                              blurRadius: 10,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withOpacity(0.6), width: 1.5),
                      ),
                      child: Text(
                        RankingSystem.getPeriodLabel(_period).toUpperCase(),
                        style: AppTextStyles.body.copyWith(
                          color: Colors.orange,
                          letterSpacing: 2.0,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.orange.withOpacity(0.6), blurRadius: 8)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    // Region Filter
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterChip(
                            label: "🌍 ${LanguageManager.of(context).translate('global_tab')}",
                            isSelected: !_isNational,
                            onTap: () {
                              if (_isNational) {
                                setState(() => _isNational = false);
                                _loadRecords();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFilterChip(
                            label: "${_myFlag ?? '🏳️'} ${LanguageManager.of(context).translate('national_tab')}",
                            isSelected: _isNational,
                            isDisabled: _isGuest, // Disable for guests
                            onTap: () {
                              if (_isGuest) return; // Block tap
                              if (!_isNational) {
                                setState(() => _isNational = true);
                                _loadRecords();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Period Filter
                    Row(
                      children: [
                        _buildPeriodChip(
                          RankingPeriod.weekly,
                          LanguageManager.of(context).translate('week'),
                        ),
                        const SizedBox(width: 8),
                        _buildPeriodChip(
                          RankingPeriod.monthly,
                          LanguageManager.of(context).translate('month'),
                        ),
                        const SizedBox(width: 8),
                        _buildPeriodChip(
                          RankingPeriod.allTime,
                          LanguageManager.of(context).translate('year'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // List Header removed as requested
                      // List
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              )
                            : _records.isEmpty
                            ? Center(
                                child: Text(
                                  LanguageManager.of(
                                    context,
                                  ).translate('no_records'),
                                  style: AppTextStyles.body,
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: _records.length,
                                itemBuilder: (context, index) {
                                  var data = _records[index];
                                  // 방금 등록한 이번 판의 기록
                                  bool isCurrent =
                                      widget.highlightRecordId != null &&
                                      data['id'] == widget.highlightRecordId;
                                  bool isMe = isCurrent ||
                                      (data['nickname'] == _myNickname &&
                                          _myNickname != null);

                                  return _buildListItem(
                                    index + 1,
                                    data,
                                    isMe,
                                    isCurrentRecord: isCurrent,
                                  );
                                },
                              ),
                      ),

                      // 상위 리스트 밖일 때 — 순위는 '-'로만 표시한다
                      if (!_isLoading && bottomRow != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              LanguageManager.of(
                                context,
                              ).translate('my_rank').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildListItem(
                          bottomRow['rank'] ?? -1,
                          bottomRow,
                          true,
                          isMyRankSection: true,
                          isCurrentRecord: bottomIsCurrent,
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 광고 보고 부활 — 순위를 확인한 뒤 바로 이어할 수 있게 하단에 둔다
                      if (widget.onRevive != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: NeonButton(
                            text:
                                "${LanguageManager.of(context).translate('revive_watch_ad')} (${widget.revivesLeft})",
                            onPressed: widget.onRevive,
                            icon: Icons.videocam,
                            color: AppColors.primary,
                            isPrimary: true,
                            isCompact: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: NeonButton(
                              text: LanguageManager.of(
                                context,
                              ).translate('close'),
                              onPressed: widget.onClose,
                              isPrimary: false,
                              isCompact: true,
                              color: AppColors.textDim,
                            ),
                          ),
                          if (widget.onRestart != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: NeonButton(
                                text: LanguageManager.of(
                                  context,
                                ).translate('retry'),
                                onPressed: widget.onRestart,
                                isPrimary: true,
                                isCompact: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(
    int rank,
    Map<String, dynamic> data,
    bool isMe, {
    bool isMyRankSection = false,
    bool isCurrentRecord = false,
  }) {
    // Rank Styling (Same as before)
    Color rankColor = Colors.white;
    IconData? rankIcon;
    bool isTop3 = false;
    bool isRanker = rank > 0 && rank <= 30;

    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
      isTop3 = true;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.emoji_events;
      isTop3 = true;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.emoji_events;
      isTop3 = true;
    } else if (isRanker) {
      rankColor = AppColors.primaryDim; // Cyan Dim
    }

    final String rankText = (rank <= 0) ? "-" : "$rank";

    final double survivalTime =
        (data['survivalTime'] as num?)?.toDouble() ?? 0.0;
    final String userId = (data['userId'] as String?) ?? '';
    final storedKeys = _userAchievementKeys[userId] ?? [];
    final achieved = highestFrom(earnedFromKeys(storedKeys, survivalTime));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withOpacity(0.15)
            : (isTop3
                  ? rankColor.withOpacity(0.05)
                  : Colors.white.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(12),
        // 방금 등록한 내 기록 — 선택 테두리로 표시
        border: isCurrentRecord
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        boxShadow: isCurrentRecord
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.45),
                  blurRadius: 12,
                ),
              ]
            : (isTop3
                ? [
                    BoxShadow(
                      color: rankColor.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : []),
      ),
      child: Row(
        children: [
          // Fixed Width Rank
          SizedBox(
            width: 28,
            child: rankIcon != null
                ? Icon(rankIcon, color: rankColor, size: 20)
                : Text(
                    rankText,
                    style: TextStyle(
                      color: isMe
                          ? AppColors.primary
                          : (rank <= 30 ? Colors.white : Colors.white54),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontStyle: isMe ? FontStyle.italic : FontStyle.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 8),

          // Fixed Width Flag
          SizedBox(
            width: 22,
            child: Text(
              (data['flag'] as String? ?? '').isNotEmpty ? data['flag'] as String : '🏳️',
              style: const TextStyle(fontSize: 17),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6),

          // Nickname + 등급 엠블럼 (닉네임 바로 오른쪽에 붙는다)
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      data['nickname'] ?? 'Unknown',
                      maxLines: 1,
                      style: TextStyle(
                        color: isMe ? AppColors.primary : Colors.white,
                        fontSize: 15,
                        fontWeight: (isMe || isTop3)
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontStyle: isMe ? FontStyle.italic : FontStyle.normal,
                        shadows: isMe
                            ? [const Shadow(color: AppColors.primary, blurRadius: 8)]
                            : [],
                      ),
                    ),
                  ),
                ),
                // 엠블럼은 작게 — 탭 영역은 패딩으로 확보한다
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showUserInfoDialog(data, rank),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    child: _AchievementEmblem(achievement: achieved, size: 15),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Fixed Width Score (Monospace for Alignment)
          SizedBox(
            width: 85,
            child: Text(
              "${data['survivalTime'].toStringAsFixed(3)}s",
              style: const TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                fontFeatures: [
                  FontFeature.tabularFigures(),
                ],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserInfoDialog(Map<String, dynamic> userData, int rank) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _UserProfilePopup(
          userData: userData,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withOpacity(0.1) // Greyed out
              : (isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withOpacity(0.3)
                : (isSelected
                      ? AppColors.primary
                      : AppColors.primaryDim.withOpacity(0.5)),
            width: 1.5,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: isDisabled
                  ? Colors.grey
                  : (isSelected ? AppColors.primary : AppColors.textDim),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodChip(RankingPeriod period, String label) {
    final isSelected = _period == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_period != period) {
            setState(() => _period = period);
            _loadRecords();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.orange.withOpacity(0.25)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.orange : Colors.white24,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 6)]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.orange : Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
