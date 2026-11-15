import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

String menuErrorMessage(Object error) {
  if (error is FormatException) return error.message;
  if (error is TimeoutException || error is http.ClientException) {
    return 'تعذر الاتصال بخدمة القائمة. تأكد من تشغيل الخدمة ثم أعد المحاولة.';
  }
  return 'تعذر إتمام العملية. أعد المحاولة.';
}

class MenuLoadView<T> extends StatelessWidget {
  const MenuLoadView({
    super.key,
    required this.future,
    required this.onRetry,
    required this.builder,
  });
  final Future<T> future;
  final VoidCallback onRetry;
  final Widget Function(T) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return MenuErrorView(error: snapshot.error!, onRetry: onRetry);
      }
      return builder(snapshot.data as T);
    },
  );
}

class MenuErrorView extends StatelessWidget {
  const MenuErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(menuErrorMessage(error), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );
}
