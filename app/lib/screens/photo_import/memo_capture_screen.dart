import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/memo_scanner.dart';
import '../../services/permission_service.dart';
import '../../widgets/confirm_dialog.dart';
import 'candidate_review_screen.dart';
import 'permission_guide_screen.dart';
import 'recognition_failure_screen.dart';
import 'todo_candidate.dart';

/// 06 메모 촬영 · 인식 중 (A14 A15 A19 · B2 B6 B11 · C3 C8)
///
/// [MemoCaptureScreen.open]으로 연다. 촬영하거나 앨범에서 한 장을 고르면 단말에서 글자를 읽고,
/// 읽은 줄이 있으면 07 후보 검토, 없으면 08 인식 실패를 이 화면 위에 push한다.
/// 촬영본은 07·08이 화면을 벗어날 때 삭제한다(A19).
class MemoCaptureScreen extends StatefulWidget {
  const MemoCaptureScreen({
    super.key,
    required this.scanner,
    required this.onManualEntry,
    required this.onRegister,
  });

  final MemoScanner scanner;

  /// [직접 입력]을 눌렀을 때 03 할 일 등록으로 넘어간다.
  // TODO(강두이): 03 할 일 등록 화면이 생기면 여기서 바로 push한다.
  final VoidCallback onManualEntry;

  /// 07 후보 검토에서 고른 제목들을 할 일로 저장한다.
  final Future<void> Function(List<String> titles) onRegister;

  /// 카메라·사진 권한이 있으면 06을, 없으면 09 권한 안내를 연다(A18).
  /// 09에서 권한을 허용하면 09를 06으로 바꾼다.
  static Future<void> open(
    BuildContext context, {
    required PermissionService permissionService,
    required MemoScanner scanner,
    required VoidCallback onManualEntry,
    required Future<void> Function(List<String> titles) onRegister,
  }) async {
    final navigator = Navigator.of(context);
    Widget buildCapture() => MemoCaptureScreen(
      scanner: scanner,
      onManualEntry: onManualEntry,
      onRegister: onRegister,
    );

    final status = await permissionService.cameraStatus();
    if (status == AppPermissionStatus.granted) {
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => buildCapture()),
      );
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => PermissionGuideScreen(
          permissionService: permissionService,
          onCameraGranted: () => navigator.pushReplacement(
            MaterialPageRoute<void>(builder: (_) => buildCapture()),
          ),
        ),
      ),
    );
  }

  @override
  State<MemoCaptureScreen> createState() => _MemoCaptureScreenState();
}

class _MemoCaptureScreenState extends State<MemoCaptureScreen> {
  static const _multiplePhotosMessage =
      '한 번에 한 장만 인식할 수 있습니다. 사진을 하나만 선택해 주세요.';
  static const _unsupportedMessage =
      '이 기기에서는 사진 인식을 사용할 수 없습니다. 직접 입력으로 할 일을 등록해 주세요.';

  MemoScanner get _scanner => widget.scanner;

  bool _isCameraReady = false;
  bool _isRecognizing = false;

  /// 연속으로 인식에 실패한 횟수. 08에 넘겨 직접 입력을 권할지 정한다(B10).
  int _failureCount = 0;

  @override
  void initState() {
    super.initState();
    if (_scanner.isRecognitionSupported) {
      _startCamera();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showUnsupported());
    }
  }

  @override
  void dispose() {
    _scanner.stopCamera().ignore();
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      await _scanner.startCamera();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (error) {
      debugPrint('카메라 시작 실패: $error');
    }
  }

  Future<void> _showUnsupported() async {
    final isManualEntry = await showConfirmDialog(
      context,
      title: '사진 인식을 쓸 수 없어요',
      message: _unsupportedMessage,
      confirmLabel: '직접 입력',
      cancelLabel: '닫기',
    );
    if (!mounted) return;
    if (isManualEntry) {
      widget.onManualEntry();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _takePicture() async {
    // 촬영이 끝나기 전에 셔터를 또 누르지 못하게 바로 인식 중으로 표시한다.
    setState(() => _isRecognizing = true);
    final File image;
    try {
      image = await _scanner.takePicture();
    } catch (error) {
      debugPrint('촬영 실패: $error');
      if (mounted) setState(() => _isRecognizing = false);
      _showMessage('촬영하지 못했어요. 다시 시도해 주세요.');
      return;
    }
    await _recognize(image);
  }

  Future<void> _pickFromAlbum() async {
    final images = await _scanner.pickFromAlbum();
    // 선택을 취소하면 아무 일 없이 촬영 화면에 남는다(B6).
    if (images.isEmpty) return;
    if (images.length > 1) {
      for (final image in images) {
        image.delete().ignore();
      }
      _showMessage(_multiplePhotosMessage);
      return;
    }
    await _recognize(images.single);
  }

  Future<void> _recognize(File image) async {
    setState(() => _isRecognizing = true);
    List<String> lines;
    try {
      lines = await _scanner.recognizeLines(image);
    } catch (error) {
      debugPrint('글자 인식 실패: $error');
      lines = const [];
    }
    if (!mounted) {
      image.delete().ignore();
      return;
    }
    setState(() => _isRecognizing = false);

    final candidates = candidatesFromLines(lines);
    _failureCount = candidates.isEmpty ? _failureCount + 1 : 0;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => candidates.isEmpty
            ? RecognitionFailureScreen(
                failureCount: _failureCount,
                imageFile: image,
                onManualEntry: widget.onManualEntry,
              )
            : CandidateReviewScreen(
                candidates: candidates,
                imageFile: image,
                onRegister: widget.onRegister,
              ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final canCapture = _isCameraReady && !_isRecognizing;

    return Scaffold(
      backgroundColor: AppColors.cameraBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cameraBackground,
        foregroundColor: AppColors.surface,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTextStyles.appBarTitle.copyWith(
          color: AppColors.surface,
        ),
        leading: const CloseButton(),
        title: const Text('메모 촬영'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _Viewfinder(
                preview: _isCameraReady ? _scanner.buildCameraPreview() : null,
                isRecognizing: _isRecognizing,
              ),
            ),
            _CaptureControls(
              onAlbum: _isRecognizing ? null : _pickFromAlbum,
              onShutter: canCapture ? _takePicture : null,
              onManualEntry: _isRecognizing ? null : widget.onManualEntry,
            ),
          ],
        ),
      ),
    );
  }
}

/// 카메라 미리보기, 한 장 안내, 안내선, 인식 중 표시를 겹쳐 그린다.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.preview, required this.isRecognizing});

  final Widget? preview;
  final bool isRecognizing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cameraSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ?preview,
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                const _DarkNotice(
                  message: '한 번에 한 장만 인식합니다. 글자가 안내선 안에 들어오게 맞춰 주세요.',
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.surface.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isRecognizing)
            const Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _RecognizingCard(),
            ),
        ],
      ),
    );
  }
}

class _DarkNotice extends StatelessWidget {
  const _DarkNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cameraBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 16, color: AppColors.surface),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.surface),
            ),
          ),
        ],
      ),
    );
  }
}

/// 인식 중 표시. 사진을 외부로 보내지 않는다는 안내를 함께 보여준다(B11 C3).
class _RecognizingCard extends StatelessWidget {
  const _RecognizingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: AppSize.iconMd + AppSpacing.xs,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceTrack,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '텍스트 인식 중...',
                  style: AppTextStyles.itemTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '단말에서 처리하며 이미지는 외부로 전송되지 않습니다',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureControls extends StatelessWidget {
  const _CaptureControls({
    required this.onAlbum,
    required this.onShutter,
    required this.onManualEntry,
  });

  final VoidCallback? onAlbum;
  final VoidCallback? onShutter;
  final VoidCallback? onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SideButton(
            icon: Icons.image_outlined,
            label: '앨범',
            onPressed: onAlbum,
          ),
          _ShutterButton(onPressed: onShutter),
          _SideButton(
            icon: Icons.edit_outlined,
            label: '직접 입력',
            onPressed: onManualEntry,
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  static const _size = 60.0;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? AppColors.textTertiary
        : AppColors.surface;

    return Material(
      color: AppColors.cameraSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.surface.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppSize.iconSm, color: color),
              const SizedBox(height: AppSpacing.xxs),
              Text(label, style: AppTextStyles.navLabel.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});

  static const _outerSize = 84.0;
  static const _innerSize = 64.0;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: '촬영',
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: isEnabled ? 1 : 0.4,
          child: Container(
            width: _outerSize,
            height: _outerSize,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Container(
              width: _innerSize,
              height: _innerSize,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cameraBackground, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
