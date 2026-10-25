import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/repositories/http_inventory_repository.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../widgets/stock_widgets.dart';

class BranchOption {
  const BranchOption({
    required this.id,
    required this.code,
    required this.name,
    required this.subtitle,
  });

  final String id;
  final String code;
  final String name;
  final String subtitle;
}

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({
    super.key,
    this.repository,
    this.initialBranchId = 'br_01',
  });

  final InventoryRepository? repository;
  final String initialBranchId;

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  late final InventoryRepository _repository;

  late String _selectedBranchId;
  String _category = 'الكل';
  String _status = 'الكل';
  String _query = '';
  bool _isLoading = true;
  bool _isOnline = false;

  List<BranchOption> _branchOptions = [];
  List<StockItem> _items = [];

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.initialBranchId;
    _repository = widget.repository ??
        (sl.isRegistered<InventoryRepository>()
            ? sl<InventoryRepository>()
            : HttpInventoryRepository());
    _loadBranches();
    _loadItems();
  }

  Future<void> _loadBranches() async {
    try {
      final rawList = await _repository.getBranches();
      if (rawList.isNotEmpty && mounted) {
        final options = rawList.map((m) {
          final id = m['id']?.toString() ?? '';
          final code = m['code']?.toString() ?? id.toUpperCase();
          final name = m['nameAr']?.toString() ??
              m['name_ar']?.toString() ??
              m['name']?.toString() ??
              id;
          final address = m['address']?.toString() ?? '';
          final type = m['type']?.toString() ?? '';
          final subtitle = address.isNotEmpty
              ? address
              : (type == 'kitchen'
                  ? 'المطبخ المركزي ومستودع الإمداد'
                  : 'نطاق المخزون التشغيلي');
          return BranchOption(
            id: id,
            code: code,
            name: name,
            subtitle: subtitle,
          );
        }).toList();

        setState(() {
          _branchOptions = options;
          if (!_branchOptions.any((b) => b.id == _selectedBranchId)) {
            if (_branchOptions.isNotEmpty) {
              _selectedBranchId = _branchOptions.first.id;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repository.getInventoryItems(
        branchId: _selectedBranchId,
        category: _category != 'الكل' ? _category : null,
        stockLevel: _status != 'الكل' ? _status : null,
        query: _query.isNotEmpty ? _query : null,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
          _isOnline = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOnline = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => StockPageShell(
        title: 'مخزون الفرع',
        tab: 3,
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadBranches();
            await _loadItems();
          },
          child: StockScrollBody(
            children: [
              _branchHeader(),
              const SizedBox(height: 12),
              _summary(context),
              const SizedBox(height: 12),
              _search(),
              StockFilterChips(
                labels: const [
                  'الكل',
                  'لحوم ودواجن',
                  'أجبان وألبان',
                  'صلصات وزيوت',
                  'مخبوزات',
                  'مجمدات',
                ],
                selected: _category,
                onSelected: (value) {
                  setState(() => _category = value);
                  _loadItems();
                },
              ),
              StockFilterChips(
                labels: const ['الكل', 'حرج', 'مخزون منخفض', 'متوفر'],
                selected: _status,
                onSelected: (value) {
                  setState(() => _status = value);
                  _loadItems();
                },
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _itemsList(context),
              const SizedBox(height: 12),
              _footerNotice(),
            ],
          ),
        ),
      );

  Widget _branchHeader() {
    final current = _branchOptions.firstWhere(
      (b) => b.id == _selectedBranchId,
      orElse: () => BranchOption(
        id: _selectedBranchId,
        code: _selectedBranchId.toUpperCase(),
        name: 'الفرع ($_selectedBranchId)',
        subtitle: 'نطاق المخزون التشغيلي المعتمد',
      ),
    );

    final options = _branchOptions.isNotEmpty
        ? _branchOptions
        : [current];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingMd,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  current.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: options.any((b) => b.id == _selectedBranchId)
                        ? _selectedBranchId
                        : options.first.id,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                    ),
                    items: options.map((b) {
                      return DropdownMenuItem<String>(
                        value: b.id,
                        child: Text(
                          b.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (newBranchId) {
                      if (newBranchId != null &&
                          newBranchId != _selectedBranchId) {
                        setState(() {
                          _selectedBranchId = newBranchId;
                        });
                        _loadItems();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            current.subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final totalBookValue = _items.fold<double>(
      0.0,
      (acc, item) => acc + item.totalValue,
    );
    final criticalCount =
        _items.where((i) => i.level == StockLevel.critical).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StockMetricCard(
                label: 'إجمالي الأصناف',
                value: _isLoading ? '...' : '${_items.length} صنف',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StockMetricCard(
                label: 'أصناف حرجة',
                value: _isLoading ? '...' : '$criticalCount',
                color: criticalCount > 0 ? AppColors.error : AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StockMetricCard(
                label: 'القيمة الدفترية',
                value: _isLoading ? '...' : '${_fmtMoney(totalBookValue)} ج.م',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/inventory/value?branch_id=$_selectedBranchId'),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('تقييم المخزون'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _search() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          onChanged: (value) {
            setState(() => _query = value.trim().toLowerCase());
            _loadItems();
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث باسم الصنف أو الكود',
          ),
        ),
      );

  Widget _itemsList(BuildContext context) {
    final visibleItems = _items.where(_matchesLocal).toList();
    if (visibleItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(
          child: Text(
            'لا توجد أصناف مسجلة في هذا الفرع وفق معايير التصفية المحددة',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondary),
          ),
        ),
      );
    }
    return Column(
      children: visibleItems
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StockItemCard(
                item: item,
                onTap: () async {
                  await context.push('/inventory/${item.id}?branch_id=$_selectedBranchId');
                  if (mounted) _loadItems();
                },
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _footerNotice() => Text(
        'معروض ${_items.where(_matchesLocal).length} صنف • ${_isOnline ? "متصل بالخادم الموحد (بيانات حية من قاعدة البيانات)" : "البيانات مسجلة محلياً"}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.secondary),
      );

  bool _matchesLocal(StockItem item) {
    final categoryMatches = _category == 'الكل' || item.category == _category;
    final statusMatches =
        _status == 'الكل' || _statusFor(item.level) == _status;
    final queryMatches = _query.isEmpty ||
        item.name.toLowerCase().contains(_query) ||
        item.sku.toLowerCase().contains(_query);
    return categoryMatches && statusMatches && queryMatches;
  }

  String _statusFor(StockLevel level) => switch (level) {
        StockLevel.critical => 'حرج',
        StockLevel.low => 'مخزون منخفض',
        StockLevel.available => 'متوفر',
      };

  String _fmtMoney(double amount) {
    if (amount >= 1000) {
      return amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return amount.toStringAsFixed(1);
  }
}
