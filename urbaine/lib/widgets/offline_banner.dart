import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final bool isAuthOffline;
  
  const OfflineBanner({
    Key? key,
    this.isAuthOffline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFF9800), // Orange color
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            color: Color(0xFFFFFFFF), // White color
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              isAuthOffline
                ? 'Mode hors ligne (authentification). Vous pouvez consulter et créer des incidents qui seront synchronisés lorsque vous serez en ligne.'
                : 'Vous êtes hors ligne. Les incidents seront enregistrés localement et synchronisés ultérieurement.',
              style: const TextStyle(
                color: Color(0xFFFFFFFF), // White color
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}