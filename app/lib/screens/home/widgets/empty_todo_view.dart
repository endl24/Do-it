import 'package:flutter/material.dart';

class EmptyTodoView extends StatelessWidget {
  const EmptyTodoView({required this.onAdd, required this.onPhoto, super.key});

  final VoidCallback onAdd;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 156,
            height: 156,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5DCC8)),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              size: 62,
              color: Color(0xFFC8BB8D),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '아직 등록한 할 일이 없어요',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '직접 입력하거나, 종이에 적어둔 메모를\n사진으로 찍어 한 번에 옮겨올 수 있습니다.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: const Color(0xFF77736A), height: 1.55),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('할 일 직접 추가'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: onPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('사진에서 가져오기'),
            ),
          ),
        ],
      ),
    );
  }
}
