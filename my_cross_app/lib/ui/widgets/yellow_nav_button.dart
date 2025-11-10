import 'package:flutter/material.dart';

class YellowNavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDisabled;
  final IconData icon;

  const YellowNavButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isDisabled = false,
    this.icon = Icons.arrow_forward,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = !isDisabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFFFFD84D), Color(0xFFFFB347)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFFFB347)
                  : theme.colorScheme.outlineVariant,
              width: enabled ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: enabled ? const Color(0xFF473200) : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                icon,
                size: 20,
                color: enabled ? const Color(0xFF473200) : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
