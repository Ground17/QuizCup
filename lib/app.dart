import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'presentation/router/app_router.dart';

class QrophyApp extends StatelessWidget {
  const QrophyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Qrophy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
