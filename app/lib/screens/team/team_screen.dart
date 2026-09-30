import 'package:flutter/material.dart';

import '../../widgets/page_header.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(김형철): 팀 화면 구현 (설계서 12, A34 A36 A37)
    return const Scaffold(
      body: SafeArea(child: PageHeader(title: '팀')),
    );
  }
}
