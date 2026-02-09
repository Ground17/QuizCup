import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'presentation/router/app_router.dart';

class QuizCupApp extends StatelessWidget {
  const QuizCupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'QuizCup',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
