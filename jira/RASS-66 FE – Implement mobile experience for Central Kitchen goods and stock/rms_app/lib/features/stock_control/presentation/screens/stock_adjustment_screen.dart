import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_inventory_repository.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../widgets/stock_widgets.dart';

enum _AdjustmentMode { deficit, surplus, setBalance }

class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({
    super.key,
    required this.itemId,
    this.branchId,
    this.repository,
  });

  final String itemId;
  final String? branchId;
  final InventoryRepository? repository;

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  late final InventoryRepository _repository;
  StockItem? _loadedItem;
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _effectiveBranchId;

  final _note = TextEditingController(
    text: 'تم استبعاد كمية تالفة بعد فحص الجودة أثناء التجهيز.',
  );
  _AdjustmentMode _mode = _AdjustmentMode.deficit;
  double _quantity = 1;
  String _reason = 'هالك أثناء التحضير';
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    _effectiveBranchId = widget.branchId;
    _repository = widget.repository ??
        (sl.isRegistered<InventoryRepository>()
            ? sl<InventoryRepository>()
            : HttpInventoryRepository());
    _loadItem();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final state = GoRouterState.of(context);
      final qBranch = state.uri.queryParameters['branch_id'];
      if (qBranch != null && qBranch.isNotEmpty && qBranch != _effectiveBranchId) {
        _effectiveBranchId = qBranch;
        _loadItem();
      }
      if (state.extra is StockItem && _loadedItem == null) {
        final extraItem = state.extra as StockItem;
        _loadedItem = extraItem;
        _effectiveBranchId = extraItem.branchId;
        _isLoading = false;
      }
    } catch (_) {}
  }

  Future<void> _loadItem() async {
    setState(() => _isLoading = true);
    try {
      final item = await _repository.getInventoryItemById(
        widget.itemId,
        branchId: _effectiveBranchId,
      );
      if (item != null && mounted) {
        setState(() {
          _loadedItem = item;
          _effectiveBranchId = item.branchId;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  StockItem? get _item => _loadedItem;

  double get _signedAdjustment {
    if (_item == null) return 0.0;
    return switch (_mode) {
      _AdjustmentMode.deficit => -_quantity,
      _AdjustmentMode.surplus => _quantity,
      _AdjustmentMode.setBalance => _quantity - _item!.quantity,
    };
  }

  double get _newBalance {
    if (_item == null) return 0.0;
    return (_item!.quantity + _signedAdjustment).clamp(0, double.infinity).toDouble();
  }

  double get _financialImpact {
    if (_item == null) return 0.0;
    return (_newBalance - _item!.quantity) * _item!.unitCost;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _loadedItem == null) {
      return const StockPageShell(
        title: 'تسوية المخزون',
        showNavigation: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadedItem == null) {
      return StockPageShell(
        title: 'تسوية المخزون',
        showNavigation: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('صنف المخزون غير موجود في قاعدة البيانات'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadItem,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final item = _loadedItem!;
    return StockPageShell(
      title: 'تسوية المخزون',
      showNavigation: false,
      child: StockScrollBody(
        children: [
          _auditNotice(),
          const SizedBox(height: 12),
          _itemSummary(item),
          const SizedBox(height: 12),
          _balanceEquation(item),
          const SizedBox(height: 14),
          _modeSelector(),
          const SizedBox(height: 12),
          _quantityInput(item),
          const SizedBox(height: 12),
          _reasonSelector(),
          const SizedBox(height: 12),
          _authorization(item),
          _acknowledgement(),
          const SizedBox(height: 12),
          RmsPrimaryButton(
            label: _isSubmitting ? 'جاري الاعتماد والترحيل...' : 'اعتماد وترحيل التسوية المخزنية',
            icon: Icons.check_circle_outline,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _confirm,
          ),
        ],
      ),
    );
  }

  Widget _auditNotice() => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: const Row(
      children: [
        Icon(Icons.gavel_outlined, color: AppColors.error),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'تسوية الأرصدة تؤثر مباشرة على القوائم المالية وأرباح التشغيل، وتخضع لتدقيق الإدارة.',
          ),
        ),
      ],
    ),
  );

  Widget _itemSummary(StockItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          Text('${item.sku} • ${item.category}'),
          const SizedBox(height: 8),
          Text('الفرع: ${item.branchId} • الموقع: ${item.location}'),
        ],
      ),
    ),
  );

  Widget _balanceEquation(StockItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        children: [
          const StockSectionTitle('معادلة رصيد التسوية الفعلي'),
          const SizedBox(height: 8),
          Text(
            '${_fmt(item.quantity)} ${item.unit}  →  ${_fmt(_signedAdjustment)}  →  ${_fmt(_newBalance)} ${item.unit}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Text(
            'الأثر المالي المباشر: ${_financialImpact.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              color: _financialImpact < 0 ? AppColors.error : AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _modeSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('نوع التسوية المخزنية *'),
      const SizedBox(height: 5),
      SegmentedButton<_AdjustmentMode>(
        segments: const [
          ButtonSegment(
            value: _AdjustmentMode.deficit,
            label: Text('عجز / هالك'),
            icon: Icon(Icons.remove_circle_outline),
          ),
          ButtonSegment(
            value: _AdjustmentMode.surplus,
            label: Text('فائض جرد'),
            icon: Icon(Icons.add_circle_outline),
          ),
          ButtonSegment(
            value: _AdjustmentMode.setBalance,
            label: Text('جرد فعلي'),
            icon: Icon(Icons.pin_outlined),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (selected) =>
            setState(() => _mode = selected.first),
      ),
    ],
  );

  Widget _quantityInput(StockItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _mode == _AdjustmentMode.setBalance
                ? 'الرصيد الفعلي الجديد المعتمد *'
                : 'الكمية المراد تسويتها *',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () => _changeQuantity(-1),
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '${_fmt(_quantity)} ${item.unit}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _changeQuantity(1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _reasonSelector() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سبب التسوية الموثق *'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'اختر سبب التسوية'),
            items: const [
              DropdownMenuItem(
                value: 'هالك أثناء التحضير',
                child: Text('هالك أثناء التحضير'),
              ),
              DropdownMenuItem(
                value: 'انتهاء فترة الصلاحية',
                child: Text('انتهاء فترة الصلاحية'),
              ),
              DropdownMenuItem(
                value: 'عجز أثناء الجرد الأسبوعي',
                child: Text('عجز أثناء الجرد الأسبوعي'),
              ),
              DropdownMenuItem(
                value: 'فائض غير مقيد',
                child: Text('فائض غير مقيد'),
              ),
              DropdownMenuItem(
                value: 'مطابقة جرد فعلي دوري',
                child: Text('مطابقة جرد فعلي دوري'),
              ),
            ],
            onChanged: (value) => setState(() => _reason = value ?? _reason),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'تفاصيل السبب للتدقيق',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _authorization(StockItem item) => ListTile(
    leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
    title: const Text('مسؤول المخزون المعتمد'),
    subtitle: Text('نطاق الفرع: ${item.branchId}'),
    trailing: const Text('تسوية معتمدة'),
  );

  Widget _acknowledgement() => CheckboxListTile(
    value: _acknowledged,
    onChanged: (value) => setState(() => _acknowledged = value ?? false),
    controlAffinity: ListTileControlAffinity.leading,
    title: const Text(
      'أقر بصحة كمية الجرد، وأعلم أن الحركة لا يمكن تعديلها بعد الترحيل.',
    ),
  );

  void _changeQuantity(double delta) => setState(
    () => _quantity = (_quantity + delta).clamp(0.1, 9999).toDouble(),
  );

  Future<void> _confirm() async {
    final item = _item;
    if (item == null) return;

    if (!_acknowledged || _note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل الإقرار وسبب التسوية قبل المتابعة')),
      );
      return;
    }

    if (_mode == _AdjustmentMode.deficit && _quantity > item.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن تسوية عجز/هالك بمقدار ${_fmt(_quantity)} وهو أكبر من الرصيد الحالي (${_fmt(item.quantity)})',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final modeStr = switch (_mode) {
        _AdjustmentMode.deficit => 'deficit',
        _AdjustmentMode.surplus => 'surplus',
        _AdjustmentMode.setBalance => 'setBalance',
      };

      final result = await _repository.adjustStock(
        itemId: item.id,
        quantity: _quantity,
        reason: _reason,
        branchId: item.branchId,
        mode: modeStr,
        notes: _note.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _loadedItem = result.item;
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            'تم اعتماد التسوية بنجاح • الرصيد الجديد: ${_fmt(result.newBalance)} ${item.unit} (كود: ${result.movement.code})',
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('فشل اعتماد التسوية: ${e.toString()}'),
        ),
      );
    }
  }

  String _fmt(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
