import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  StatefulShellRoute(
    builder: (context, state, navigationShell) {
      return Container(child: navigationShell);
    },
    navigatorContainerBuilder: (context, navigationShell, children) {
      return Stack(children: children);
    },
    branches: [
      StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, __) => Container())]),
    ],
  );
}
