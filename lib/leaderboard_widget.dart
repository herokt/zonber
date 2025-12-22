import 'package:flutter/material.dart';
import 'ranking_system.dart';
import 'user_profile.dart';
import 'package:country_picker/country_picker.dart';

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
  String _targetCountryName = 'South Korea';

  @override
  void initState() {
    super.initState();
    _loadProfileAndRecords();
  }

  Future<void> _loadProfileAndRecords() async {
    // 1. Get User Profile
    try {
      final profile = await UserProfileManager.getProfile();
      if (mounted) {
        setState(() {
          _myFlag = profile['flag'];
          _myNickname = profile['nickname'];
          // If user has a flag, set it as default target for national ranking
          if (_myFlag != null && _myFlag != '🏳️') {
            _targetFlag = _myFlag!;
            String? storedName = profile['countryName'];
            if (storedName == null || storedName == 'Unknown Region') {
              // Fallback for existing users or if name is missing
              if (_targetFlag == '🇰🇷') {
                _targetCountryName = 'South Korea';
              } else {
                _targetCountryName = 'Selected'; // Generic fallback
              }
            } else {
              _targetCountryName = storedName;
            }
          }
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
    }

    // 2. Load Records
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _myRankData = null; // Reset my rank data
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

      // 내 랭킹 따로 조회 (리스트에 없을 경우 대비)
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
          double position = index * 56.0; // Approx item height (reduced)
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

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        setState(() {
          _targetFlag = country.flagEmoji;
          _targetCountryName = country.name;
          _loadRecords();
        });
      },
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF1F2833),
        textStyle: const TextStyle(color: Colors.white),
        searchTextStyle: const TextStyle(color: Colors.white),
        bottomSheetHeight: 600,
        borderRadius: BorderRadius.circular(20),
        inputDecoration: const InputDecoration(
          hintText: 'Search country',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF66FCF1)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showMyRank = false;
    if (_myRankData != null) {
      bool isInList = _records.any((r) => r['id'] == _myRankData!['id']);
      showMyRank = !isInList;
    }

    return Center(
      child: Container(
        width: 320,
        height: 600,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0C10).withOpacity(0.95),
          border: Border.all(color: const Color(0xFF45A29E), width: 3),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            const Text(
              "RANKING",
              style: TextStyle(
                color: Color(0xFF45A29E),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            // Tabs
            Row(
              children: [
                Expanded(child: _buildTabButton("Global", !_isNational)),
                const SizedBox(width: 10),
                Expanded(child: _buildTabButton("National", _isNational)),
              ],
            ),
            // Country Selector (Visible only when National is active)
            if (_isNational) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "$_targetFlag $_targetCountryName",
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(color: Colors.grey),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF45A29E),
                      ),
                    )
                  : _records.isEmpty
                  ? const Center(
                      child: Text(
                        "No records yet!",
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        var data = _records[index];
                        bool isMine =
                            (widget.highlightRecordId != null &&
                                data['id'] == widget.highlightRecordId) ||
                            (data['nickname'] == _myNickname &&
                                _myNickname != null);

                        return _buildRankItem(index + 1, data, isMine);
                      },
                    ),
            ),
            // 내 등수 (30위 밖일 때)
            if (!_isLoading && showMyRank && _myRankData != null) ...[
              const Divider(color: Color(0xFF45A29E), thickness: 1),
              _buildRankItem(_myRankData!['rank'], _myRankData!, true),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.onRestart != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF21D1D),
                    ),
                    onPressed: widget.onRestart,
                    child: const Text(
                      "RESTART",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (widget.onRestart != null) const SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2833),
                  ),
                  onPressed: widget.onClose,
                  child: Text(
                    widget.onRestart != null ? "EXIT" : "CLOSE",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (isActive) return;
        setState(() {
          _isNational = text == "National";
          _loadRecords();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF45A29E) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF45A29E) : Colors.grey,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRankItem(int rank, Map<String, dynamic> data, bool highlight) {
    // highlight argument is now ignored/re-calculated for Granular control
    bool isMe = data['nickname'] == _myNickname;
    bool isCurrentRecord =
        widget.highlightRecordId != null &&
        data['id'] == widget.highlightRecordId;

    return Container(
      height: 56, // Reduced height
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        // Background: Orange tint if Me, else transparent
        color: isMe ? Colors.orangeAccent.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
        // Border: Red if Current, else none
        border: isCurrentRecord
            ? Border.all(
                color: const Color(0xFFF21D1D), // Red Border
                width: 2,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                "#$rank",
                style: TextStyle(
                  color: isMe ? Colors.orangeAccent : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontStyle: isMe ? FontStyle.italic : FontStyle.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            Text(data['flag'] ?? '🏳️', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data['nickname'] ?? 'Unknown',
                style: TextStyle(
                  color: isMe ? Colors.orangeAccent : Colors.white,
                  fontSize: 14,
                  fontWeight: sizeForNick(data['nickname']),
                  fontStyle: isMe ? FontStyle.italic : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              "${data['survivalTime'].toStringAsFixed(3)}s",
              style: const TextStyle(
                color: Color(0xFF66FCF1),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  FontWeight sizeForNick(String? nick) {
    return (nick == _myNickname) ? FontWeight.bold : FontWeight.normal;
  }
}
