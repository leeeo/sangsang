import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_shell.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  static const _channel = MethodChannel('sangsang/reminder');
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  DateTime? _pending, _date;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String? _message;
  bool _busy = false, _error = false, _blocked = false, _loaded = false;

  @override
  void initState() {
    super.initState();
    if (_supported) _load();
  }

  Future<void> _load() => _run(() async {
    final value = await _channel.invokeMethod<int>('pending');
    if (mounted) {
      setState(() {
        _pending = value == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(value);
        _loaded = true;
      });
    }
  });

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) _status('알림을 처리하지 못했어요. 다시 시도해 주세요.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _status(String text, {bool error = false}) => setState(() {
    _message = text;
    _error = error;
  });

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final day = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDate: _date == null || _date!.isBefore(today) ? today : _date,
    );
    if (mounted && day != null) setState(() => _date = day);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (mounted && time != null) setState(() => _time = time);
  }

  Future<void> _save() => _run(() async {
    final date = _date!;
    final when = DateTime(
      date.year,
      date.month,
      date.day,
      _time.hour,
      _time.minute,
    );
    if (!when.isAfter(DateTime.now())) {
      _status('지금보다 나중인 날짜와 시간을 골라 주세요.', error: true);
      return;
    }
    var allowed = await _channel.invokeMethod<bool>('allowed') ?? false;
    if (!mounted) return;
    if (!allowed) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('알림을 받으려면 권한이 필요해요'),
          content: const Text(
            '정한 시간에 이 휴대폰에서 알림을 보여주기 위해 Android 알림 권한을 요청해요. 이름·금액은 알림에 넣지 않아요. 허용하지 않아도 장부는 계속 쓸 수 있어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('권한 요청'),
            ),
          ],
        ),
      );
      if (!mounted || proceed != true) return;
      allowed = await _channel.invokeMethod<bool>('requestPermission') ?? false;
    }
    if (!mounted) return;
    setState(() => _blocked = !allowed);
    if (!allowed) {
      _status('알림이 꺼져 있어 예약하지 않았어요. 필요하면 Android 설정에서 켜 주세요.', error: true);
      return;
    }
    await _channel.invokeMethod<void>('schedule', when.millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() => _pending = when);
    _status('경조사 알림을 예약했어요.');
  });

  Future<void> _cancel() => _run(() async {
    await _channel.invokeMethod<void>('cancel');
    if (!mounted) return;
    setState(() => _pending = null);
    _status('알림 예약을 취소했어요.');
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = _pending;
    final date = _date;
    final dateFormat = DateFormat('yyyy년 M월 d일');
    return Scaffold(
      appBar: AppBar(title: const Text('경조사 알림')),
      body: PageBody(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _supported ? '챙길 날짜 기억하기' : '알림은 Android 앱에서',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _supported
                          ? '이 휴대폰에서만 한 번 알려드려요. 알림에 이름이나 금액을 표시하지 않아요.'
                          : '이 화면에서는 알림을 예약할 수 없어요. Android 앱에서 날짜와 시간을 골라 주세요.',
                    ),
                    if (_supported) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '한 번에 하나만 예약할 수 있어요. 기기 설정이나 절전 상태에 따라 늦어질 수 있어요.',
                      ),
                      if (_loaded) ...[
                        const SizedBox(height: 16),
                        Text(
                          pending == null
                              ? '예약된 알림이 없어요.'
                              : '예약 시간: ${dateFormat.format(pending)} ${TimeOfDay.fromDateTime(pending).format(context)}',
                        ),
                        if (pending != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _busy ? null : _cancel,
                              child: const Text('예약 취소'),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _pickDate,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                date == null
                                    ? '날짜 선택'
                                    : dateFormat.format(date),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _pickTime,
                              icon: const Icon(Icons.schedule),
                              label: Text('시간: ${_time.format(context)}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy || date == null ? null : _save,
                          child: Text(pending == null ? '알림 예약' : '예약 시간 바꾸기'),
                        ),
                        if (_blocked)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () =>
                                        _channel.invokeMethod<void>('settings'),
                                  ),
                            child: const Text('Android 알림 설정 열기'),
                          ),
                      ] else if (!_busy)
                        TextButton(
                          onPressed: _load,
                          child: const Text('다시 시도'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (_message case final message?)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: _error
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
