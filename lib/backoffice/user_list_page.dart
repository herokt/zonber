import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _users = [];
  bool _loading = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  static const int _limit = 20;

  // Filter state
  // 'recent': date desc
  // 'top_played': totalGamesPlayed desc
  String _currentFilter = 'recent';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _users = [];
      _lastDocument = null;
      _hasMore = true;
    }
    if (!_hasMore) return;

    setState(() => _loading = true);

    try {
      Query query = FirebaseFirestore.instance.collection('users');

      if (_searchController.text.isNotEmpty) {
        // Search mode: exact match for nickname
        query = query.where(
          'nickname',
          isEqualTo: _searchController.text.trim(),
        );
      } else {
        // List mode: apply sorting
        if (_currentFilter == 'recent') {
          query = query.orderBy('lastUpdated', descending: true);
        } else if (_currentFilter == 'top_played') {
          query = query.orderBy('totalGamesPlayed', descending: true);
        }

        query = query.limit(_limit);

        if (_lastDocument != null) {
          query = query.startAfterDocument(_lastDocument!);
        }
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _users.addAll(snapshot.docs);
      }

      setState(() => _loading = false);
    } catch (e) {
      print("Error fetching users: $e");
      setState(() => _loading = false);
    }
  }

  void _showEditDialog(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        userDoc: doc,
        onSave: () {
          _fetchUsers(refresh: true);
        },
      ),
    );
  }

  void _changeFilter(String filter) {
    if (_currentFilter == filter) return;
    setState(() {
      _currentFilter = filter;
      _searchController.clear();
    });
    _fetchUsers(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "사용자 관리 (v2)",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              _buildFilterChips(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSearchBar(),
          const SizedBox(height: 24),
          Expanded(child: _buildUserTable()),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_hasMore && _searchController.text.isEmpty && !_loading)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton.icon(
                  onPressed: () => _fetchUsers(),
                  icon: const Icon(Icons.arrow_downward_rounded),
                  label: const Text("더 불러오기", style: TextStyle(fontSize: 16)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00FF88),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip("최신 활동순", 'recent'),
          const SizedBox(width: 12),
          _buildChip("플레이 횟수순", 'top_played'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _currentFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: FontWeight.bold,
        ),
      ),
      selectedColor: const Color(0xFF00FF88),
      backgroundColor: Colors.white10,
      showCheckmark: false,
      onSelected: (_) => _changeFilter(value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "닉네임 정확히 입력",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _fetchUsers(refresh: true),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () => _fetchUsers(refresh: true),
            icon: const Icon(Icons.refresh, color: Color(0xFF00FF88)),
            tooltip: "새로고침",
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTable() {
    return Container(
      width: double.infinity, // Force full width
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          // Use LayoutBuilder to handle constraints
          builder: (context, constraints) {
            // Guard against unbounded width
            final double minWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : 1000.0;
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFF2C2C2C),
                    ),
                    dataRowColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return Colors.white.withOpacity(0.05);
                      }
                      return Colors.transparent;
                    }),
                    horizontalMargin: 32, // Increased margin
                    columnSpacing: 60, // Significantly increased spacing
                    headingRowHeight: 56,
                    dataRowMinHeight: 72, // Taller rows
                    dataRowMaxHeight: 72,
                    columns: const [
                      DataColumn(
                        label: Text(
                          '닉네임',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '국가',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '플랫폼 / 로그인',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      DataColumn(
                        numeric: true, // Right align numbers
                        label: Text(
                          '총 게임 수',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '보유 티켓 (닉/국)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '관리',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                    rows: _users.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DataRow(
                        cells: [
                          DataCell(
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 120,
                              ), // Min width for nickname
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white10,
                                    child: Text(
                                      (data['flag'] == null ||
                                              data['flag'].toString().isEmpty)
                                          ? '🏳️'
                                          : data['flag'],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    data['nickname'] ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              // Fixed width container
                              width: 100,
                              child: Text(
                                data['countryName'] ?? '-',
                                style: const TextStyle(color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            _buildPlatformInfo(data),
                          ),
                          DataCell(
                            Text(
                              NumberFormat(
                                '#,###',
                              ).format(data['totalGamesPlayed'] ?? 0),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTicketBadge(
                                  data['nicknameTickets'] ?? 0,
                                  Colors.blueAccent,
                                ),
                                const SizedBox(width: 8),
                                _buildTicketBadge(
                                  data['countryTickets'] ?? 0,
                                  Colors.orangeAccent,
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            IconButton(
                              tooltip: "정보 수정",
                              icon: const Icon(Icons.edit_note_rounded),
                              color: const Color(0xFF00FF88),
                              onPressed: () => _showEditDialog(doc),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTicketBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlatformInfo(Map<String, dynamic> data) {
    final platform = data['platform'] as String? ?? 'Unknown';
    final loginProvider = data['loginProvider'] as String? ?? 'Unknown';

    // Determine icon and color based on platform
    IconData platformIcon;
    Color platformColor;

    switch (platform) {
      case 'Android':
        platformIcon = Icons.android;
        platformColor = const Color(0xFF3DD9EB);
        break;
      case 'iOS':
        platformIcon = Icons.apple;
        platformColor = const Color(0xFFFFFFFF);
        break;
      case 'Web':
        platformIcon = Icons.web;
        platformColor = const Color(0xFFFF9800);
        break;
      default:
        platformIcon = Icons.phone_android;
        platformColor = const Color(0xFF9E9E9E);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: platformColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: platformColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                platformIcon,
                size: 14,
                color: platformColor.withOpacity(0.8),
              ),
              const SizedBox(width: 6),
              Text(
                platform,
                style: TextStyle(
                  fontSize: 12,
                  color: platformColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          loginProvider,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

class EditUserDialog extends StatefulWidget {
  final DocumentSnapshot userDoc;
  final VoidCallback onSave;

  const EditUserDialog({
    super.key,
    required this.userDoc,
    required this.onSave,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late TextEditingController _nicknameCtrl;
  late TextEditingController _flagCtrl;
  late TextEditingController _countryNameCtrl;
  late TextEditingController _nickTicketCtrl;
  late TextEditingController _countryTicketCtrl;
  late TextEditingController _gamesCtrl;

  @override
  void initState() {
    super.initState();
    final data = widget.userDoc.data() as Map<String, dynamic>;
    _nicknameCtrl = TextEditingController(text: data['nickname'] ?? '');
    _flagCtrl = TextEditingController(text: data['flag'] ?? '');
    _countryNameCtrl = TextEditingController(text: data['countryName'] ?? '');
    _nickTicketCtrl = TextEditingController(
      text: (data['nicknameTickets'] ?? 0).toString(),
    );
    _countryTicketCtrl = TextEditingController(
      text: (data['countryTickets'] ?? 0).toString(),
    );
    _gamesCtrl = TextEditingController(
      text: (data['totalGamesPlayed'] ?? 0).toString(),
    );
  }

  Future<void> _save() async {
    try {
      await widget.userDoc.reference.update({
        'nickname': _nicknameCtrl.text.trim(),
        'flag': _flagCtrl.text.trim(),
        'countryName': _countryNameCtrl.text.trim(),
        'nicknameTickets': int.tryParse(_nickTicketCtrl.text) ?? 0,
        'countryTickets': int.tryParse(_countryTicketCtrl.text) ?? 0,
        'totalGamesPlayed': int.tryParse(_gamesCtrl.text) ?? 0,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSave();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("에러 발생: $e")));
    }
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("계정 삭제 확인"),
        content: const Text("정말로 이 사용자를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "삭제",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.userDoc.reference.delete();
        if (mounted) {
          Navigator.pop(context);
          widget.onSave();
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("에러 발생: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      title: const Text("사용자 정보 수정", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogTextField(_nicknameCtrl, "닉네임", Icons.person_outline),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDialogTextField(
                    _flagCtrl,
                    "국기(이모지)",
                    Icons.flag_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildDialogTextField(
                    _countryNameCtrl,
                    "국가명",
                    Icons.public,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Divider(color: Colors.white24),
            ),
            const Text(
              "아이템 관리",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCounterField(
                    _nickTicketCtrl,
                    "닉변권",
                    Icons.confirmation_number_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCounterField(
                    _countryTicketCtrl,
                    "국변권",
                    Icons.confirmation_number_outlined,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Divider(color: Colors.white24),
            ),
            const Text(
              "통계 수정 (주의)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            _buildDialogTextField(_gamesCtrl, "총 게임 플레이 수", Icons.games),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleteUser,
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text("계정 삭제"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소", style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF88),
            foregroundColor: Colors.black,
          ),
          onPressed: _save,
          child: const Text("저장"),
        ),
      ],
    );
  }

  Widget _buildDialogTextField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF00FF88)),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.black12,
      ),
    );
  }

  Widget _buildCounterField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.remove,
                  size: 16,
                  color: Colors.redAccent,
                ),
                onPressed: () {
                  int val = int.tryParse(ctrl.text) ?? 0;
                  if (val > 0) {
                    setState(() => ctrl.text = (val - 1).toString());
                  }
                },
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: IconButton(
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF00FF88)),
                onPressed: () {
                  int val = int.tryParse(ctrl.text) ?? 0;
                  setState(() => ctrl.text = (val + 1).toString());
                },
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
