import 'package:flutter/material.dart';

import '../../widgets/page_header.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(김형철): 일정 화면 구현 (설계서 10, A12 A13)
    return const Scaffold(
      body: SafeArea(child: PageHeader(title: '일정')),
    );
  }
}
