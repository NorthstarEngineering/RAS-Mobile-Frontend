import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

class RmsOpsDestination {
  const RmsOpsDestination(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

class RmsOpsScaffold extends StatelessWidget {
  const RmsOpsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.destinations = const [],
    this.selectedIndex = 0,
    this.showProfile = true,
  });

  final String title;
  final List<Widget> children;
  final List<RmsOpsDestination> destinations;
  final int selectedIndex;
  final bool showProfile;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: Text(title),
      leading: _buildLeading(context),
      actions: showProfile
          ? [const Icon(Icons.person_outline), const SizedBox(width: 16)]
          : null,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
    bottomNavigationBar: destinations.isEmpty
        ? null
        : _bottomNavigation(context),
  );

  Widget? _buildLeading(BuildContext context) {
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'رجوع',
        onPressed: () => nav.pop(),
      );
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      try {
        final uri = GoRouterState.of(context).uri.path;
        if (uri != '/home' && uri != '/login') {
          return IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'الرئيسية',
            onPressed: () => router.go('/home'),
          );
        }
      } catch (_) {}
    }
    return null;
  }

  Widget _bottomNavigation(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: (index) => context.go(destinations[index].path),
    destinations: destinations
        .map(
          (destination) => NavigationDestination(
            icon: Icon(destination.icon),
            label: destination.label,
          ),
        )
        .toList(),
  );
}

class RmsOpsSection extends StatelessWidget {
  const RmsOpsSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: AppColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, color: AppColors.primary, size: 20),
              if (icon != null) const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class RmsOpsMetric extends StatelessWidget {
  const RmsOpsMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Icon(icon, size: 19, color: color ?? AppColors.primary),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.onSurface,
          ),
        ),
      ],
    ),
  );
}

class RmsOpsStatus extends StatelessWidget {
  const RmsOpsStatus(this.label, {super.key, this.color = AppColors.primary});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: AppTypography.labelSm.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class RmsOpsRecord extends StatelessWidget {
  const RmsOpsRecord({
    super.key,
    required this.title,
    required this.subtitle,
    this.status,
    this.details = const [],
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final Widget? status;
  final List<Widget> details;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ?status,
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
        ),
        if (details.isNotEmpty) ...[const Divider(height: 18), ...details],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: actions),
        ],
      ],
    ),
  );
}

class RmsOpsBanner extends StatelessWidget {
  const RmsOpsBanner({
    super.key,
    required this.title,
    required this.message,
    this.color = AppColors.primaryFixed,
  });

  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(message, style: AppTypography.bodySm),
      ],
    ),
  );
}
