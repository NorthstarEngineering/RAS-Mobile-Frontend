import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/http_inventory_repository.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../widgets/stock_widgets.dart';

class InventoryValueScreen extends StatefulWidget {
  const InventoryValueScreen({
    super.key,
    this.branchId = 'br_01',
    this.repository,
  });

  final String branchId;
  final InventoryRepository? repository;

  @override
  State<InventoryValueScreen> createState() => _InventoryValueScreenState();
}

class _InventoryValueScreenState extends State<InventoryValueScreen> {
  late final InventoryRepository _repository;
  bool _isLoading = true;
  StockValuation? _valuation;
  String? _effectiveBranchId;

  @override
  void initState() {
    super.initState();
    _effectiveBranchId = widget.branchId;
    _repository = widget.repository ??
        (sl.isRegistered<InventoryRepository>()
            ? sl<InventoryRepository>()
            : HttpInventoryRepository());
    _loadValuation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final state = GoRouterState.of(context);
      final qBranch = state.uri.queryParameters['branch_id'];
      if (qBranch != null && qBranch.isNotEmpty && qBranch != _effectiveBranchId) {
        _effectiveBranchId = qBranch;
        _loadValuation();
      }
    } catch (_) {}
  }

  Future<void> _loadValuation() async {
    setState(() => _isLoading = true);
    try {
      final val = await _repository.getValuation(branchId: _effectiveBranchId ?? widget.branchId);
      if (mounted) {
        setState(() {
          _valuation = val;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'تقييم قيمة المخزون',
    tab: 4,
    child: RefreshIndicator(
      onRefresh: _loadValuation,
      child: StockScrollBody(
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _evaluationNote(),
            const SizedBox(height: 12),
            _totalValue(),
            const SizedBox(height: 12),
            _summaryMetrics(),
            const SizedBox(height: 16),
            _categoryValues(),
            const SizedBox(height: 16),
            _highestValueItems(context),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _exportNotice(context),
            icon: const Icon(Icons.ios_share),
            label: const Text('تصدير كشف تقييم المخزون (PDF / Excel)'),
          ),
          TextButton.icon(
            onPressed: () => context.go('/inventory'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('العودة لقائمة المخزون'),
          ),
        ],
      ),
    ),
  );

  Widget _evaluationNote() => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: const Text(
      'قيمة المخزون تمثل رأس المال المقيد في خامات الفرع، ولا تمثل إيرادات أو مبيعات نقدية.',
    ),
  );

  Widget _totalValue() {
    final val = _valuation?.totalValuation ?? 0.0;
    final branchName = _valuation?.branchName ?? 'الفرع (${_effectiveBranchId ?? widget.branchId})';
    final totalItems = _valuation?.totalItems ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إجمالي القيمة التقديرية للمخزون (سعر التكلفة)',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '${_money(val)} ج.م',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'الفرع: $branchName • $totalItems صنف مسجل في قاعدة البيانات',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetrics() {
    final totalItems = _valuation?.totalItems ?? 0;
    final critCount = _valuation?.criticalCount ?? 0;
    return Row(
      children: [
        Expanded(
          child: StockMetricCard(
            label: 'أصناف حرجة النقص',
            value: '$critCount أصناف',
            icon: Icons.warning_amber_rounded,
            color: critCount > 0 ? AppColors.error : AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StockMetricCard(
            label: 'إجمالي البنود',
            value: '$totalItems صنف',
            icon: Icons.category_outlined,
          ),
        ),
      ],
    );
  }

  Widget _categoryValues() {
    final categories = _valuation?.byCategory ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StockSectionTitle(
              'توزيع القيمة حسب الأقسام',
              icon: Icons.pie_chart_outline,
            ),
            if (categories.isNotEmpty)
              for (final cat in categories)
                _categoryRow(
                  cat.category,
                  cat.totalValue,
                  cat.percentage.round(),
                  '${cat.itemCount} أصناف • ${_money(cat.totalQuantity)} كجم/وحدة',
                )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'لا توجد تصنيفات مخزنية مسجلة لهذا الفرع',
                    style: TextStyle(color: AppColors.secondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _categoryRow(
    String name,
    double value,
    int percentage,
    String subtitle,
  ) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: AppTypography.labelMd)),
                Text('${_money(value)} ج.م • $percentage%'),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
            ),
          ],
        ),
      );

  Widget _highestValueItems(BuildContext context) {
    final items = _valuation?.topItems ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StockSectionTitle(
          'أعلى بنود المخزون قيمة',
          icon: Icons.format_list_numbered,
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'لا توجد أصناف مسجلة بالفرع لحساب أعلى قيمة',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _valueItem(context, item),
            ),
      ],
    );
  }

  Widget _valueItem(BuildContext context, StockItem item) => InkWell(
    onTap: () => context.push('/inventory/${item.id}?branch_id=${item.branchId}'),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${item.sku} • ${item.quantity.toInt()} ${item.unit} • ${item.unitCost.toStringAsFixed(1)} ج.م للوحدة',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_money(item.totalValue)} ج.م',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _exportNotice(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خاصية التصدير غير مفعلة حالياً - قيد التطوير (غير مكتملة)'),
          backgroundColor: AppColors.secondary,
        ),
      );

  String _money(double amount) => amount.toStringAsFixed(0);
}
