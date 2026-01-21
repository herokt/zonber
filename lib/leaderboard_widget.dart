import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'ranking_system.dart';
import 'user_profile.dart';

import 'design_system.dart';
import 'language_manager.dart';

part 'leaderboard_widget_popup.dart';

class LeaderboardWidget extends StatefulWidget {
  final String mapId;
  final String? highlightRecordId;
  final VoidCallback? onRestart; // Optional (not shown in Map Select)
  final VoidCallback onClose;

  const LeaderboardWidget({
    super.key,
    required this.mapId,
    this.highlightRecordId,
    this.onRestart,
    required this.onClose,
  });

  @override
  State<LeaderboardWidget> createState() => _LeaderboardWidgetState();
}

class _LeaderboardWidgetState extends State<LeaderboardWidget> {
  bool _isNational = false; // false = Global, true = National
  RankingPeriod _period = RankingPeriod.daily; // Default to daily
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _myRankData;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  String? _myFlag;
  String? _myNickname;
  String _targetFlag = '🇰🇷'; // Default to a valid flag emoji (Korea)
  bool _isGuest = false; // Add guest flag

  @override
  void initState() {
    super.initState();
    _loadProfileAndRecords();
  }

  Future<void> _loadProfileAndRecords() async {
    try {
      final profile = await UserProfileManager.getProfile();
      if (mounted) {
        setState(() {
          _myFlag = profile['flag'];
          _myNickname = profile['nickname'];

          // Simple guest check based on nickname or auth (assuming nickname 'Guest' means guest or use other flag)
          // Ideally use FirebaseAuth but profile might have 'isGuest' if we saved it?
          // UserProfileManager loads from SharedPreferences usually.
          // Let's rely on empty flag or specific nickname if needed.
          // Or just check if flag is empty/default.
          // User request implies guests might be logged in anonymously.
          if (_myNickname == 'Guest' ||
              (_myFlag == null || _myFlag!.isEmpty || _myFlag == '🏳️')) {
            _isGuest = true;
          } else {
            _isGuest = false;
          }

          if (_myFlag != null && _myFlag != '🏳️') {
            _targetFlag = _myFlag!;
            String? storedName = profile['countryName'];
            if (storedName == null || storedName == 'Unknown Region') {
              // Logic to optionally set flag if valid
            } else {
              // Valid
            }
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
      if (_myNickname != null) {
        myRank = await RankingSystem().getMyRank(
          widget.mapId,
          _myNickname!,
          flag: _isNational ? currentFilterFlag : null,
          period: _period,
        );
      }

      if (mounted) {
        setState(() {
          _records = records;
          _myRankData = myRank;
          _isLoading = false;
        });
        _scrollToHighlight();
      }
    } catch (e) {
      print("Error loading records: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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
    bool showMyRank = false;
    if (_myRankData != null) {
      bool isInList = _records.any((r) => r['id'] == _myRankData!['id']);
      showMyRank = !isInList;
    }

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.9 > 400
        ? 400.0
        : screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.8 > 600
        ? 600.0
        : screenSize.height * 0.8;

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
                    const SizedBox(height: 4),
                    Text(
                      RankingSystem.getPeriodLabel(_period).toUpperCase(),
                      style: AppTextStyles.body.copyWith(
                        color: Colors.orange,
                        letterSpacing: 1.2,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
                            label: "🌍 GLOBAL",
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
                            label: "${_myFlag ?? '🏳️'} NATIONAL",
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
                          RankingPeriod.daily,
                          LanguageManager.of(context).translate('day'),
                        ),
                        const SizedBox(width: 6),
                        _buildPeriodChip(
                          RankingPeriod.weekly,
                          LanguageManager.of(context).translate('week'),
                        ),
                        const SizedBox(width: 6),
                        _buildPeriodChip(
                          RankingPeriod.monthly,
                          LanguageManager.of(context).translate('month'),
                        ),
                        const SizedBox(width: 6),
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
                                  bool isMe =
                                      (widget.highlightRecordId != null &&
                                          data['id'] ==
                                              widget.highlightRecordId) ||
                                      (data['nickname'] == _myNickname &&
                                          _myNickname != null);

                                  return _buildListItem(index + 1, data, isMe);
                                },
                              ),
                      ),

                      // My Rank (if outside top list)
                      if (!_isLoading && showMyRank && _myRankData != null) ...[
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
                          _myRankData!['rank'] ?? -1,
                          _myRankData!,
                          true,
                          isMyRankSection: true,
                        ),
                      ],
                      const SizedBox(height: 16),

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

    return GestureDetector(
      onTap: () => _showUserInfoDialog(data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), // Increased gap
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary.withOpacity(0.15)
              : (isTop3
                    ? rankColor.withOpacity(0.05)
                    : Colors.white.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(12),
          // No borders as requested
          boxShadow: isTop3
              ? [
                  BoxShadow(
                    color: rankColor.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Fixed Width Rank
            SizedBox(
              width: 40,
              child: rankIcon != null
                  ? Icon(rankIcon, color: rankColor, size: 22)
                  : Text(
                      rankText,
                      style: TextStyle(
                        color: isMe
                            ? AppColors.primary
                            : (rank <= 30 ? Colors.white : Colors.white54),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontStyle: isMe ? FontStyle.italic : FontStyle.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: 12),

            // Fixed Width Flag
            SizedBox(
              width: 32,
              child: Text(
                data['flag'] ?? '🏳️',
                style: const TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 16),

            // Nickname (Flexible)
            Expanded(
              child: Text(
                data['nickname'] ?? 'Unknown',
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 16),

            // Fixed Width Score (Monospace for Alignment)
            SizedBox(
              width: 80,
              child: Text(
                "${data['survivalTime'].toStringAsFixed(2)}s",
                style: const TextStyle(
                  color: Color(0xFF00FF88), // Consistent Green
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace', // Ensure alignment
                  fontFeatures: [
                    FontFeature.tabularFigures(),
                  ], // Tabular alignment if font supports
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserInfoDialog(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _UserProfilePopup(mapId: widget.mapId, userData: userData),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.orange.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? Colors.orange
                  : AppColors.primaryDim.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.orange : AppColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
