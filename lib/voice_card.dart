import 'package:flutter/material.dart';

class VoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap; // ✅ Click event (optional)
  final VoidCallback? onDelete; // ✅ Optional delete action

  const VoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4, // ✅ Adds a slight shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // ✅ Rounded edges
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        leading: const Icon(Icons.mic, color: Colors.blueAccent), // ✅ Mic icon
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete, // ✅ Delete action
              )
            : null,
        onTap: onTap, // ✅ Optional tap action
      ),
    );
  }
}
