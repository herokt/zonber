import 'package:flutter/material.dart';
import 'ranking_system.dart';
import 'user_profile.dart';

import 'design_system.dart';

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
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _myRankData; // 내 등수 데이터
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
        );
      } else {
        records = await RankingSystem().getTopRecords(widget.mapId);
      }

      Map<String, dynamic>? myRank;
      if (_myNickname != null) {
        myRank = await RankingSystem().getMyRank(
          widget.mapId,
          _myNickname!,
          flag: _isNational ? currentFilterFlag : null,
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

    return Center(
      child: SizedBox(
        width: 360,
        height: 640,
        child: NeonCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Text(
                      "GLOBAL LEADERBOARD",
                      style: AppTextStyles.header.copyWith(
                        fontSize: 26,
                        color: AppColors.primary,
                        shadows: [
                          const Shadow(
                            blurRadius: 10,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "WEEKLY CHALLENGE",
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
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
                                  "No records yet",
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

                      // My Rank (if outside)
                      if (!_isLoading && showMyRank && _myRankData != null) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "MY RANK",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildListItem(
                          _myRankData!['rank'],
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
                              text: "CLOSE",
                              onPressed: widget.onClose,
                              isPrimary: false,
                              isCompact: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: NeonButton(
                              text: "SHARE",
                              onPressed: () {},
                              isPrimary: false,
                              isCompact: true,
                            ), // Placeholder share
                          ),
                          if (widget.onRestart != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: NeonButton(
                                text: "REPLAY",
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withOpacity(0.1)
            : Colors.transparent, // Updated for Neon theme
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? (isMyRankSection ? AppColors.primary : AppColors.primaryDim)
              : AppColors.primaryDim.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "$rank.",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Text(data['flag'] ?? '🏳️', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          // Country code removed as requested
          Expanded(
            child: Text(
              data['nickname'] ?? 'Unknown', // Hyphen removed
              style: TextStyle(
                color: isMe ? AppColors.primary : Colors.white,
                fontSize: 16,
                fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            "${data['survivalTime'].toStringAsFixed(1)}s",
            style: const TextStyle(
              color: AppColors.textDim,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
