import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/service_locator.dart';
import '../../core/network/authenticated_api.dart';
import '../auth/domain/entities/user_session.dart';
import '../auth/presentation/bloc/auth_bloc.dart';
import '../menu/presentation/widgets/menu_load_view.dart';
import '../branches/domain/entities/branch.dart';
import '../branches/domain/repositories/branch_repository.dart';
import 'operations_api.dart';

class OperationsHome extends StatelessWidget {
  const OperationsHome({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('عمليات الفروع')),
    body: ListView(
      children: [
        for (final (route, title) in const [
          ('sales', 'المبيعات والورديات'),
          ('inventory', 'دليل الخامات'),
          ('stock', 'مخزون الفروع'),
          ('reports', 'التقارير وسجل التدقيق'),
          ('supply', 'طلبات التوريد'),
          ('transfers', 'التحويلات بين الفروع'),
        ])
          ListTile(
            title: Text(title),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => context.push('/operations/$route'),
          ),
      ],
    ),
  );
}

class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key, required this.module});
  final String module;

  @override
  Widget build(BuildContext context) {
    const supplyUrl = String.fromEnvironment('RAS_SUPPLY_API_BASE_URL');
    final (title, url) = switch (module) {
      'sales' => (
        'المبيعات والورديات',
        const String.fromEnvironment('RAS_SALES_API_BASE_URL'),
      ),
      'inventory' => ('دليل الخامات', supplyUrl),
      'stock' => (
        'مخزون الفروع',
        const String.fromEnvironment('RAS_STOCK_API_BASE_URL'),
      ),
      'reports' => (
        'التقارير وسجل التدقيق',
        const String.fromEnvironment('RAS_REPORTS_API_BASE_URL'),
      ),
      'supply' => ('طلبات التوريد', supplyUrl),
      'transfers' => (
        'التحويلات بين الفروع',
        const String.fromEnvironment('RAS_TRANSFER_API_BASE_URL'),
      ),
      _ => ('عمليات الفروع', ''),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _body(context, url),
    );
  }

  Widget _body(BuildContext context, String url) {
    final session = sl<AuthBloc>().state.session;
    final allowed =
        session?.role == StaffRole.ceo ||
        (session?.role == StaffRole.branchManager &&
            session!.branchId.isNotEmpty);
    if (!allowed) {
      return const Center(child: Text('العمليات متاحة للإدارة ومديري الفروع'));
    }
    if (url.isEmpty) {
      return const Center(
        child: Text('عنوان الخدمة غير مضبوط في نسخة التطبيق'),
      );
    }
    final api = OperationsApi(
      AuthenticatedApi(sl<AuthenticatedApi>().auth, baseUrl: url),
      session!,
    );
    final operations = switch (module) {
      'sales' => api.sales,
      'inventory' => api.inventory,
      'stock' => api.stock,
      'reports' => api.reports,
      'supply' => api.supply,
      'transfers' => api.transfers,
      _ => const <Operation>[],
    };
    return ListView(
      children: [
        for (final operation in operations)
          ListTile(
            title: Text(operation.title),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OperationForm(operation: operation),
              ),
            ),
          ),
      ],
    );
  }
}

class OperationForm extends StatefulWidget {
  const OperationForm({super.key, required this.operation});
  final Operation operation;

  @override
  State<OperationForm> createState() => _OperationFormState();
}

class _OperationFormState extends State<OperationForm> {
  late final Map<String, String> _values = {
    for (final field in widget.operation.fields) field.key: field.initial,
  };
  Future<List<Branch>>? _branches;

  bool _isBranchField(OperationField field) => const {
    'branch_id',
    'source_branch_id',
    'dest_branch_id',
  }.contains(field.key);

  @override
  void initState() {
    super.initState();
    if (widget.operation.fields.any(_isBranchField)) {
      _branches = sl<BranchRepository>().getBranches();
    }
  }

  Widget _branchInput(OperationField field, bool enabled) =>
      FutureBuilder<List<Branch>>(
        future: _branches,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              children: [
                _textInput(field, enabled),
                TextButton(
                  onPressed: enabled
                      ? () => setState(() {
                          _branches = sl<BranchRepository>().getBranches();
                        })
                      : null,
                  child: const Text('إعادة تحميل الفروع'),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final branches = snapshot.data!;
          if (branches.isEmpty) {
            return const ListTile(
              title: Text('مفيش فروع متاحة. أضف فرع من شاشة الفروع أولًا.'),
            );
          }
          final current = _values[field.key];
          return DropdownButtonFormField<String>(
            initialValue: branches.any((branch) => branch.id == current)
                ? current
                : field.optional
                ? ''
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: field.label.replaceFirst('معرّف ', ''),
            ),
            items: [
              if (field.optional)
                const DropdownMenuItem(value: '', child: Text('كل الفروع')),
              for (final branch in branches)
                DropdownMenuItem(value: branch.id, child: Text(branch.name)),
            ],
            onChanged: enabled
                ? (value) => _values[field.key] = value ?? ''
                : null,
          );
        },
      );

  bool _busy = false;
  bool _completed = false;
  Object? _response;
  String? _error;

  Fields _request() {
    final payload = <String, Object?>{};
    for (final field in widget.operation.fields) {
      final value = field.parse(_values[field.key] ?? '');
      if (value != null) payload[field.key] = value;
    }
    return payload;
  }

  Future<void> _submit() async {
    if (_busy || (_completed && widget.operation.changesData)) return;
    setState(() {
      _busy = true;
      _error = null;
      _response = null;
    });
    try {
      final response = await widget.operation.run(_request());
      if (!mounted) return;
      _response = response;
      _completed = true;
    } on Exception catch (error) {
      if (mounted) _error = menuErrorMessage(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final operation = widget.operation;
    final committed = _completed && operation.changesData;
    return Scaffold(
      appBar: AppBar(title: Text(operation.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final field in operation.fields)
            _input(field, !_busy && !committed),
          FilledButton(
            onPressed: _busy || committed ? null : _submit,
            child: Text(
              _busy
                  ? 'جارٍ التنفيذ…'
                  : operation.changesData
                  ? 'تأكيد العملية'
                  : 'عرض',
            ),
          ),
          if (_error case final String error)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error),
            ),
          if (_completed) ...[
            if (operation.changesData)
              const ListTile(title: Text('تم تنفيذ العملية')),
            _Result(data: _response),
          ],
        ],
      ),
    );
  }

  Widget _input(OperationField field, bool enabled) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _isBranchField(field) && _branches != null
        ? _branchInput(field, enabled)
        : field.choices.isNotEmpty
        ? DropdownButtonFormField<String>(
            initialValue: field.initial,
            decoration: InputDecoration(labelText: field.label),
            items: field.choices
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_label(value)),
                  ),
                )
                .toList(),
            onChanged: enabled ? (value) => _values[field.key] = value! : null,
          )
        : _textInput(field, enabled),
  );

  Widget _textInput(OperationField field, bool enabled) => TextFormField(
    initialValue: field.initial,
    enabled: enabled,
    minLines: field.kind == InputKind.lines ? 3 : 1,
    maxLines: field.kind == InputKind.lines ? 7 : 1,
    decoration: InputDecoration(
      labelText: field.label,
      helperMaxLines: 3,
      helperText: field.columns.isEmpty
          ? null
          : 'كل بند في سطر. افصل الخانات بفاصلة: ${field.columns.map((column) => column.label).join('، ')}',
    ),
    onChanged: (value) => _values[field.key] = value,
  );
}

String _label(String key) =>
    const {
      '': 'الكل',
      'AVAILABLE': 'متوفر',
      'LOW': 'منخفض',
      'CRITICAL': 'حرج',
      'min_stock': 'حد الأمان',
      'max_stock': 'السعة القصوى',
      'location_code': 'مكان التخزين',
      'reorder_level': 'حد إعادة الطلب',
      'unit_cost': 'تكلفة الوحدة',
      'quantity_before': 'الرصيد قبل الحركة',
      'quantity_after': 'الرصيد بعد الحركة',
      'id': 'المعرّف',
      'name': 'الاسم',
      'code': 'الرقم',
      'sku': 'الكود',
      'status': 'الحالة',
      'items': 'البنود',
      'branch_id': 'الفرع',
      'shift_id': 'الوردية',
      'good_id': 'الخامة',
      'quantity': 'الكمية',
      'amount': 'المبلغ',
      'reason': 'السبب',
      'channel': 'القناة',
      'gross_sales': 'إجمالي البيع',
      'net_sales': 'صافي البيع',
      'total_discounts': 'إجمالي الخصومات',
      'total_orders': 'عدد الطلبات',
      'source_branch_name': 'الفرع المرسل',
      'dest_branch_name': 'الفرع المستلم',
      'good_name': 'الخامة',
      'requested_quantity': 'الكمية المطلوبة',
      'approved_quantity': 'الكمية المعتمدة',
      'received_quantity': 'الكمية المستلمة',
      'PENDING': 'قيد المراجعة',
      'APPROVED': 'تمت الموافقة',
      'REJECTED': 'مرفوض',
      'SHIPPED': 'تم الشحن',
      'SENT': 'تم الإرسال',
      'RECEIVED': 'تم الاستلام',
      'FULFILLED': 'مكتمل',
      'OPEN': 'مفتوحة',
      'CLOSED': 'مغلقة',
      'RESTAURANT': 'داخل المطعم',
      'DELIVERY': 'توصيل',
      'NORMAL': 'عادي',
      'URGENT': 'عاجل',
      'IN': 'إضافة',
      'OUT': 'صرف',
      'ADJUSTMENT': 'تسوية',
    }[key] ??
    key;

class _Result extends StatelessWidget {
  const _Result({required this.data});
  final Object? data;

  @override
  Widget build(BuildContext context) => switch (data) {
    null => const SizedBox.shrink(),
    final List rows =>
      rows.isEmpty
          ? const ListTile(title: Text('مفيش بيانات'))
          : Column(
              children: rows
                  .map(
                    (row) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _Result(data: row),
                      ),
                    ),
                  )
                  .toList(),
            ),
    final Map row => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in row.entries)
          if (entry.value != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: entry.value is Map || entry.value is List
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_label(entry.key.toString())),
                        _Result(data: entry.value),
                      ],
                    )
                  : SelectableText(
                      '${_label(entry.key.toString())}: ${_label(entry.value.toString())}',
                    ),
            ),
      ],
    ),
    final value => SelectableText(value.toString()),
  };
}
