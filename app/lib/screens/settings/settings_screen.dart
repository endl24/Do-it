import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../services/permission_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/notice_box.dart';
import '../../widgets/page_header.dart';
import '../notification_settings/notification_settings.dart';
import '../notification_settings/notification_settings_screen.dart';
import '../photo_import/permission_guide_screen.dart';
import 'widgets/settings_content.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.nickname = '사용자',
    this.isLinked = false,
    this.pendingCount = 0,
    this.notifications = const NotificationSettings(),
    this.permissionService,
    this.onSaveNickname,
    this.onNotificationsChanged,
    this.onLinkAccount,
    this.onLogout,
    this.onDeleteAccount,
  }) : assert(pendingCount >= 0);
  final String nickname;
  final bool isLinked;
  final int pendingCount;
  final NotificationSettings notifications;
  final PermissionService? permissionService;
  final Future<void> Function(String)? onSaveNickname;
  final ValueChanged<NotificationSettings>? onNotificationsChanged;
  final Future<void> Function()? onLinkAccount;
  final Future<void> Function()? onLogout;
  final Future<void> Function()? onDeleteAccount;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _name = TextEditingController(text: widget.nickname);
  final _focus = FocusNode();
  late String _savedName = widget.nickname;
  late bool _isLinked = widget.isLinked;
  late NotificationSettings _notifications = widget.notifications;
  bool _isBusy = false;
  String? _error;
  Future<void> Function()? _retry;
  String _permissions = '권한 상태 확인 필요';
  bool _isNotificationDenied = false;
  bool get _isValidName =>
      _name.text.isNotEmpty &&
      _name.text.characters.length <= 12 &&
      RegExp(r'^[가-힣a-zA-Z0-9]+$').hasMatch(_name.text);
  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _readPermissions();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nickname != widget.nickname) {
      _savedName = widget.nickname;
      _name.text = widget.nickname;
    }
    if (oldWidget.isLinked != widget.isLinked) _isLinked = widget.isLinked;
    if (oldWidget.notifications != widget.notifications) {
      _notifications = widget.notifications;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _name.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _saveName();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _readPermissions() async {
    final service = widget.permissionService;
    if (service == null) return;
    try {
      final camera = await service.cameraStatus();
      final notification = await service.notificationStatus();
      if (!mounted) return;
      setState(() {
        _permissions =
            '카메라·사진 ${camera == AppPermissionStatus.granted ? '허용' : '미허용'} · 알림 ${notification == AppPermissionStatus.granted ? '허용' : '미허용'}';
        _isNotificationDenied = notification != AppPermissionStatus.granted;
      });
    } catch (_) {
      if (mounted) setState(() => _permissions = '권한 확인 실패 · 다시 시도');
    }
  }

  Future<void> _saveName() async {
    if (_isBusy || _name.text == _savedName) return;
    if (!_isValidName) {
      _retry = _saveName;
      setState(() => _error = '닉네임은 한글·영문·숫자 12자까지 쓸 수 있습니다');
      return;
    }
    final value = _name.text;
    await _run(
      widget.onSaveNickname == null
          ? null
          : () => widget.onSaveNickname!(value),
      () {
        _savedName = value;
        _message('닉네임을 변경했습니다');
      },
    );
  }

  Future<void> _run(
    Future<void> Function()? action,
    VoidCallback success,
  ) async {
    if (_isBusy) return;
    _retry = () => _run(action, success);
    if (action == null) {
      setState(() => _error = '현재 계정 기능을 사용할 수 없습니다. 연결 후 다시 시도해 주세요.');
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(success);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '요청을 처리하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _accountAction({required bool isDeleting}) async {
    if (_isBusy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: isDeleting ? '회원 탈퇴할까요?' : '로그아웃할까요?',
      message: isDeleting
          ? '계정과 계정에 연결된 할 일이 모두 삭제됩니다. 회원 탈퇴는 되돌릴 수 없습니다.'
          : widget.pendingCount > 0
          ? '아직 서버에 반영되지 않은 할 일이 ${widget.pendingCount}건 있습니다. 그래도 로그아웃할까요?'
          : '연동된 계정에서 로그아웃합니다.',
      confirmLabel: isDeleting ? '회원 탈퇴' : '로그아웃',
      isDestructive: true,
    );
    if (!mounted || !confirmed) return;
    await _run(isDeleting ? widget.onDeleteAccount : widget.onLogout, () {
      _isLinked = false;
      _message(isDeleting ? '회원 탈퇴했습니다' : '로그아웃했습니다');
    });
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationSettingsScreen(
          initialSettings: _notifications,
          isPermissionDenied: _isNotificationDenied,
          onOpenSystemSettings: widget.permissionService == null
              ? null
              : () async {
                  try {
                    await widget.permissionService!.openAppSettings();
                  } catch (_) {
                    if (mounted) _message('설정을 열지 못했습니다. 다시 시도해 주세요.');
                  }
                },
          onChanged: (value) {
            setState(() => _notifications = value);
            widget.onNotificationsChanged?.call(value);
          },
        ),
      ),
    );
    if (mounted) await _readPermissions();
  }

  Future<void> _openPermissions() async {
    final service = widget.permissionService;
    if (service == null) {
      _message('권한 서비스가 연결되지 않았습니다. 연결 후 다시 시도해 주세요.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => PermissionGuideScreen(
          permissionService: service,
          onCameraGranted: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    if (mounted) await _readPermissions();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isBusy,
    child: Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const PageHeader(title: '설정'),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Column(
                children: [
                  if (_error != null) ...[
                    NoticeBox.error(message: _error!),
                    TextButton(
                      onPressed: _isBusy ? null : _retry,
                      child: const Text('다시 시도'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  SettingsContent(
                    name: _savedName,
                    controller: _name,
                    focus: _focus,
                    isBusy: _isBusy,
                    isLinked: _isLinked,
                    pendingCount: widget.pendingCount,
                    notifications: _notifications,
                    permissions: _permissions,
                    onNameChanged: (_) => setState(() => _error = null),
                    onNotifications: _isBusy ? null : _openNotifications,
                    onPermissions: _isBusy ? null : _openPermissions,
                    onLink: _isBusy || _isLinked
                        ? null
                        : () => _run(widget.onLinkAccount, () {
                            _isLinked = true;
                            _message('계정을 연동했습니다');
                          }),
                    onLogout: _isBusy || !_isLinked
                        ? null
                        : () => _accountAction(isDeleting: false),
                    onDelete: _isBusy || !_isLinked
                        ? null
                        : () => _accountAction(isDeleting: true),
                  ),
                  if (_isBusy)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: LinearProgressIndicator(semanticsLabel: '처리 중'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
