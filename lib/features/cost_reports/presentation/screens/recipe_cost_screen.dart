import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/report_export_dialog.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_cost_repository.dart';
import '../../domain/repositories/cost_repository.dart';

class RecipeCostScreen extends StatefulWidget {
  const RecipeCostScreen({super.key, this.itemId = 'item_1', this.repository});

  final String itemId;
  final CostRepository? repository;

  @override
  State<RecipeCostScreen> createState() => _RecipeCostScreenState();
}

class _RecipeCostScreenState extends State<RecipeCostScreen> {
  late final CostRepository _repository;
  RecipeCostData? _data;
  bool _isLoading = true;
  String? _errorMessage;
  late String _selectedItemId;

  final List<Map<String, String>> _availableItems = const [
    {'id': 'item_1', 'name': 'برجر كلاسيك سينجل (MENU-BRG-01)'},
    {'id': 'item_2', 'name': 'تشيكن تندر سوبريم 5 قطع (CHK-SUP-01)'},
    {'id': 'item_3', 'name': 'دبل سموكد بيكون برجر (BURG-DBL-01)'},
    {'id': 'item_4', 'name': 'حلقات بصل كريسبي (SIDE-FRIES-01)'},
    {'id': 'item_5', 'name': 'عصير برتقال طازج (DRK-ORG-01)'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedItemId = widget.itemId;
    _repository = widget.repository ??
        (sl.isRegistered<CostRepository>()
            ? sl<CostRepository>()
            : HttpCostRepository.instance);
    _loadData();
  }

  Future<void> _loadData([String? itemId]) async {
    final targetId = itemId ?? _selectedItemId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final report = await _repository.getRecipeCost(itemId: targetId);
      if (!mounted) return;
      setState(() {
        _data = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatNumber(num value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _data == null) {
      return const RmsOpsScaffold(
        title: 'تكلفة صنف القائمة',
        showProfile: false,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (_errorMessage != null && _data == null) {
      return RmsOpsScaffold(
        title: 'تكلفة صنف القائمة',
        showProfile: false,
        children: [
          RmsOpsBanner(
            title: 'خطأ في الاتصال',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }
    return RmsOpsScaffold(
      title: 'تكلفة صنف القائمة',
      showProfile: false,
      children: [
        if (_errorMessage != null)
          RmsOpsBanner(
            title: 'تنبيه',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
      _itemSelector(),
      const SizedBox(height: 10),
      _recipeHeader(),
      const SizedBox(height: 10),
      _keyMetrics(),
      const SizedBox(height: 10),
      _targetGauge(),
      const SizedBox(height: 10),
      _ingredients(),
      const SizedBox(height: 10),
      _profitEquation(),
      const SizedBox(height: 10),
      _actions(context),
    ],
  );
  }

  Widget _itemSelector() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.fastfood, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'اختر الصنف:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _availableItems.any((it) => it['id'] == _selectedItemId)
                      ? _selectedItemId
                      : 'item_1',
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                  ),
                  items: _availableItems
                      .map(
                        (it) => DropdownMenuItem(
                          value: it['id'],
                          child: Text(
                            it['name']!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (newItem) {
                    if (newItem != null && newItem != _selectedItemId) {
                      setState(() => _selectedItemId = newItem);
                      _loadData(newItem);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );

  Widget _recipeHeader() => RmsOpsSection(
    title: '${_data!.nameAr} • ${_data!.sku}',
    icon: Icons.lunch_dining,
    child: Text('${_data!.categoryName} • ${_data!.portionSize} • زمن التحضير ${_data!.prepTime}'),
  );

  Widget _keyMetrics() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: RmsOpsMetric(
              label: 'سعر البيع المعتمد',
              value: '${_formatNumber(_data!.sellingPrice)} ج.م',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RmsOpsMetric(
              label: 'تكلفة الصنف (COGS)',
              value: '${_formatNumber(_data!.recipeCost)} ج.م',
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: RmsOpsMetric(
              label: 'إجمالي الربح',
              value: '${_formatNumber(_data!.grossProfit)} ج.م',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RmsOpsMetric(
              label: 'تكلفة الطعام',
              value: '${_data!.foodCostPercentage.toStringAsFixed(1)}%',
              color: _data!.isWithinTarget ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _targetGauge() {
    final progress = (_data!.foodCostPercentage / 100).clamp(0.0, 1.0);
    return RmsOpsSection(
      title: 'مؤشر الانحراف عن المستهدف التشغيلي',
      child: Column(
        children: [
          LinearProgressIndicator(value: progress, minHeight: 10),
          ListTile(
            title: Text('الفعلي ${_data!.foodCostPercentage.toStringAsFixed(1)}%'),
            trailing: Text('الهدف ${_data!.targetFoodCostPercentage.toStringAsFixed(1)}% • ${_data!.targetStatus}'),
          ),
        ],
      ),
    );
  }

  Widget _ingredients() {
    final list = _data!.ingredients;

    return RmsOpsSection(
      title: 'تفصيل تكلفة مكونات الوصفة (BOM)',
      icon: Icons.format_list_bulleted,
      child: Column(
        children: [
          for (int i = 0; i < list.length; i++) ...[
            RmsOpsRecord(
              title: list[i].nameAr,
              subtitle: _formatIngredientSubtitle(list[i]),
            ),
            if (i < list.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  String _formatIngredientSubtitle(RecipeIngredientData ing) {
    final qtyStr = ing.quantity % 1 == 0 ? ing.quantity.toInt().toString() : ing.quantity.toStringAsFixed(3);
    return '$qtyStr ${ing.unit} • ${_formatNumber(ing.totalCost)} ج.م';
  }

  Widget _profitEquation() => RmsOpsSection(
    title: 'معادلات التكلفة وهوامش الربحية',
    child: Column(
      children: [
        ListTile(
          title: Text('${_formatNumber(_data!.sellingPrice)} سعر البيع − ${_formatNumber(_data!.recipeCost)} تكلفة الصنف'),
          trailing: Text('${_formatNumber(_data!.grossProfit)} ج.م'),
        ),
        ListTile(
          title: Text('نسبة تكلفة الطعام • المستهدف ≤ ${_data!.targetFoodCostPercentage.toStringAsFixed(0)}%'),
          trailing: Text('${_data!.foodCostPercentage.toStringAsFixed(1)}%'),
        ),
      ],
    ),
  );

  Widget _actions(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () async {
            final targetId = _data?.itemId ?? widget.itemId;
            await context.push('/menu/edit/$targetId');
            if (mounted) {
              _loadData();
            }
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('تعديل معايير الوصفة والمكونات'),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => context.push('/pricing/history/MENU-BRG-01'),
              child: const Text('سجل التغيرات السعرية'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => _export(context),
              child: const Text('تصدير بطاقة التكلفة'),
            ),
          ),
        ],
      ),
    ],
  );

  void _export(BuildContext context) => showReportExportDialog(
        context,
        reportType: 'recipe',
        reportTitle: 'بطاقة تكلفة الوصفة (${_data?.nameAr ?? widget.itemId})',
        isCostReport: true,
      );
}
