import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      Query query = FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastUpdated', descending: true)
          .limit(_limit);

      if (_searchController.text.isNotEmpty) {
        // Simple search (Note: Firestore requires exact match or range for strings usually, unless configured)
        // For now, let's just try accurate nickname search
        query = FirebaseFirestore.instance
            .collection('users')
            .where('nickname', isEqualTo: _searchController.text.trim());
      } else {
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
          _fetchUsers(refresh: true); // Refresh list after save
        },
      ),
    );
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
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: "닉네임 정확히 입력",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _fetchUsers(refresh: true),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchUsers(refresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text("검색 / 새로고침"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Table
          Expanded(
            child: Card(
              color: const Color(0xFF2C2C2C),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.black12),
                      columns: const [
                        DataColumn(
                          label: Text(
                            '닉네임',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '국가',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '총 게임 수',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '보유 티켓 (닉/국)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '관리',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: _users.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DataRow(
                          cells: [
                            DataCell(Text(data['nickname'] ?? '-')),
                            DataCell(
                              Text(
                                "${data['flag'] ?? ''} ${data['countryName'] ?? '-'}",
                              ),
                            ),
                            DataCell(Text("${data['totalGamesPlayed'] ?? 0}")),
                            DataCell(
                              Text(
                                "${data['nicknameTickets'] ?? 0} / ${data['countryTickets'] ?? 0}",
                              ),
                            ),
                            DataCell(
                              IconButton(
                                tooltip: "정보 수정",
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF00FF88),
                                ),
                                onPressed: () => _showEditDialog(doc),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_hasMore && _searchController.text.isEmpty && !_loading)
            Center(
              child: TextButton(
                onPressed: () => _fetchUsers(),
                child: const Text("더 불러오기", style: TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
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
  late TextEditingController
  _flagCtrl; // Manual Emoji Input for now? Or Country Code
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
      title: const Text("사용자 정보 수정"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nicknameCtrl,
              decoration: const InputDecoration(
                labelText: "닉네임",
                suffixIcon: Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _flagCtrl,
                    decoration: const InputDecoration(labelText: "국기(이모지)"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _countryNameCtrl,
                    decoration: const InputDecoration(labelText: "국가명"),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              "아이템 관리",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nickTicketCtrl,
                    decoration: const InputDecoration(labelText: "닉변권 수량"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _countryTicketCtrl,
                    decoration: const InputDecoration(labelText: "국변권 수량"),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              "통계 수정 (주의)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            TextField(
              controller: _gamesCtrl,
              decoration: const InputDecoration(labelText: "총 게임 플레이 수"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleteUser,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text("계정 삭제"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소"),
        ),
        ElevatedButton(onPressed: _save, child: const Text("저장")),
      ],
    );
  }
}
