import 'dart:async';
import 'package:flutter/material.dart';

class DelayedSpinner extends StatefulWidget {
  const DelayedSpinner({super.key});

  @override
  State<DelayedSpinner> createState() => _DelayedSpinnerState();
}

class _DelayedSpinnerState extends State<DelayedSpinner> {
  late final Timer _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 24,
    child: _visible ? const CircularProgressIndicator(strokeWidth: 2) : null,
  );
}
