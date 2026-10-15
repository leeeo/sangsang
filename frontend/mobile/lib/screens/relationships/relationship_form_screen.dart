import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/relationship_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/form_exit_guard.dart';
import '../../widgets/delayed_spinner.dart';

const _kRelationshipTypes = ['가족', '친구', '직장동료', '지인', '기타'];

class RelationshipFormScreen extends StatefulWidget {
  const RelationshipFormScreen({super.key});

  @override
  State<RelationshipFormScreen> createState() => _RelationshipFormScreenState();
}

class _RelationshipFormScreenState extends State<RelationshipFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedType;
  String? _error;
  bool _isSubmitting = false;
  bool _saved = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await context.read<RelationshipProvider>().createRelationship(
        counterpartyName: _nameCtrl.text.trim(),
        relationshipType: _selectedType,
        notes: _notesCtrl.text.trim(),
      );
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _saved = saved;
      if (!saved) {
        _error = '사람을 저장하지 못했어요. 이미 추가한 이름인지 확인한 뒤 다시 시도해 주세요.';
      }
    });
    if (saved) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormExitGuard(
      hasChanges: !_saved && (_nameCtrl.text.isNotEmpty || _notesCtrl.text.isNotEmpty || _selectedType != null),
      saving: _isSubmitting,
      child: Scaffold(
      appBar: AppBar(title: const Text('사람 추가')),
      body: SafeArea(
        child: PageBody(
          maxWidth: 640,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('기억하고 싶은 사람',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('같은 이름의 기록이 한곳에 모여요.\n기록에 쓴 이름 그대로 입력해 주세요.'),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('person-name'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: _nameCtrl,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: '예: 김민수',
                      prefixIcon: Icon(Icons.person_outline),
                      errorMaxLines: 3,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이름을 입력해 주세요.';
                      }
                      if (value.trim().length > 100) {
                        return '100자 이내로 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('person-relation'),
                    initialValue: _selectedType ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '나와의 관계 (선택)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('선택 안 함')),
                      ..._kRelationshipTypes.map((type) =>
                          DropdownMenuItem(value: type, child: Text(type))),
                    ],
                    onChanged: _isSubmitting ? null : (value) => setState(() =>
                        _selectedType = value == null || value.isEmpty ? null : value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('person-notes'),
                    controller: _notesCtrl,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: '기억할 내용 (선택)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: '예: 대학 동아리에서 만난 친구',
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(_error!, style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('person-save'),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const DelayedSpinner()
                        : const Icon(Icons.person_add_outlined),
                    label: Text(_isSubmitting ? '저장하는 중' : '사람 추가하기'),
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
