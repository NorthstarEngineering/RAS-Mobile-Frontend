import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

class SessionExpiredScreen extends StatefulWidget {
  const SessionExpiredScreen({super.key});

  @override
  State<SessionExpiredScreen> createState() => _SessionExpiredScreenState();
}

class _SessionExpiredScreenState extends State<SessionExpiredScreen> {
  bool _signingOut = false;

  Future<void> _returnToLogin() async {
    if (_signingOut) return;
    final auth = sl<AuthBloc>();
    if (auth.state.session != null) {
      setState(() => _signingOut = true);
      final signedOut = auth.stream.firstWhere(
        (state) => state.session == null,
      );
      auth.add(const LogoutRequested());
      await signedOut;
    }
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('انتهت الجلسة')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('سجّل دخولك مرة تانية عشان تكمّل.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _signingOut ? null : _returnToLogin,
              child: Text(
                _signingOut ? 'جارٍ إنهاء الجلسة…' : 'الذهاب لتسجيل الدخول',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
