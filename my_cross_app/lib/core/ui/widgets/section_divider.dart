import 'package:flutter/material.dart';

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, this.height = 24});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
