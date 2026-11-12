import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/main/main_screen.dart';

/// Do-it 앱의 최상위 위젯. 공통 테마를 입히고 하단 탭 화면([MainScreen])을 첫 화면으로 띄운다.
class DoItApp extends StatelessWidget {
  /// 앱 위젯을 만든다.
  const DoItApp({super.key});

  /// 앱 이름과 밝은 테마로 [MaterialApp]을 구성한다.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Do-it',
      theme: AppTheme.light,
      home: const MainScreen(),
    );
  }
}
