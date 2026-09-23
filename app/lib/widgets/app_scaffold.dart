import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'bottom_nav.dart';

final class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.selectedTabIndex,
    required this.onDestinationSelected,
    required this.appBar,
    required this.body,
    super.key,
  });

  final int selectedTabIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SafeArea(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(theme.appBar.height),
          child: appBar,
        ),
        body: body,
        bottomNavigationBar: BottomNav(
          selectedTabIndex: selectedTabIndex,
          onDestinationSelected: onDestinationSelected,
        ),
      ),
    );
  }
}
