import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/main/main_screen.dart';

class DoItApp extends StatelessWidget {
  const DoItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Do-it',
      theme: AppTheme.light,
      home: const MainScreen(),
    );
  }
}
