import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/menu_item_request.dart';
import '../../domain/repositories/menu_repository.dart';
import '../widgets/menu_load_view.dart';

class MenuItemRequestReviewScreen extends StatefulWidget {
  const MenuItemRequestReviewScreen({super.key, required this.requestId});
  final String requestId;
  @override
  State<MenuItemRequestReviewScreen> createState() =>
      _MenuItemRequestReviewScreenState();
}

class _MenuItemRequestReviewScreenState
    extends State<MenuItemRequestReviewScreen> {
  final _repository = sl<MenuRepository>();
  final _sku = TextEditingController();
  final _reason = TextEditingController();
  late Future<MenuItemRequest?> _request;
  bool _submitting = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _request = _repository.getMenuItemRequestById(widget.requestId);
  }

  @override
  void dispose() {
    _sku.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_sku.text.trim().isEmpty) {
      _message('أدخل كود SKU للصنف');
      return;
    }
    await _submit(
      () => _repository.approveMenuItemRequest(
        widget.requestId,
        _sku.text.trim(),
      ),
    );
  }

  Future<void> _reject() async {
    if (_reason.text.trim().isEmpty) {
      _message('أدخل سبب الرفض');
      return;
    }
    await _submit(
      () => _repository.rejectMenuItemRequest(
        widget.requestId,
        _reason.text.trim(),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit(Future<void> Function() decision) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await decision();
      if (!mounted) return;
      _message('تم تسجيل القرار');
      context.pop(true);
    } on Exception catch (error) {
      if (mounted) _message(menuErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مراجعة طلب الصنف')),
    body: MenuLoadView<MenuItemRequest?>(
      future: _request,
      onRetry: () => setState(_reload),
      builder: (request) => request == null
          ? const Center(child: Text('الطلب غير موجود'))
          : _details(request),
    ),
  );

  Widget _details(MenuItemRequest request) => ListView(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    children: [
      Text(
        request.itemNameAr,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      ListTile(
        title: const Text('رقم الطلب'),
        subtitle: Text(request.requestNumber),
      ),
      ListTile(
        title: const Text('الحالة'),
        subtitle: Text(request.status.labelArabic),
      ),
      ListTile(
        title: const Text('معرّف الفرع'),
        subtitle: Text(request.branchName),
      ),
      ListTile(
        title: const Text('معرّف مقدم الطلب'),
        subtitle: Text(request.requestedByName),
      ),
      ListTile(
        title: const Text('السعر المقترح'),
        subtitle: Text('${request.proposedPrice.toStringAsFixed(2)} ج.م'),
      ),
      ListTile(
        title: const Text('تاريخ الطلب'),
        subtitle: Text(request.requestDate.toLocal().toString()),
      ),
      if (request.reason.isNotEmpty)
        ListTile(
          title: const Text('مبرر الطلب'),
          subtitle: Text(request.reason),
        ),
      if (request.notes.isNotEmpty)
        ListTile(
          title: Text(
            request.status == MenuItemRequestStatus.rejected
                ? 'سبب الرفض'
                : 'الوصف',
          ),
          subtitle: Text(request.notes),
        ),
      if (request.status == MenuItemRequestStatus.pending &&
          sl<AuthBloc>().state.session?.role == StaffRole.ceo) ...[
        TextField(
          controller: _sku,
          decoration: const InputDecoration(
            labelText: 'كود SKU مطلوب للموافقة',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _submitting ? null : _approve,
          child: const Text('الموافقة وإضافة الصنف'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _reason,
          decoration: const InputDecoration(labelText: 'سبب الرفض'),
          maxLines: 3,
        ),
        OutlinedButton(
          onPressed: _submitting ? null : _reject,
          child: const Text('رفض الطلب'),
        ),
      ],
    ],
  );
}
