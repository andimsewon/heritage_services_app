import 'package:flutter/material.dart';


class AttachTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const AttachTile({super.key, required this.icon, required this.label});


  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label 기능은 목업입니다.'))),
      child: Container(
        width: 150,
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}