import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../language_manager.dart';
import '../design_system.dart'; // basic design system usage if needed for snackbar styling

class InviteService {
  static String generateInviteMessage(BuildContext context, String nickname) {
    final lang = LanguageManager.of(context);
    final title = lang.translate('invite_message_title');
    final body = lang
        .translate('invite_message_body')
        .replaceAll('{code}', nickname);
    final link = lang.translate('download_link');

    return '$title\n$body\n\n$link';
  }

  static Future<void> copyToClipboard(
    BuildContext context,
    String nickname,
  ) async {
    final message = generateInviteMessage(context, nickname);
    await Clipboard.setData(ClipboardData(text: message));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageManager.of(context).translate('invite_copied'),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
