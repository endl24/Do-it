import 'package:flutter/material.dart';

import '../../widgets/page_header.dart';

class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(고은재): 할 일 화면 구현 (설계서 01·02, A1 A2 A5 A6)
    return const Scaffold(
      body: SafeArea(child: PageHeader(title: '할 일')),
    );
  }
}
