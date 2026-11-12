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
  /// 글자 인식기 [scanner]와 직접 입력·등록 동작으로 촬영 화면을 만든다. 보통은 [MemoCaptureScreen.open]으로 연다.
  const MemoCaptureScreen({
    super.key,
    required this.scanner,
    required this.onManualEntry,
    required this.onRegister,
  });

  final MemoScanner scanner;

  /// [직접 입력]을 눌렀을 때 부른다. 부르는 쪽(01 할 일 목록)이 사진 흐름을 닫고 03 할 일 등록 시트를 연다.
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

  /// 카메라·인식 진행 상태를 관리할 상태를 만든다.
  @override
  State<MemoCaptureScreen> createState() => _MemoCaptureScreenState();
}

/// 카메라 준비, 인식 진행, 연속 실패 횟수를 들고 촬영·앨범 선택부터 07·08로 넘기기까지 맡는 상태.
class _MemoCaptureScreenState extends State<MemoCaptureScreen> {
  static const _multiplePhotosMessage =
      '한 번에 한 장만 인식할 수 있습니다. 사진을 하나만 선택해 주세요.';
  static const _unsupportedMessage =
      '이 기기에서는 사진 인식을 사용할 수 없습니다. 직접 입력으로 할 일을 등록해 주세요.';

  /// 위젯에서 받은 글자 인식기를 짧게 부르기 위한 이름.
  MemoScanner get _scanner => widget.scanner;

  bool _isCameraReady = false;
  bool _isRecognizing = false;

  /// 연속으로 인식에 실패한 횟수. 08에 넘겨 직접 입력을 권할지 정한다(B10).
  int _failureCount = 0;

  /// 사진 인식을 쓸 수 있는 기기면 카메라를 켜고, 아니면 첫 화면이 그려진 뒤 사용 불가 안내를 띄운다.
  @override
  void initState() {
    super.initState();
    if (_scanner.isRecognitionSupported) {
      _startCamera();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showUnsupported());
    }
  }

  /// 화면을 떠날 때 카메라를 끈다. 끄는 동안 기다리지 않는다.
  @override
  void dispose() {
    _scanner.stopCamera().ignore();
    super.dispose();
  }

  /// 카메라를 켜고, 준비되면 셔터를 누를 수 있게 한다.
  ///
  /// 켜지 못하면 기록만 남기고 셔터를 막아 둔 채 앨범과 직접 입력은 그대로 쓸 수 있게 한다.
  Future<void> _startCamera() async {
    try {
      await _scanner.startCamera();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (error) {
      debugPrint('카메라 시작 실패: $error');
    }
  }

  /// 이 기기에서 사진 인식을 쓸 수 없다고 알리고, [직접 입력]을 고르면 직접 입력으로, [닫기]를 고르면 이전 화면으로 보낸다.
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

  /// 사진을 찍어 글자 인식을 시작한다. 촬영에 실패하면 인식 중 표시를 풀고 다시 시도하라고 안내한다.
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

  /// 앨범에서 사진을 고르게 하고, 한 장이면 글자 인식을 시작한다.
  ///
  /// 여러 장을 골랐으면 받은 사진을 모두 지우고 한 장만 고르라고 안내한다.
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

  /// [image]에서 글자를 읽어 할 일 후보로 바꾸고, 후보가 있으면 07 후보 검토, 없으면 08 인식 실패를 띄운다.
  ///
  /// 인식 중 오류는 읽은 줄이 없는 것으로 보고 08로 보낸다. 후보가 없을 때마다 연속 실패 횟수를 늘리고,
  /// 후보가 나오면 0으로 되돌린다. 인식 중에 화면을 벗어났으면 사진을 바로 지운다(A19).
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

  /// 지금 떠 있는 스낵바를 닫고 [message]를 새 스낵바로 띄운다.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 어두운 촬영 화면에 미리보기와 아래 버튼 줄(앨범·셔터·직접 입력)을 그린다.
  ///
  /// 인식 중에는 모든 버튼을 막고, 셔터는 카메라가 준비됐을 때만 누를 수 있다.
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
  /// 카메라 미리보기 [preview](준비 전이면 `null`)와 인식 중 여부로 뷰파인더를 만든다.
  const _Viewfinder({required this.preview, required this.isRecognizing});

  final Widget? preview;
  final bool isRecognizing;

  /// 미리보기 위에 안내 문구와 안내선 테두리를 겹치고, 인식 중이면 아래쪽에 인식 중 카드를 띄운다.
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

/// 어두운 화면 위에 띄우는 반투명 안내 문구 박스.
class _DarkNotice extends StatelessWidget {
  /// 보여 줄 [message]로 안내 박스를 만든다.
  const _DarkNotice({required this.message});

  final String message;

  /// 정보 아이콘과 흰 글자를 반투명 어두운 배경 위에 그린다.
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
  /// 고정된 문구로 인식 중 카드를 만든다.
  const _RecognizingCard();

  /// 진행 표시와 인식 중 문구, 단말 처리 안내를 한 줄에 그린다.
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

/// 촬영 화면 아래의 앨범·셔터·직접 입력 버튼 줄. `null`을 받은 버튼은 누를 수 없다.
class _CaptureControls extends StatelessWidget {
  /// 세 버튼에서 실행할 동작으로 버튼 줄을 만든다.
  const _CaptureControls({
    required this.onAlbum,
    required this.onShutter,
    required this.onManualEntry,
  });

  final VoidCallback? onAlbum;
  final VoidCallback? onShutter;
  final VoidCallback? onManualEntry;

  /// 셔터를 가운데에, 앨범과 직접 입력 버튼을 양옆에 둔다.
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

/// 셔터 양옆에 두는 아이콘·글자 사각 버튼.
class _SideButton extends StatelessWidget {
  /// 아이콘, 글자, 누를 때 동작으로 버튼을 만든다. [onPressed]가 `null`이면 누를 수 없다.
  const _SideButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  static const _size = 60.0;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// 누를 수 없을 때는 아이콘과 글자를 흐린 색으로 그린다.
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

/// 사진을 찍는 원형 셔터 버튼.
class _ShutterButton extends StatelessWidget {
  /// 누를 때 동작으로 셔터를 만든다. [onPressed]가 `null`이면 누를 수 없다.
  const _ShutterButton({required this.onPressed});

  static const _outerSize = 84.0;
  static const _innerSize = 64.0;

  final VoidCallback? onPressed;

  /// 바깥 원 안에 흰 원을 겹쳐 그리고, 누를 수 없을 때는 흐리게 한다. 화면 읽기 프로그램에는 '촬영' 버튼으로 알린다.
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
