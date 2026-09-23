import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MolduraResponsiva extends StatelessWidget {
  const MolduraResponsiva({super.key, required this.child, this.maxWidth = 400});

  final Widget child;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: AppColors.borderStrong(context),
                  width: 0.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
