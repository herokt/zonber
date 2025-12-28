import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'ranking_system.dart';
import 'user_profile.dart';

import 'design_system.dart';
import 'language_manager.dart';

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
                        _isNational ? "NATIONAL RANKING" : "GLOBAL RANKING",
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
                            onTap: () {
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: NeonButton(
                              text: LanguageManager.of(
                                context,
                              ).translate('share'),
                              onPressed: () {},
                              isPrimary: false,
                              isCompact: true,
                              color: Colors.amber,
                            ),
                          ),
                          if (widget.onRestart != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: NeonButton(
                                text: LanguageManager.of(
                                  context,
                                ).translate('replay'),
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
    final String rankText = (rank <= 0) ? "-" : "$rank.";

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? (isMyRankSection ? AppColors.primary : AppColors.primaryDim)
              : AppColors.primaryDim.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              rankText,
              style: TextStyle(
                color: isMe ? AppColors.primary : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(data['flag'] ?? '🏳️', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data['nickname'] ?? 'Unknown',
              style: TextStyle(
                color: isMe ? AppColors.primary : Colors.white,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            "${data['survivalTime'].toStringAsFixed(3)}s",
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.primaryDim.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textDim,
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
