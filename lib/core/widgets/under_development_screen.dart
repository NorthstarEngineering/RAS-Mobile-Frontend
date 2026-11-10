import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class UnderDevelopmentScreen extends StatelessWidget {
  const UnderDevelopmentScreen({super.key, required this.feature});

  final String feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('قيد التطوير')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$feature\n\nهذه الوظيفة ستظهر بعد ربط خدمة النظام الفعلية.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd,
          ),
        ),
      ),
    );
  }
}
