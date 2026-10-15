import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/delayed_spinner.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().createLocalProfile(_nameCtrl.text.trim());
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '이름을 저장하지 못했어요. 입력한 이름을 확인하고 다시 시작해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          maxWidth: 640,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(Icons.volunteer_activism_outlined,
                        size: 48, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text('상부상조', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('주고받은 마음,\n오래 기억하도록.',
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  Text(
                    '소중한 날 함께한 사람과 마음을\n나만의 기록장에 남겨 보세요.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const ValueKey('profile-name'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: _nameCtrl,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _start(),
                    decoration: const InputDecoration(
                      labelText: '어떤 이름으로 불러드릴까요?',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: '이름 또는 별명',
                      helperText: '나에게만 보이는 이름이에요.',
                      helperMaxLines: 2,
                      errorMaxLines: 3,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이름이나 별명을 입력해 주세요.';
                      }
                      if (value.trim().length > 100) {
                        return '100자 이내로 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.phone_android_outlined,
                              color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text('이 기기에 간직하는 기록',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          const Text('회원가입 없이 시작해요.\n기록은 기기에만 저장해요.\n서버로 보내지 않아요.'),
                          const SizedBox(height: 12),
                          Text(
                            '앱 삭제·기기 변경 전에는\n홈에서 백업 파일을 보관해 주세요.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('profile-start'),
                    onPressed: _isSubmitting ? null : _start,
                    icon: _isSubmitting
                        ? const DelayedSpinner()
                        : const Icon(Icons.arrow_forward),
                    label: Text(_isSubmitting ? '기록장 준비하는 중' : '내 기록장 시작하기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
