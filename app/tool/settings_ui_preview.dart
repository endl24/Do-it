import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/settings/settings_screen.dart';
import 'package:do_it/services/permission_service.dart';
import 'package:flutter/material.dart';

void main() => runApp(const SettingsUiPreviewApp());

class SettingsUiPreviewApp extends StatelessWidget {
  const SettingsUiPreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => Banner(
      message: 'UI 미리보기',
      location: BannerLocation.topEnd,
      child: child!,
    ),
    home: Scaffold(
      body: SettingsScreen(
        nickname: '두이',
        isLinked: !const bool.fromEnvironment('SETTINGS_UI_UNLINKED'),
        pendingCount: 2,
        permissionService: PreviewPermissionService(),
        onSaveNickname: (_) async {
          if (const bool.fromEnvironment('SETTINGS_UI_FAIL')) throw Exception();
        },
        onLinkAccount: _request,
        onLogout: _request,
        onDeleteAccount: _request,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: '할 일'),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            label: '일정',
          ),
          NavigationDestination(icon: Icon(Icons.group_outlined), label: '팀'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '설정',
          ),
        ],
      ),
    ),
  );
  static Future<void> _request() async {
    if (const bool.fromEnvironment('SETTINGS_UI_FAIL')) throw Exception();
  }
}

class PreviewPermissionService implements PermissionService {
  AppPermissionStatus _camera = AppPermissionStatus.denied;
  AppPermissionStatus _notification = AppPermissionStatus.denied;
  @override
  Future<AppPermissionStatus> cameraStatus() async => _camera;
  @override
  Future<AppPermissionStatus> notificationStatus() async => _notification;
  @override
  Future<AppPermissionStatus> requestCamera() async =>
      _camera = AppPermissionStatus.granted;
  @override
  Future<AppPermissionStatus> requestNotification() async =>
      _notification = AppPermissionStatus.granted;
  @override
  Future<void> openAppSettings() async {
    _camera = AppPermissionStatus.granted;
    _notification = AppPermissionStatus.granted;
  }
}
