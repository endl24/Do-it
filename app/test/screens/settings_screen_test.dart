import 'dart:async';

import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/notification_settings/notification_settings_screen.dart';
import 'package:do_it/screens/photo_import/permission_guide_screen.dart';
import 'package:do_it/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/settings_ui_preview.dart';

Future<void> _pump(WidgetTester tester, SettingsScreen screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _edit(WidgetTester tester, String value) async {
  final field = find.byKey(const ValueKey('nickname-input'));
  await tester.tap(field);
  await tester.enterText(field, value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('미리보기에서 저장·로그아웃·재연동·탈퇴를 확인한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SettingsUiPreviewApp());
    await tester.pumpAndSettle();
    await _edit(tester, '미리보기');
    expect(find.text('닉네임을 변경했습니다'), findsOneWidget);
    await _tap(tester, '로그아웃');
    await _tap(tester, '로그아웃');
    expect(find.text('계정이 연동되지 않았습니다'), findsOneWidget);
    await _tap(tester, '연동하기');
    expect(find.text('연동됨'), findsOneWidget);
    await _tap(tester, '회원 탈퇴');
    await _tap(tester, '회원 탈퇴');
    expect(find.text('회원 탈퇴했습니다'), findsOneWidget);
    expect(find.text('실행 취소'), findsNothing);
    expect(tester.takeException(), null);
  });
  testWidgets('작은 화면에서도 긴 이름과 권한 설명이 잘리지 않는다', (tester) async {
    await _pump(
      tester,
      SettingsScreen(
        nickname: '가나다라마바사아자차카타',
        permissionService: PreviewPermissionService(),
      ),
    );
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });
  testWidgets('닉네임과 계정·동기화·알림 요약을 표시한다', (tester) async {
    await _pump(
      tester,
      const SettingsScreen(nickname: '두이', isLinked: true, pendingCount: 2),
    );
    expect(find.text('2 / 12'), findsOneWidget);
    expect(find.text('연동된 계정으로 로그인됨'), findsOneWidget);
    expect(find.text('대기 2건'), findsOneWidget);
    expect(find.text('켜짐 · 오전 9:00'), findsOneWidget);
  });
  testWidgets('포커스 해제 시 이름을 저장하고 프로필을 갱신한다', (tester) async {
    String? saved;
    await _pump(
      tester,
      SettingsScreen(onSaveNickname: (name) async => saved = name),
    );
    await _edit(tester, '새이름12');
    expect(saved, '새이름12');
    expect(find.text('닉네임을 변경했습니다'), findsOneWidget);
  });
  testWidgets('기호·공백·빈 이름은 저장하지 않고 규칙을 안내한다', (tester) async {
    var calls = 0;
    await _pump(tester, SettingsScreen(onSaveNickname: (_) async => calls++));
    for (final value in ['이름!', '한 글', '']) {
      await _edit(tester, value);
      expect(find.text('닉네임은 한글·영문·숫자 12자까지 쓸 수 있습니다'), findsOneWidget);
    }
    expect(calls, 0);
  });
  testWidgets('닉네임 입력은 12자로 제한한다', (tester) async {
    await _pump(tester, const SettingsScreen());
    await tester.enterText(find.byType(TextField), '가' * 13);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byType(TextField))
          .controller!
          .text
          .characters
          .length,
      12,
    );
  });
  testWidgets('저장 실패 시 프로필을 유지하고 재시도한다', (tester) async {
    var attempts = 0;
    await _pump(
      tester,
      SettingsScreen(
        nickname: '기존',
        onSaveNickname: (_) async {
          if (++attempts == 1) throw Exception();
        },
      ),
    );
    await _edit(tester, '수정');
    expect(find.text('기존'), findsOneWidget);
    await _tap(tester, '다시 시도');
    expect(attempts, 2);
    expect(find.text('닉네임을 변경했습니다'), findsOneWidget);
  });
  testWidgets('저장 처리 중 입력을 막는다', (tester) async {
    final request = Completer<void>();
    await _pump(tester, SettingsScreen(onSaveNickname: (_) => request.future));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '새이름');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    request.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('11번에서 알림 변경 후 요약을 갱신한다', (tester) async {
    await _pump(tester, const SettingsScreen());
    await _tap(tester, '알림');
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    await _tap(tester, '알림 받기');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('꺼짐'), findsOneWidget);
  });
  testWidgets('09번 권한 안내를 열고 허용 후 상태를 갱신한다', (tester) async {
    await _pump(
      tester,
      SettingsScreen(permissionService: PreviewPermissionService()),
    );
    await _tap(tester, '권한');
    expect(find.byType(PermissionGuideScreen), findsOneWidget);
    await _tap(tester, '권한 허용하기');
    expect(find.byType(PermissionGuideScreen), findsNothing);
    expect(find.textContaining('카메라·사진 허용'), findsOneWidget);
  });
  testWidgets('로그아웃 경고의 실제 건수와 취소·확인을 처리한다', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      SettingsScreen(
        isLinked: true,
        pendingCount: 7,
        onLogout: () async => calls++,
      ),
    );
    await _tap(tester, '로그아웃');
    expect(find.textContaining('7건'), findsWidgets);
    await _tap(tester, '취소');
    expect(calls, 0);
    await _tap(tester, '로그아웃');
    await _tap(tester, '로그아웃');
    expect(calls, 1);
    expect(find.text('계정이 연동되지 않았습니다'), findsOneWidget);
  });
  testWidgets('회원 탈퇴는 삭제 범위를 안내하고 실행 취소를 제공하지 않는다', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      SettingsScreen(isLinked: true, onDeleteAccount: () async => calls++),
    );
    await _tap(tester, '회원 탈퇴');
    expect(find.textContaining('되돌릴 수 없습니다'), findsOneWidget);
    await _tap(tester, '회원 탈퇴');
    expect(calls, 1);
    expect(find.text('실행 취소'), findsNothing);
  });
  testWidgets('실패한 탈퇴는 계정 유지와 재시도 안내를 표시한다', (tester) async {
    await _pump(
      tester,
      SettingsScreen(
        isLinked: true,
        onDeleteAccount: () async => throw Exception(),
      ),
    );
    await _tap(tester, '회원 탈퇴');
    await _tap(tester, '회원 탈퇴');
    expect(find.text('연동된 계정으로 로그인됨'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });
  testWidgets('계정 연동 성공 및 미연결 이름 저장 실패를 구분한다', (tester) async {
    await _pump(tester, SettingsScreen(onLinkAccount: () async {}));
    await _tap(tester, '연동하기');
    expect(find.text('연동됨'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await _edit(tester, '변경');
    expect(find.textContaining('현재 계정 기능을 사용할 수 없습니다'), findsOneWidget);
  });
}
