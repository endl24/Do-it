import 'package:flutter/material.dart';

import '../../widgets/page_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(김형철): 설정 화면 구현 (설계서 14, A38–A41)
    return const Scaffold(
      body: SafeArea(child: PageHeader(title: '설정')),
    );
  }
}
