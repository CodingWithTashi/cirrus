import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';

/// Shared step body: horizontal padding + optional title/subtitle header.
class StepBody extends StatelessWidget {
  const StepBody({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 24),
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: LpType.title(lp.textPrimary)),
            SizedBox(height: subtitle != null ? 10 : 26),
          ],
          if (subtitle != null) ...[
            Text(subtitle!, style: LpType.body14(lp.textSecondary)),
            const SizedBox(height: 26),
          ],
          ...children,
        ],
      ),
    );
  }
}
