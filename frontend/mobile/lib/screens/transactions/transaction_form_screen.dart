import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../monetization/ads_manager.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/form_exit_guard.dart';
import '../../widgets/delayed_spinner.dart';

class TransactionFormScreen extends StatefulWidget {
  final String? initialCounterpartyName;
  final String initialType;

  const TransactionFormScreen({
    super.key,
    this.initialCounterpartyName,
    this.initialType = 'expense',
  }) : assert(initialType == 'expense' || initialType == 'income');

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _counterpartyCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  late String _type;
  String? _categoryId;
  String? _eventType;
  String? _saveError;
  bool _categoryError = false;
  final DateTime _initialDate = DateTime.now();
  late DateTime _date;
  bool _isSubmitting = false;
  bool _saved = false;

  bool get _hasChanges => !_saved && (
    _amountCtrl.text.isNotEmpty || _memoCtrl.text.isNotEmpty ||
    _counterpartyCtrl.text != (widget.initialCounterpartyName ?? '') ||
    _type != widget.initialType || _categoryId != null || _eventType != null ||
    !DateUtils.isSameDay(_date, _initialDate)
  );

  static const _eventTypes = {
    '': '선택 안 함',
    'wedding': '결혼식',
    'funeral': '장례식',
    'birthday': '생일',
    'baby': '돌잔치',
    'housewarming': '집들이',
    'other': '기타',
  };

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _date = _initialDate;
    _counterpartyCtrl.text = widget.initialCounterpartyName ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCategories();
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _categoryError = false);
    try {
      await context.read<CategoryProvider>().fetchCategories();
    } catch (_) {
      if (mounted) setState(() => _categoryError = true);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _counterpartyCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'),
    );
    if (mounted && picked != null) setState(() => _date = picked);
  }

  String? _validateAmount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '금액을 입력해 주세요.';
    if (!RegExp(r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)$').hasMatch(text)) {
      return '원 단위 숫자로 입력해 주세요.';
    }
    final amount = double.tryParse(text.replaceAll(',', ''));
    if (amount == null || !amount.isFinite || amount > 999999999999) {
      return '999,999,999,999원 이하로 입력해 주세요.';
    }
    if (amount <= 0) return '1원 이상 입력해 주세요.';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _saveError = null;
    });
    var saved = false;
    try {
      saved = await context.read<TransactionProvider>().createTransaction(
        categoryId: _categoryId!,
        amount: double.parse(_amountCtrl.text.trim().replaceAll(',', '')),
        type: _type,
        transactionDate: DateFormat('yyyy-MM-dd').format(_date),
        counterpartyName: _counterpartyCtrl.text.trim(),
        memo: _memoCtrl.text.trim(),
        eventType: _eventType,
      );
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _saved = saved;
      if (!saved) {
        _saveError = '기록을 저장하지 못했어요. 입력한 내용은 그대로 있으니 다시 저장해 주세요.';
      }
    });
    if (saved) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(const SnackBar(content: Text('마음을 기록했어요.')));
      unawaited(AdsManager.instance.onTransactionSaved());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CategoryProvider>();
    final categories = _type == 'expense'
        ? provider.expenseCategories
        : provider.incomeCategories;
    return FormExitGuard(
      hasChanges: _hasChanges,
      saving: _isSubmitting,
      child: Scaffold(
      appBar: AppBar(title: const Text('마음 기록')),
      body: SafeArea(
        child: PageBody(
          maxWidth: 640,
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('누구와 나눈 마음인가요?', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '함께한 사람을 기록해요.\n다음에 꺼내볼 수 있어요.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('record-person'),
                    controller: _counterpartyCtrl,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '함께한 사람 (선택)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: '예: 김민수',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) > 100
                        ? '이름은 100자 이내로 입력해 주세요.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text('마음의 방향', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final direction in const {
                        'expense': '보낸 마음',
                        'income': '받은 마음',
                      }.entries)
                        ChoiceChip(
                          key: ValueKey('record-direction-${direction.key}'),
                          label: Text(direction.value),
                          avatar: Icon(direction.key == 'expense'
                              ? Icons.north_east
                              : Icons.south_west),
                          selected: _type == direction.key,
                          onSelected: _isSubmitting ? null : (selected) {
                            if (selected && direction.key != _type) {
                              setState(() {
                                _type = direction.key;
                                _categoryId = null;
                              });
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('record-amount'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: _amountCtrl,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '금액',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: '예: 50,000',
                      suffixText: '원',
                      errorMaxLines: 3,
                    ),
                    validator: _validateAmount,
                  ),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: ValueKey('category-direction-$_type'),
                    child: DropdownButtonFormField<String>(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      key: const ValueKey('record-category'),
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '마음의 분류',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        errorMaxLines: 3,
                      ),
                      hint: const Text('분류 선택'),
                      items: categories.map((category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.displayName,
                            overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: _isSubmitting || provider.isLoading
                          ? null
                          : (value) => setState(() => _categoryId = value),
                      validator: (value) => value == null
                          ? '마음의 분류를 선택해 주세요.'
                          : null,
                    ),
                  ),
                  if (provider.isLoading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ] else if (_categoryError || categories.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('분류를 불러오지 못했어요. 다시 불러온 뒤 선택해 주세요.'),
                    TextButton.icon(
                      onPressed: _loadCategories,
                      icon: const Icon(Icons.refresh),
                      label: const Text('분류 다시 불러오기'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const ValueKey('record-date'),
                    onPressed: _isSubmitting ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('날짜  ${DateFormat('yyyy년 M월 d일').format(_date)}'),
                  ),
                  const SizedBox(height: 32),
                  Text('기억하고 싶은 이야기', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('경조사와 메모는 필요할 때만 남겨 주세요.'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('record-event'),
                    initialValue: _eventType ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '어떤 자리였나요? (선택)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    items: _eventTypes.entries.map((event) => DropdownMenuItem(
                      value: event.key,
                      child: Text(event.value),
                    )).toList(),
                    onChanged: _isSubmitting ? null : (value) {
                      setState(() => _eventType =
                          value == null || value.isEmpty ? null : value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('record-memo'),
                    controller: _memoCtrl,
                    enabled: !_isSubmitting,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '기억할 내용 (선택)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: '예: 오랜만에 만나 반가웠던 날',
                    ),
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(_saveError!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('record-save'),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const DelayedSpinner()
                        : const Icon(Icons.check),
                    label: Text(_isSubmitting ? '저장하는 중' : '마음 기록하기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
