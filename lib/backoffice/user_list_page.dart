import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:intl/intl.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allUsers = []; // 전체 로드된 원본
  List<DocumentSnapshot> _users = []; // 정렬/필터 후 표시용
  bool _loading = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  static const int _limit = 100; // 한 번에 넉넉하게 로드

  // Sort state
  String _sortColumn = 'createdAt';
  bool _sortAscending = false; // false = 최신순

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _allUsers = [];
      _lastDocument = null;
      _hasMore = true;
    }
    if (!_hasMore) return;

    setState(() => _loading = true);

    try {
      Query query = FirebaseFirestore.instance.collection('users');

      if (_searchController.text.isNotEmpty) {
        query = query.where('nickname', isEqualTo: _searchController.text.trim());
      } else {
        // orderBy 없이 로드 → 모든 유저(createdAt 없는 구버전 포함) 포함
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
        _allUsers.addAll(snapshot.docs);
      }

      _applySortAndFilter();
      setState(() => _loading = false);
    } catch (e) {
      print("Error fetching users: $e");
      setState(() => _loading = false);
    }
  }

  void _applySortAndFilter() {
    final query = _searchController.text.trim();
    List<DocumentSnapshot> filtered = query.isEmpty
        ? List.from(_allUsers)
        : _allUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['nickname'] ?? '').toString().toLowerCase().contains(query.toLowerCase());
          }).toList();

    filtered.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db = b.data() as Map<String, dynamic>;
      int cmp;
      switch (_sortColumn) {
        case 'createdAt':
          final ta = (da['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final tb = (db['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          cmp = ta.compareTo(tb);
          break;
        case 'lastUpdated':
          final ta = (da['lastUpdated'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final tb = (db['lastUpdated'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          cmp = ta.compareTo(tb);
          break;
        case 'totalGamesPlayed':
          final ta = (da['totalGamesPlayed'] as int?) ?? 0;
          final tb = (db['totalGamesPlayed'] as int?) ?? 0;
          cmp = ta.compareTo(tb);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });

    _users = filtered;
  }

  void _showEditDialog(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        userDoc: doc,
        onSave: () => _fetchUsers(refresh: true),
      ),
    );
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false;
      }
      _applySortAndFilter();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "사용자 관리",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
            onChanged: (_) => setState(() => _applySortAndFilter()),
            onSubmitted: (_) => setState(() => _applySortAndFilter()),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
                _searchController.clear();
                _fetchUsers(refresh: true);
              },
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
                    sortColumnIndex: _searchController.text.isEmpty
                        ? _sortColumn == 'createdAt' ? 4
                          : _sortColumn == 'lastUpdated' ? 5
                          : _sortColumn == 'totalGamesPlayed' ? 6
                          : null
                        : null,
                    sortAscending: _sortAscending,
                    columns: [
                      const DataColumn(
                        label: Text(
                          '닉네임',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '국가',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '플랫폼 / 로그인',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '이메일 / UID',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                      ),
                      DataColumn(
                        label: _buildSortableHeader('가입일', 'createdAt'),
                        onSort: (_, __) => _onSort('createdAt'),
                      ),
                      DataColumn(
                        label: _buildSortableHeader('최근 플레이', 'lastUpdated'),
                        onSort: (_, __) => _onSort('lastUpdated'),
                      ),
                      DataColumn(
                        numeric: true,
                        label: _buildSortableHeader('총 게임 수', 'totalGamesPlayed'),
                        onSort: (_, __) => _onSort('totalGamesPlayed'),
                      ),
                      const DataColumn(
                        numeric: true,
                        label: Text(
                          'S1',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4FACFE)),
                        ),
                      ),
                      const DataColumn(
                        numeric: true,
                        label: Text(
                          'S2',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF43E97B)),
                        ),
                      ),
                      const DataColumn(
                        numeric: true,
                        label: Text(
                          'S3',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '보유 티켓 (닉/국)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '관리',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                      ),
                    ],
                    rows: _users.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final mapCounts = data['mapPlayCounts'] as Map<String, dynamic>? ?? {};
                      final zone1 = mapCounts['zone_1_classic'] as int? ?? 0;
                      final zone2 = mapCounts['zone_2_hard'] as int? ?? 0;
                      final zone3 = mapCounts['zone_3_obstacles'] as int? ?? 0;
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                      final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
                      return DataRow(
                        cells: [
                          DataCell(
                            Container(
                              constraints: const BoxConstraints(minWidth: 120),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white10,
                                    child: Text(
                                      (data['flag'] == null || data['flag'].toString().isEmpty)
                                          ? '🏳️'
                                          : data['flag'],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    data['nickname'] ?? '-',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 100,
                              child: Text(
                                data['countryName'] ?? '-',
                                style: const TextStyle(color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(_buildPlatformInfo(data)),
                          DataCell(_buildEmailCell(data, doc.id)),
                          DataCell(Text(
                            createdAt != null
                                ? DateFormat('yy/MM/dd HH:mm').format(createdAt)
                                : '-',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          )),
                          DataCell(Text(
                            lastUpdated != null
                                ? DateFormat('yy/MM/dd HH:mm').format(lastUpdated)
                                : '-',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          )),
                          DataCell(Text(
                            NumberFormat('#,###').format(data['totalGamesPlayed'] ?? 0),
                            style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontWeight: FontWeight.bold),
                          )),
                          DataCell(_buildStageCount(zone1, const Color(0xFF4FACFE))),
                          DataCell(_buildStageCount(zone2, const Color(0xFF43E97B))),
                          DataCell(_buildStageCount(zone3, const Color(0xFFFFD700))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTicketBadge(data['nicknameTickets'] ?? 0, Colors.blueAccent),
                                const SizedBox(width: 8),
                                _buildTicketBadge(data['countryTickets'] ?? 0, Colors.orangeAccent),
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

  Widget _buildSortableHeader(String label, String column) {
    final isActive = _sortColumn == column;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF00FF88) : Colors.white70,
          ),
        ),
        if (isActive) ...[
          const SizedBox(width: 4),
          Icon(
            _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: const Color(0xFF00FF88),
          ),
        ],
      ],
    );
  }

  Widget _buildStageCount(int count, Color color) {
    if (count == 0) {
      return const Text('-', style: TextStyle(color: Colors.white24, fontSize: 13));
    }
    return Text(
      NumberFormat('#,###').format(count),
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
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

  Widget _buildEmailCell(Map<String, dynamic> data, String docId) {
    final email = data['email'] as String? ?? '';
    final hasEmail = email.isNotEmpty;
    final displayText = hasEmail ? email : docId;
    final loginProvider = data['loginProvider'] as String? ?? '';

    Color providerColor = Colors.white30;
    if (loginProvider == 'Google') providerColor = const Color(0xFF4285F4);
    if (loginProvider == 'Apple') providerColor = Colors.white70;

    return Tooltip(
      message: 'UID: $docId',
      child: SizedBox(
        width: 180,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayText,
              style: TextStyle(
                color: hasEmail ? providerColor : Colors.white24,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (!hasEmail)
              const Text(
                '이메일 미등록',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
          ],
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
        platformIcon = Icons.help_outline_rounded;
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
  late TextEditingController _nickTicketCtrl;
  late TextEditingController _countryTicketCtrl;
  late int _totalGamesPlayed;
  late String _selectedFlag;
  late String _selectedCountryName;

  @override
  void initState() {
    super.initState();
    final data = widget.userDoc.data() as Map<String, dynamic>;
    _nicknameCtrl = TextEditingController(text: data['nickname'] ?? '');
    _nickTicketCtrl = TextEditingController(
      text: (data['nicknameTickets'] ?? 0).toString(),
    );
    _countryTicketCtrl = TextEditingController(
      text: (data['countryTickets'] ?? 0).toString(),
    );
    _totalGamesPlayed = (data['totalGamesPlayed'] as int?) ?? 0;
    _selectedFlag = data['flag'] as String? ?? '';
    _selectedCountryName = data['countryName'] as String? ?? '';
  }

  Future<void> _save() async {
    try {
      await widget.userDoc.reference.update({
        'nickname': _nicknameCtrl.text.trim(),
        'flag': _selectedFlag,
        'countryName': _selectedCountryName,
        'nicknameTickets': int.tryParse(_nickTicketCtrl.text) ?? 0,
        'countryTickets': int.tryParse(_countryTicketCtrl.text) ?? 0,
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("계정 삭제 확인", style: TextStyle(color: Colors.white)),
        content: const Text(
          "정말로 이 사용자를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text("삭제", style: TextStyle(fontWeight: FontWeight.bold)),
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
    final data = widget.userDoc.data() as Map<String, dynamic>;
    final email = data['email'] as String? ?? '';
    final platform = data['platform'] as String? ?? 'Unknown';
    final loginProvider = data['loginProvider'] as String? ?? 'Unknown';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();

    return Dialog(
      backgroundColor: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.manage_accounts_rounded, color: Color(0xFF00FF88), size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    "사용자 정보 수정",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 읽기 전용 계정 정보
                    _buildSectionLabel("계정 정보", Colors.white54),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow("UID", widget.userDoc.id, monospace: true),
                          const SizedBox(height: 6),
                          _buildInfoRow("이메일", email.isNotEmpty ? email : '(미등록)'),
                          const SizedBox(height: 6),
                          _buildInfoRow("플랫폼 / 로그인", '$platform  ·  $loginProvider'),
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            "가입일",
                            createdAt != null
                                ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
                                : '-',
                          ),
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            "마지막 접속",
                            lastUpdated != null
                                ? DateFormat('yyyy-MM-dd HH:mm').format(lastUpdated)
                                : '-',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),

                    // 기본 정보
                    _buildSectionLabel("기본 정보", Colors.white70),
                    const SizedBox(height: 10),
                    _buildDialogTextField(_nicknameCtrl, "닉네임", Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildCountrySelector(),

                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),

                    // 아이템 관리
                    _buildSectionLabel("아이템 관리", Colors.white70),
                    const SizedBox(height: 10),
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

                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),

                    // 통계
                    _buildSectionLabel("통계", Colors.white54),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.games, size: 16, color: Colors.white38),
                          const SizedBox(width: 10),
                          const Text("총 게임 플레이 수", style: TextStyle(color: Colors.white54, fontSize: 13)),
                          const Spacer(),
                          Text(
                            NumberFormat('#,###').format(_totalGamesPlayed),
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _deleteUser,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text("계정 삭제"),
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("취소", style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text("저장", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountrySelector() {
    final hasCountry = _selectedCountryName.isNotEmpty;
    return InkWell(
      onTap: () {
        showCountryPicker(
          context: context,
          showPhoneCode: false,
          favorite: ['KR', 'US', 'JP'],
          countryListTheme: CountryListThemeData(
            backgroundColor: const Color(0xFF2C2C2C),
            textStyle: const TextStyle(color: Colors.white),
            searchTextStyle: const TextStyle(color: Colors.white),
            inputDecoration: InputDecoration(
              hintText: '국가 검색...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          onSelect: (Country country) {
            setState(() {
              _selectedFlag = country.flagEmoji;
              _selectedCountryName = country.name;
            });
          },
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasCountry ? const Color(0xFF00FF88).withValues(alpha: 0.4) : Colors.white24),
        ),
        child: Row(
          children: [
            Icon(Icons.public, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: hasCountry
                  ? Row(
                      children: [
                        Text(_selectedFlag, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Text(
                          _selectedCountryName,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    )
                  : const Text(
                      '국가 선택',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool monospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: monospace ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
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
