import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ShareProfileDialog extends StatelessWidget {
  final String? email;
  final String host = "www.event-fit.it";

  const ShareProfileDialog({Key? key, required this.email}) : super(key: key);

  String? get profileUrl {
    if (email == null) return null;
    return 'https://$host/profilePage?email=$email';
  }

  void _copyToClipboard(BuildContext context) {
    if (profileUrl != null) {
      Clipboard.setData(ClipboardData(text: profileUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).link_copied)),
      );
    }
  }

  void _shareLink(BuildContext context) {
    if (profileUrl != null) {
      Share.share(
        AppLocalizations.of(context).view_my_profile(profileUrl!),
        subject: AppLocalizations.of(context).share_profile_subject,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (email == null) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context).error_title),
        content: Text(AppLocalizations.of(context).email_not_available),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).close),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(AppLocalizations.of(context).share_profile_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).profile_link_label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    profileUrl!,
                    style: const TextStyle(fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: AppLocalizations.of(context).copy_link,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
          ),
          child: Text(AppLocalizations.of(context).close),
        ),
        ElevatedButton.icon(
          onPressed: () => _shareLink(context),
          icon: const Icon(
            Icons.share,
            color: Colors.black,
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
          ),
          label: Text(AppLocalizations.of(context).share),
        ),
      ],
    );
  }
}
