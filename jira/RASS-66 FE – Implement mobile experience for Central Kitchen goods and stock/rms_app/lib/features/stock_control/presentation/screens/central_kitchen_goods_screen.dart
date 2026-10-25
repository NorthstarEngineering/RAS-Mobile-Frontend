import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/http_central_kitchen_repository.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/repositories/central_kitchen_repository.dart';
import '../widgets/stock_widgets.dart';

class CentralKitchenGoodsScreen extends StatefulWidget {
  const CentralKitchenGoodsScreen({
    super.key,
    this.repository,
  });

  final CentralKitchenRepository? repository;

  @override
  State<CentralKitchenGoodsScreen> createState() =>
      _CentralKitchenGoodsScreenState();
}

class _CentralKitchenGoodsScreenState extends State<CentralKitchenGoodsScreen> {
  late final CentralKitchenRepository _repository;
  String _category = 'الكل';
  String _status = 'الكل';
  String _query = '';

  List<StockItem> _allItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<CentralKitchenRepository>()
            ? sl<CentralKitchenRepository>()
            : HttpCentralKitchenRepository(
                apiClient:
                    sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null,
              ));
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repository.getItems(
        category: _category != 'الكل' ? _category : null,
        status: _status != 'الكل' ? _status : null,
        query: _query.isNotEmpty ? _query : null,
      );
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'أصناف المطبخ المركزي',
    tab: 1,
    child: RefreshIndicator(
      onRefresh: _loadItems,
      child: StockScrollBody(
        children: [
          _heading(context),
          const SizedBox(height: 12),
          _summary(),
          const SizedBox(height: 12),
          _search(),
          const SizedBox(height: 8),
          _categoryFilters(),
          _statusFilters(),
          const SizedBox(height: 8),
          _itemList(context),
        ],
      ),
    ),
  );

  Widget _heading(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'خامات المستودع الرئيسي',
          style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      IconButton.filled(
        onPressed: () async {
          await context.push('/kitchen/items/create');
          _loadItems();
        },
        icon: const Icon(Icons.add),
      ),
    ],
  );

  Widget _summary() {
    final total = _allItems.length;
    final critical =
        _allItems.where((i) => i.level == StockLevel.critical).length;
    final low = _allItems.where((i) => i.level == StockLevel.low).length;

    return Row(
      children: [
        Expanded(
          child: StockMetricCard(
            label: 'إجمالي الأصناف',
            value: _isLoading ? '...' : '$total',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StockMetricCard(
            label: 'حرج ونفاد',
            value: _isLoading ? '...' : '$critical',
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StockMetricCard(
            label: 'تحت الطلب',
            value: _isLoading ? '...' : '$low',
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _search() => TextField(
    onChanged: (query) {
      setState(() => _query = query.trim().toLowerCase());
      _loadItems();
    },
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.search),
      hintText: 'ابحث باسم الصنف أو الكود',
    ),
  );

  Widget _categoryFilters() => StockFilterChips(
    labels: const [
      'الكل',
      'لحوم ودواجن',
      'زيوت ودهون',
      'صوصات مركزية',
      'مخبوزات',
      'ألبان وخامات',
    ],
    selected: _category,
    onSelected: (category) {
      setState(() => _category = category);
      _loadItems();
    },
  );

  Widget _statusFilters() => StockFilterChips(
    labels: const ['الكل', 'متوفر', 'مخزون منخفض', 'حرج'],
    selected: _status,
    onSelected: (status) {
      setState(() => _status = status);
      _loadItems();
    },
  );

  Widget _itemList(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final items = _allItems.where(_matchesFilters).toList();
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(
          child: Text(
            'لا توجد أصناف مسجلة في المستودع المركزي',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondary),
          ),
        ),
      );
    }
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: StockItemCard(
                item: item,
                onTap: () async {
                  await context.push('/kitchen/items/\${item.id}');
                  _loadItems();
                },
              ),
            ),
          )
          .toList(),
    );
  }

  bool _matchesFilters(StockItem item) {
    final matchesCategory = _category == 'الكل' || item.category == _category;
    final matchesStatus =
        _status == 'الكل' || _statusFor(item.level) == _status;
    final matchesQuery =
        _query.isEmpty ||
        item.name.toLowerCase().contains(_query) ||
        item.sku.toLowerCase().contains(_query);
    return matchesCategory && matchesStatus && matchesQuery;
  }

  String _statusFor(StockLevel level) => switch (level) {
    StockLevel.critical => 'حرج',
    StockLevel.low => 'مخزون منخفض',
    StockLevel.available => 'متوفر',
  };
}
