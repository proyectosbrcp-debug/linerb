import 'package:flutter/material.dart';

import '../core/theme/ui_constants.dart';

class LinerbLoadingState extends StatelessWidget {
  final String message;

  const LinerbLoadingState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LinerbSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: LinerbSpacing.md),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
