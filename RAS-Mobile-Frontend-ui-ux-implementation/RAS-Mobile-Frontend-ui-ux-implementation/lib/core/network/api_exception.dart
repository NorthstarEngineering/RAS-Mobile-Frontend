class ApiException implements Exception {
  const ApiException(
    this.statusCode,
    this.code,
    this.message, {
    this.retryAfter,
  });

  final int statusCode;
  final String? code;
  final String message;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

String arabicApiMessage(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 401) {
      return 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مجدداً.';
    }
    if (error.statusCode == 403) {
      return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.';
    }
    if (error.statusCode == 404) {
      return 'البيانات المطلوبة غير موجودة.';
    }
    if (error.statusCode == 409) {
      return 'تعارضت العملية مع حالة حالية. حدّث البيانات وحاول مجدداً.';
    }
    if (error.statusCode == 429) {
      final retrySeconds = error.retryAfter?.inSeconds ?? 0;
      if (retrySeconds > 0) {
        return 'محاولات كثيرة. أعد المحاولة بعد $retrySeconds ثانية.';
      }
      return 'محاولات كثيرة. يرجى الانتظار ثم المحاولة مرة أخرى.';
    }
    if (error.statusCode >= 500) {
      return 'الخدمة غير متاحة مؤقتاً. حاول مرة أخرى لاحقاً.';
    }
    return error.statusCode == 400
        ? 'يرجى مراجعة البيانات المدخلة.'
        : 'تعذر إتمام الطلب.';
  }
  return 'تعذر الاتصال بالخدمة. تحقق من الشبكة وحاول مرة أخرى.';
}
