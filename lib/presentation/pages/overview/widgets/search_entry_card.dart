import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../widgets/search_dialog.dart';

class SearchEntryCard extends StatelessWidget {
  const SearchEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => SearchDialog.show(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 22, color: theme.hintColor),
              const SizedBox(width: 12),
              Text(
                '搜索文件...',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
              ),
              const Spacer(),
              Icon(LucideIcons.arrowRight, size: 18, color: theme.hintColor.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
