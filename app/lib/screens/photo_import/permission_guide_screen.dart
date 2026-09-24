import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/permission_service.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/notice_box.dart';

/// 09 권한 안내 (A18 A32 · B6 B11)
///
/// 01 할 일 목록에서 06 메모 촬영으로 가려는데 카메라·사진 권한이 없을 때 push한다.
/// 권한을 허용하면 [onCameraGranted]로 06에 넘어가고, [나중에 하기]는 01로 돌아간다.
/// 권한을 거부해도 앱을 종료하지 않고 이 화면에 남는다(B6).
class PermissionGuideScreen extends StatefulWidget {
  const PermissionGuideScreen({
    super.key,
    required this.permissionService,
    required this.onCameraGranted,
  });

  final PermissionService permissionService;

  /// 카메라·사진 권한을 얻었을 때 06 메모 촬영으로 넘어간다.
  // TODO(강두이): 06 메모 촬영 화면이 생기면 여기서 바로 pushReplacement한다.
  final VoidCallback onCameraGranted;

  @override
  State<PermissionGuideScreen> createState() => _PermissionGuideScreenState();
}

class _PermissionGuideScreenState extends State<PermissionGuideScreen> {
  static const _cameraDeniedMessage =
      '사진으로 등록하려면 카메라와 사진 접근이 필요합니다. 권한을 허용하거나 직접 입력으로 등록해 주세요.';

  late final AppLifecycleListener _lifecycleListener;
  AppPermissionStatus? _cameraStatus;
  AppPermissionStatus? _notificationStatus;

  PermissionService get _service => widget.permissionService;

  @override
  void initState() {
    super.initState();
    // 설정 화면에서 권한을 켜고 돌아오면 상태를 다시 읽는다.
    _lifecycleListener = AppLifecycleListener(onResume: _loadStatuses);
    _loadStatuses();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    final camera = await _service.cameraStatus();
    final notification = await _service.notificationStatus();
    if (!mounted) return;
    setState(() {
      _cameraStatus = camera;
      _notificationStatus = notification;
    });
  }

  Future<void> _requestCamera() async {
    final status = await _service.requestCamera();
    if (!mounted) return;
    setState(() => _cameraStatus = status);
    if (status == AppPermissionStatus.granted) {
      widget.onCameraGranted();
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(_cameraDeniedMessage)));
    }
  }

  Future<void> _requestNotification() async {
    final status = await _service.requestNotification();
    if (!mounted) return;
    setState(() => _notificationStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    final cameraStatus = _cameraStatus;
    final notificationStatus = _notificationStatus;

    return Scaffold(
      appBar: AppBar(leading: const CloseButton(), title: const Text('권한 안내')),
      body: cameraStatus == null || notificationStatus == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.xs,
                AppSpacing.screenHorizontal,
                AppSpacing.md,
              ),
              children: [
                Text(
                  '이 기능에는\n권한이 필요합니다',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _CameraCard(
                  status: cameraStatus,
                  onRequest: _requestCamera,
                  onOpenSettings: _service.openAppSettings,
                  onContinue: widget.onCameraGranted,
                ),
                const SizedBox(height: AppSpacing.sm),
                _NotificationCard(
                  status: notificationStatus,
                  onRequest: _requestNotification,
                  onOpenSettings: _service.openAppSettings,
                ),
                const SizedBox(height: AppSpacing.sm),
                const NoticeBox(
                  message: '권한을 거부해도 직접 입력으로 할 일을 등록하고 관리할 수 있습니다.',
                ),
              ],
            ),
      bottomNavigationBar: BottomActionBar(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('나중에 하기'),
          ),
        ],
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.status,
    required this.onRequest,
    required this.onOpenSettings,
    required this.onContinue,
  });

  final AppPermissionStatus status;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _PermissionCard(
      icon: Icons.camera_alt_outlined,
      iconColor: AppColors.primary,
      iconBackground: AppColors.primaryContainer,
      title: '카메라 · 사진',
      description: '종이 메모를 찍어 할 일로 옮기는 데 사용합니다',
      children: [
        switch (status) {
          AppPermissionStatus.granted => const _StatusLine.granted(
            '허용됨 — 메모를 찍어 등록할 수 있습니다',
          ),
          AppPermissionStatus.denied || AppPermissionStatus.permanentlyDenied =>
            const _StatusLine.denied('현재 거부됨 — 사진으로 등록할 수 없습니다'),
          AppPermissionStatus.notDetermined => const _PrivacyNote(),
        },
        const SizedBox(height: AppSpacing.md),
        switch (status) {
          AppPermissionStatus.granted => FilledButton(
            onPressed: onContinue,
            child: const Text('메모 촬영하기'),
          ),
          AppPermissionStatus.permanentlyDenied => FilledButton(
            onPressed: onOpenSettings,
            child: const Text('설정에서 권한 켜기'),
          ),
          _ => FilledButton(onPressed: onRequest, child: const Text('권한 허용하기')),
        },
        if (status == AppPermissionStatus.permanentlyDenied)
          const _SettingsPath('설정 > 앱 > Do it 에서 카메라와 사진 접근을 켤 수 있습니다.'),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.status,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final AppPermissionStatus status;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isDenied =
        status == AppPermissionStatus.denied ||
        status == AppPermissionStatus.permanentlyDenied;

    return _PermissionCard(
      icon: Icons.notifications_none,
      iconColor: AppColors.warning,
      iconBackground: AppColors.warningContainer,
      title: '알림',
      description: '마감 알림과 반복 알림을 받는 데 사용합니다',
      children: [
        switch (status) {
          AppPermissionStatus.granted => const _StatusLine.granted(
            '허용됨 — 마감 알림을 받습니다',
          ),
          AppPermissionStatus.notDetermined => OutlinedButton(
            onPressed: onRequest,
            child: const Text('알림 허용하기'),
          ),
          _ => const _StatusLine.denied('현재 거부됨 — 알림이 오지 않습니다'),
        },
        if (isDenied) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onOpenSettings,
            child: const Text('설정에서 알림 켜기'),
          ),
          const _SettingsPath('설정 > 앱 > Do it > 알림 에서 언제든 다시 켤 수 있습니다.'),
        ],
      ],
    );
  }
}

/// 아이콘·제목·설명 아래에 상태와 버튼을 담는 카드.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.children,
  });

  static const _iconBoxSize = 44.0;

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: _iconBoxSize,
                  height: _iconBoxSize,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, size: AppSize.iconSm, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.itemTitle.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 사진을 외부로 보내지 않는다는 안내(B11).
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '촬영한 사진은 단말 안에서만 처리되고 외부로 전송되지 않으며, 등록이 끝나면 삭제됩니다.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLabel),
      ),
    );
  }
}

/// 점과 짧은 문구로 권한 상태를 보여주는 줄. 예) `● 현재 거부됨 — 알림이 오지 않습니다`
class _StatusLine extends StatelessWidget {
  const _StatusLine.granted(this.text) : isDenied = false;

  const _StatusLine.denied(this.text) : isDenied = true;

  final String text;
  final bool isDenied;

  @override
  Widget build(BuildContext context) {
    final color = isDenied
        ? AppColors.dangerText
        : AppColors.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDenied
            ? AppColors.dangerContainer
            : AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDenied ? AppColors.dangerBorder : AppColors.primaryContainer,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: AppSize.statusDot,
            height: AppSize.statusDot,
            decoration: BoxDecoration(
              color: isDenied ? AppColors.danger : AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(text, style: AppTextStyles.chip.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _SettingsPath extends StatelessWidget {
  const _SettingsPath(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
