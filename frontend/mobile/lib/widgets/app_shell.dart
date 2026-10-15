import 'package:flutter/material.dart';

class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const PageBody({super.key, required this.child, this.maxWidth = 960});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class AppNavigation extends StatelessWidget {
  final int index;

  const AppNavigation({super.key, required this.index});

  static const routes = ['/home', '/transactions', '/relationships', '/analytics'];

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index,
    onDestinationSelected: (selected) {
      if (selected != index) {
        Navigator.pushReplacementNamed(context, routes[selected]);
      }
    },
    destinations: const [
      NavigationDestination(
        key: ValueKey('nav-home'),
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: '홈',
      ),
      NavigationDestination(
        key: ValueKey('nav-records'),
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history_rounded),
        label: '기록',
      ),
      NavigationDestination(
        key: ValueKey('nav-people'),
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: '사람',
      ),
      NavigationDestination(
        key: ValueKey('nav-review'),
        icon: Icon(Icons.insights_outlined),
        selectedIcon: Icon(Icons.insights),
        label: '돌아보기',
      ),
    ],
  );
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}

class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.cloud_off_outlined,
    title: '기록을 불러오지 못했어요',
    message: message,
    actionLabel: '다시 불러오기',
    onAction: onRetry,
  );
}
