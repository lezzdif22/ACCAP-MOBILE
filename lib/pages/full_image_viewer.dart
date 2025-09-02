import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

class FullImageViewer extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onDelete;
  final VoidCallback? onChange;

  const FullImageViewer({
    super.key,
    required this.imageUrl,
    this.onDelete,
    this.onChange,
  });

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Change Photo'),
              onTap: () {
                Navigator.pop(context);
                if (onChange != null) onChange!();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Photo', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color.fromARGB(255, 250, 250, 250),
                    title: const Text('Delete Photo'),
                    content: const Text('Are you sure you want to delete this photo?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && onDelete != null) {
                  onDelete!();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () { HapticService.instance.selection(); Navigator.pop(context); },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () { HapticService.instance.selection(); _showOptions(context); },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: imageUrl,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}