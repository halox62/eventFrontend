import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareProfileDialog extends StatelessWidget {
  final String? email;
  final String host = "event-production.up.railway.app";

  const ShareProfileDialog({Key? key, required this.email}) : super(key: key);

  String? get profileUrl {
    if (email == null) return null;
    return 'https://$host/profilePage?email=$email';
  }

  void _copyToClipboard(BuildContext context) {
    if (profileUrl != null) {
      Clipboard.setData(ClipboardData(text: profileUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copiato negli appunti')),
      );
    }
  }

  void _shareLink() {
    if (profileUrl != null) {
      Share.share(
        'Guarda il mio profilo: $profileUrl',
        subject: 'Condividi profilo',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (email == null) {
      return AlertDialog(
        title: const Text('Errore'),
        content: const Text('Email non disponibile'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Condividi profilo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Link al profilo:'),
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
                  tooltip: 'Copia link',
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Chiudi'),
        ),
        ElevatedButton.icon(
          onPressed: _shareLink,
          icon: const Icon(Icons.share),
          label: const Text('Condividi'),
        ),
      ],
    );
  }
}
