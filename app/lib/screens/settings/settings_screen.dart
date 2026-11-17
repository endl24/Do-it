import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../services/account_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_retry_card.dart';
import '../../widgets/page_header.dart';
import '../notification_settings/notification_settings.dart';
import '../notification_settings/notification_settings_screen.dart';
import '../photo_import/permission_guide_screen.dart';
import 'widgets/settings_content.dart';

/// 14 설정 화면. 닉네임, 알림·권한·동기화 상태, 계정 연동·로그아웃·회원 탈퇴를 한곳에서 다룬다.
///
/// 저장과 계정 요청은 부르는 쪽 콜백에 맡긴다. 요청 중에는 다른 동작과 뒤로 가기를 막는다.
class SettingsScreen extends StatefulWidget {
  /// 닉네임·계정 연동 상태·동기화 대기 수·알림 설정과 저장·계정 동작 콜백으로 설정 화면을 만든다. 대기 수는 0 이상이어야 한다.
  const SettingsScreen({
    super.key,
    this.nickname = '사용자',
    this.isLinked = false,
    this.accountEmail,
    this.pendingCount = 0,
    this.notifications = const NotificationSettings(),
    this.permissionService,
    this.onSaveNickname,
    this.onNotificationsChanged,
    this.onLinkAccount,
    this.onAuthenticate,
    this.onLogout,
    this.onDeleteAccount,
  }) : assert(pendingCount >= 0);
  final String nickname;
  final bool isLinked;
  final String? accountEmail;
  final int pendingCount;
  final NotificationSettings notifications;
  final PermissionService? permissionService;
  final Future<void> Function(String)? onSaveNickname;
  final ValueChanged<NotificationSettings>? onNotificationsChanged;
  final Future<void> Function()? onLinkAccount;
  final Future<bool> Function()? onAuthenticate;
  final Future<void> Function()? onLogout;
  final Future<void> Function()? onDeleteAccount;

  /// 입력 중인 닉네임과 요청 진행 여부를 관리할 상태를 만든다.
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// 입력 중인 닉네임과 마지막으로 저장한 닉네임, 계정 연동·알림 설정, 요청 진행 여부·오류와 다시 시도할 동작, 권한 상태 문구를 들고 있는 상태.
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

  /// 닉네임이 비어 있지 않고 한글·영문·숫자로만 12자 이내인지 검증한 결과를 돌려준다.
  bool get _isValidName =>
      _name.text.isNotEmpty &&
      _name.text.characters.length <= 12 &&
      RegExp(r'^[가-힣a-zA-Z0-9]+$').hasMatch(_name.text);

  /// 닉네임 입력칸에서 포커스가 빠질 때 저장하도록 연결하고, 권한 상태를 처음 읽어 온다.
  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _readPermissions();
  }

  /// 부르는 쪽이 넘긴 닉네임·연동 여부·알림 설정이 바뀌면 화면 값도 맞춘다.
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

  /// 포커스 감시를 끊고 닉네임 입력 컨트롤러와 포커스를 정리한다.
  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _name.dispose();
    super.dispose();
  }

  /// 닉네임 입력칸에서 포커스가 빠지면 닉네임을 저장한다.
  void _onFocusChanged() {
    if (!_focus.hasFocus) _saveName();
  }

  /// 떠 있는 스낵바를 닫고 [text]를 새 스낵바로 띄운다.
  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// 카메라·사진과 알림 권한 상태를 읽어 '권한' 줄 문구를 만들고, 알림이 거부됐는지 기록한다. 읽지 못하면 실패 문구를 보여 준다.
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

  /// 바뀐 닉네임을 검증한 뒤 저장한다.
  ///
  /// 형식이 맞지 않으면 저장하지 않고 오류 문구를 보여 준다. 저장에 성공해야 저장한 닉네임을 바꾸고 알린다.
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

  /// 계정 요청 [action]을 실행하고, 성공하면 [success]로 화면을 바꾼다.
  ///
  /// 요청 중에는 다른 요청을 막는다. 실패하면 [AccountFailure]의 문구나 기본 오류 문구를 보여 주고, 같은 요청을 다시 시도할 수 있게 남겨 둔다. [action]이 없으면 계정 기능을 쓸 수 없다고 알린다.
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
    } on AccountFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '요청을 처리하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// 확인 대화상자를 거쳐 로그아웃하거나, [isDeleting]이면 회원 탈퇴한다.
  ///
  /// 로그아웃할 때 서버에 반영되지 않은 할 일이 있으면 그 건수를 대화상자에 알린다. 성공하면 연동 해제 상태로 바꾼다.
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

  /// 계정 연동을 진행하고, 연동되면 연동됨 상태로 바꿔 알린다.
  ///
  /// 실제 인증 화면([SettingsScreen.onAuthenticate])에서 취소하면 연동 성공으로 처리하지 않는다.
  /// 인증 화면이 없으면 기존 미리보기 콜백 [SettingsScreen.onLinkAccount]를 쓴다.
  Future<void> _linkAccount() async {
    var isAuthenticated = widget.onAuthenticate == null;
    await _run(
      widget.onAuthenticate == null
          ? widget.onLinkAccount
          : () async {
              isAuthenticated = await widget.onAuthenticate!();
            },
      () {
        if (!isAuthenticated) return;
        _isLinked = true;
        _message('계정을 연동했습니다');
      },
    );
  }

  /// 11 알림 설정 화면을 열어 바뀐 알림 설정을 화면과 부르는 쪽에 반영하고, 돌아오면 권한 상태를 다시 읽는다.
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

  /// 09 권한 안내 화면을 열고, 돌아오면 권한 상태를 다시 읽는다.
  ///
  /// 카메라 권한을 허용하면 바로 설정 화면으로 돌아온다. 권한 서비스가 없으면 안내 스낵바만 띄운다.
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

  /// 설정 머리글 아래에 요청 오류 재시도 카드와 설정 본문을 그리고, 요청 중에는 진행 막대를 보여 주며 뒤로 가기를 막는다.
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
                  // 로그아웃·탈퇴 같은 요청이라 자동으로 다시 보내지 않는다.
                  if (_error != null) ...[
                    ErrorRetryCard(
                      message: _error!,
                      onRetry: _isBusy ? null : _retry,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  SettingsContent(
                    name: _savedName,
                    controller: _name,
                    focus: _focus,
                    isBusy: _isBusy,
                    isLinked: _isLinked,
                    accountEmail: widget.accountEmail,
                    pendingCount: widget.pendingCount,
                    notifications: _notifications,
                    permissions: _permissions,
                    onNameChanged: (_) => setState(() => _error = null),
                    onNotifications: _isBusy ? null : _openNotifications,
                    onPermissions: _isBusy ? null : _openPermissions,
                    onLink: _isBusy || _isLinked ? null : _linkAccount,
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
