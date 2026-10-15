import 'package:flutter/material.dart';

class FormExitGuard extends StatefulWidget {
  final bool hasChanges;
  final bool saving;
  final Widget child;

  const FormExitGuard({
    super.key,
    required this.hasChanges,
    required this.saving,
    required this.child,
  });

  @override
  State<FormExitGuard> createState() => _FormExitGuardState();
}

class _FormExitGuardState extends State<FormExitGuard> {
  bool _allowExit = false;
  bool _asking = false;

  Future<void> _confirmExit() async {
    if (_asking) return;
    if (widget.saving) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중이에요. 저장이 끝나면 이동할 수 있어요.')),
      );
      return;
    }
    _asking = true;
    final colors = Theme.of(context).colorScheme;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('나갈까요?'),
        content: const Text('아직 저장 전이에요.\n나가면 내용이 사라져요.'),
        actions: [
          TextButton(
            key: const ValueKey('discard-stay'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 작성'),
          ),
          FilledButton(
            key: const ValueKey('discard-leave'),
            style: FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('저장하지 않고 나가기'),
          ),
        ],
      ),
    );
    _asking = false;
    if (discard != true || !mounted) return;
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _allowExit || (!widget.hasChanges && !widget.saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmExit();
    },
    child: widget.child,
  );
}
