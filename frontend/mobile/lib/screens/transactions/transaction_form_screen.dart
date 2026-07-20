import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../monetization/ads_manager.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';


class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _counterpartyCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  String _type = 'expense';
  String? _categoryId;
  String? _eventType;
  DateTime _date = DateTime.now();
  bool _isSubmitting = false;

  static const _eventTypes = [
    {'value': '', 'label': '없음'},
    {'value': 'wedding', 'label': '💍 결혼식'},
    {'value': 'funeral', 'label': '🕯️ 장례식'},
    {'value': 'birthday', 'label': '🎂 생일'},
    {'value': 'baby', 'label': '👶 돌잔치'},
    {'value': 'housewarming', 'label': '🏠 집들이'},
    {'value': 'other', 'label': '기타'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().fetchCategories();
    });
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
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택하세요')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await context.read<TransactionProvider>().createTransaction(
          categoryId: _categoryId!,
          amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
          type: _type,
          transactionDate: DateFormat('yyyy-MM-dd').format(_date),
          counterpartyName: _counterpartyCtrl.text,
          memo: _memoCtrl.text,
          eventType: _eventType,
        );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('거래가 등록되었습니다'), backgroundColor: Color(0xFF10B981)),
        );
        // 저장 N회마다 전면 광고 (정책은 AdConfig 참고). pop 이후라 화면 전환을 막지 않는다.
        unawaited(AdsManager.instance.onTransactionSaved());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록에 실패했습니다'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catProvider = context.watch<CategoryProvider>();
    final categories = _type == 'expense' ? catProvider.expenseCategories : catProvider.incomeCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('거래 등록', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 수입/지출 탭
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    _TypeButton(label: '지출', value: 'expense', current: _type, onTap: () {
                      setState(() { _type = 'expense'; _categoryId = null; });
                    }),
                    _TypeButton(label: '수입', value: 'income', current: _type, onTap: () {
                      setState(() { _type = 'income'; _categoryId = null; });
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Card(children: [
                // 금액
                _FieldLabel('금액'),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: '원',
                    border: InputBorder.none,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '금액을 입력하세요' : null,
                ),
                const Divider(),

                // 날짜
                _FieldLabel('날짜'),
                InkWell(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(DateFormat('yyyy년 MM월 dd일').format(_date), style: const TextStyle(fontSize: 15)),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const Divider(),

                // 카테고리
                _FieldLabel('카테고리'),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  hint: const Text('선택하세요'),
                  decoration: const InputDecoration(border: InputBorder.none),
                  items: categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.icon ?? ''} ${c.name}'),
                  )).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ]),
              const SizedBox(height: 12),

              _Card(children: [
                // 상대방
                _FieldLabel('상대방 이름'),
                TextFormField(
                  controller: _counterpartyCtrl,
                  decoration: const InputDecoration(hintText: '홍길동 (선택)', border: InputBorder.none),
                ),
                const Divider(),

                // 경조사 유형
                _FieldLabel('경조사 유형'),
                DropdownButtonFormField<String>(
                  initialValue: _eventType,
                  hint: const Text('없음'),
                  decoration: const InputDecoration(border: InputBorder.none),
                  items: _eventTypes.map((e) => DropdownMenuItem(
                    value: e['value']!.isEmpty ? null : e['value'],
                    child: Text(e['label']!),
                  )).toList(),
                  onChanged: (v) => setState(() => _eventType = v),
                ),
                const Divider(),

                // 메모
                _FieldLabel('메모'),
                TextFormField(
                  controller: _memoCtrl,
                  decoration: const InputDecoration(hintText: '메모 (선택)', border: InputBorder.none),
                  maxLines: 2,
                ),
              ]),
              const SizedBox(height: 24),

              // 등록 버튼
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('등록', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label, value, current;
  final VoidCallback onTap;
  const _TypeButton({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    final color = value == 'expense' ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
      );
}
