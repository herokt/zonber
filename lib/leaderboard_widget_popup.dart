

part of 'leaderboard_widget.dart';

class _UserProfilePopup extends StatefulWidget {
  final String mapId;
  final Map<String, dynamic> userData;

  const _UserProfilePopup({
    required this.mapId,
    required this.userData,
  });

  @override
  State<_UserProfilePopup> createState() => _UserProfilePopupState();
}

class _UserProfilePopupState extends State<_UserProfilePopup> {
  List<String> _titles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTitles();
  }

  Future<void> _loadTitles() async {
    final titles = await RankingSystem().getUserTitles(
      widget.mapId,
      widget.userData['nickname'],
    );
    if (mounted) {
      setState(() {
        _titles = titles;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine highest badge
    String? highestTitle;
    IconData mainIcon = Icons.person;
    Color mainColor = AppColors.textDim;
    
    // Priority: Legendary -> Monthly -> Weekly -> Daily
    if (_titles.contains('Legendary Survivor')) {
      highestTitle = 'Legendary Survivor';
      mainIcon = Icons.workspace_premium;
      mainColor = const Color(0xFFE5E4E2); // Platinum
    } else if (_titles.contains('Monthly Ranker')) {
      highestTitle = 'Monthly Ranker';
      mainIcon = Icons.calendar_month;
      mainColor = const Color(0xFFFFD700); // Gold
    } else if (_titles.contains('Weekly Ranker')) {
      highestTitle = 'Weekly Ranker';
      mainIcon = Icons.calendar_view_week;
      mainColor = const Color(0xFFC0C0C0); // Silver
    } else if (_titles.contains('Daily Ranker')) {
      highestTitle = 'Daily Ranker';
      mainIcon = Icons.sunny;
      mainColor = const Color(0xFFFF8C00); // Orange
    }

    return NeonCard(
       padding: const EdgeInsets.all(20),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           // Profile Header
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Text(
                 widget.userData['flag'] ?? '🏳️',
                 style: const TextStyle(fontSize: 32),
               ),
               const SizedBox(width: 12),
               Flexible(
                 child: Text(
                   widget.userData['nickname'] ?? 'Unknown',
                   style: const TextStyle(
                     color: Colors.white,
                     fontSize: 20,
                     fontWeight: FontWeight.bold,
                   ),
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
             ],
           ),
           const SizedBox(height: 4),
           Text(
             "Record: ${widget.userData['survivalTime'].toStringAsFixed(3)}s",
             style: const TextStyle(
               color: Colors.orange,
               fontSize: 14,
               fontWeight: FontWeight.bold,
             ),
           ),
           const SizedBox(height: 24),

           // Main Badge Display
           if (_isLoading)
             const CircularProgressIndicator(color: AppColors.primary)
           else if (highestTitle != null) ...[
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: mainColor.withOpacity(0.1),
                 border: Border.all(color: mainColor, width: 3),
                 boxShadow: [
                   BoxShadow(
                     color: mainColor.withOpacity(0.3),
                     blurRadius: 20,
                     spreadRadius: 2,
                   )
                 ]
               ),
               child: Icon(mainIcon, color: mainColor, size: 32),
             ),
             const SizedBox(height: 12),
             Text(
               LanguageManager.of(context).translate(highestTitle).toUpperCase(),
               style: TextStyle(
                 color: mainColor,
                 fontSize: 14,
                 fontWeight: FontWeight.bold,
                 letterSpacing: 1.2,
                 shadows: [Shadow(color: mainColor, blurRadius: 10)],
               ),
             ),
           ] else ...[
             const Icon(Icons.person_outline, size: 64, color: AppColors.textDim),
             const SizedBox(height: 12),
             Text(
               LanguageManager.of(context).translate('no_titles'),
               style: TextStyle(
                 color: AppColors.textDim,
                 fontSize: 14,
                 letterSpacing: 1.2,
               ),
             ),
           ],

           const SizedBox(height: 24),

           // All Titles List
           if (!_isLoading && _titles.isNotEmpty) ...[
             const Divider(color: AppColors.textDim, height: 1),
             const SizedBox(height: 12),
             Wrap(
               spacing: 8,
               runSpacing: 8,
               alignment: WrapAlignment.center,
               children: _titles.map((title) {
                 // Skip main title if you want, but showing all is fine too
                 Color color = AppColors.textDim;
                 if (title.contains('Legendary')) color = const Color(0xFFE5E4E2);
                 if (title.contains('Monthly')) color = const Color(0xFFFFD700);
                 if (title.contains('Weekly')) color = const Color(0xFFC0C0C0);
                 if (title.contains('Daily')) color = const Color(0xFFFF8C00);

                 return Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                   decoration: BoxDecoration(
                     color: color.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(20),
                     border: Border.all(color: color.withOpacity(0.5)),
                   ),
                   child: Text(
                     LanguageManager.of(context).translate(title),
                     style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                   ),
                 );
               }).toList(),
             ),
           ],

           const SizedBox(height: 24),
           
           // Close Button
           SizedBox(
             width: double.infinity,
             child: NeonButton(
               text: LanguageManager.of(context).translate('close'),
               onPressed: () => Navigator.pop(context),
               isPrimary: false,
             ),
           ),
         ],
       ),
    );
  }
}
