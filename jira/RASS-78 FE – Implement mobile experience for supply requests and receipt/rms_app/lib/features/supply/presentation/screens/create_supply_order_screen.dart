import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_supply_repository.dart';
import '../../domain/repositories/supply_repository.dart';

class CreateSupplyOrderScreen extends StatefulWidget {
  const CreateSupplyOrderScreen({super.key, this.repository});

  final SupplyRepository? repository;

  @override
  State<CreateSupplyOrderScreen> createState() =>
      _CreateSupplyOrderScreenState();
}

class _CreateSupplyOrderScreenState extends State<CreateSupplyOrderScreen> {
  late final SupplyRepository _repository;
  late final ApiClient _apiClient;
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  String _branch = 'فرع وسط البلد (#01)';
  String _item = 'لحم بقري مفروم (خام)';
  int _quantity = 40;
  bool _urgent = true;

  List<Map<String, String>> _branchChoices = const [
    {'id': 'br_01', 'name': 'فرع وسط البلد (#01)'},
    {'id': 'br_02', 'name': 'فرع المعادي (#02)'},
    {'id': 'br_03', 'name': 'فرع التجمع الخامس (#03)'},
    {'id': 'br_04', 'name': 'المطبخ المركزي ومستودع الإمداد (#04)'},
  ];

  List<Map<String, String>> _itemChoices = const [
    {'id': 'stock_ck_01', 'name': 'لحم بقري مفروم (خام)'},
    {'id': 'stock_ck_chick', 'name': 'صدور دجاج فيليه'},
    {'id': 'stock_ck_02', 'name': 'زيت قلي نباتي'},
    {'id': 'stock_ck_06', 'name': 'خبز بريوش طازج'},
    {'id': 'stock_ck_05', 'name': 'بطاطس نصف مقلية فاخرة'},
    {'id': 'stock_ck_04', 'name': 'جبنة شيدر معتقة شرائح'},
    {'id': 'stock_ck_03', 'name': 'صلصة البرجر السرية الخاصة'},
  ];

  @override
  void initState() {
    super.initState();
    _apiClient = sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient();
    _repository = widget.repository ??
        (sl.isRegistered<SupplyRepository>()
            ? sl<SupplyRepository>()
            : HttpSupplyRepository(apiClient: _apiClient));
    _fetchDynamicChoices();
  }

  Future<void> _fetchDynamicChoices() async {
    try {
      final branchRes = await _apiClient.get('/branches');
      if (mounted && branchRes.success && branchRes.data is List) {
        final rawList = branchRes.data as List;
        final fetchedBranches = rawList.whereType<Map>().map((b) {
          final id = b['id']?.toString() ?? '';
          final nameAr = b['name_ar']?.toString() ?? b['name']?.toString() ?? id;
          final code = b['code']?.toString() ?? '';
          final displayName = code.isNotEmpty ? '$nameAr (#$code)' : nameAr;
          return {'id': id, 'name': displayName};
        }).where((b) => b['id']!.isNotEmpty).toList();

        if (fetchedBranches.isNotEmpty) {
          setState(() {
            _branchChoices = fetchedBranches;
            if (!_branchChoices.any((b) => b['name'] == _branch)) {
              _branch = _branchChoices.first['name']!;
            }
          });
        }
      }
    } catch (_) {}

    try {
      final itemsRes = await _apiClient.get('/kitchen/items');
      if (mounted && itemsRes.success && itemsRes.data is List) {
        final rawItems = itemsRes.data as List;
        final fetchedItems = rawItems.whereType<Map>().map((it) {
          final id = it['id']?.toString() ?? it['stock_item_id']?.toString() ?? '';
          final name = it['name']?.toString() ?? it['item_name']?.toString() ?? id;
          return {'id': id, 'name': name};
        }).where((it) => it['id']!.isNotEmpty).toList();

        if (fetchedItems.isNotEmpty) {
          setState(() {
            _itemChoices = fetchedItems;
            if (!_itemChoices.any((i) => i['name'] == _item)) {
              _item = _itemChoices.first['name']!;
            }
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'إنشاء طلب توريد',
    showProfile: false,
    children: [
      const RmsOpsBanner(
        title: 'طلب توريد من المطبخ المركزي',
        message:
            'حدد الفرع والأصناف والكميات المطلوبة، وسيتم مراجعة الطلب قبل التجهيز.',
      ),
      const SizedBox(height: 12),
      _branchField(),
      const SizedBox(height: 12),
      _itemField(),
      const SizedBox(height: 12),
      _quantityField(),
      const SizedBox(height: 12),
      _priorityField(),
      const SizedBox(height: 12),
      _reasonField(),
      const SizedBox(height: 14),
      RmsPrimaryButton(
        label: 'إرسال طلب التوريد للمراجعة',
        icon: Icons.send_outlined,
        onPressed: _submit,
      ),
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('إلغاء وتراجع'),
      ),
    ],
  );

  Widget _branchField() {
    final options = _branchChoices.map((b) => b['name']!).toList();
    final effectiveValue = options.contains(_branch) ? _branch : options.first;
    return _selectField(
      'الفرع المستلم',
      effectiveValue,
      options,
      (value) => setState(() => _branch = value!),
    );
  }

  Widget _itemField() {
    final options = _itemChoices.map((i) => i['name']!).toList();
    final effectiveValue = options.contains(_item) ? _item : options.first;
    return _selectField(
      'الصنف المطلوب',
      effectiveValue,
      options,
      (value) => setState(() => _item = value!),
    );
  }

  Widget _selectField(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    isExpanded: true,
    value: value,
    decoration: InputDecoration(labelText: label),
    items: options
        .map(
          (option) => DropdownMenuItem(
            value: option,
            child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );

  Widget _quantityField() => RmsOpsSection(
    title: 'الكمية المطلوبة • كجم',
    child: Row(
      children: [
        IconButton(
          onPressed: () =>
              setState(() => _quantity = (_quantity - 5).clamp(5, 500)),
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: Text(
            '$_quantity كجم',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _quantity += 5),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );

  Widget _priorityField() => SwitchListTile(
    value: _urgent,
    onChanged: (value) => setState(() => _urgent = value),
    title: const Text('أولوية تشغيل عاجلة'),
    subtitle: const Text('يحتاج الفرع إلى هذه الخامات خلال الوردية الحالية'),
  );

  Widget _reasonField() => TextField(
    controller: _reasonController,
    maxLines: 3,
    decoration: const InputDecoration(
      labelText: 'سبب طلب التوريد',
      hintText: 'اكتب سبب الطلب لدعم المراجعة',
    ),
  );

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    // Resolve matching branch ID
    final matchedBranch = _branchChoices.firstWhere(
      (b) => b['name'] == _branch,
      orElse: () => {'id': HttpSupplyRepository.resolveBranchId(_branch), 'name': _branch},
    );
    final destinationBranchId = matchedBranch['id'];

    // Resolve matching item ID
    final matchedItem = _itemChoices.firstWhere(
      (i) => i['name'] == _item,
      orElse: () => {'id': HttpSupplyRepository.resolveStockItemId(_item), 'name': _item},
    );
    final stockItemId = matchedItem['id']!;

    try {
      final order = await _repository.createSupplyOrder(
        branch: _branch,
        destinationBranchId: destinationBranchId,
        item: _item,
        quantity: _quantity,
        urgent: _urgent,
        reason: _reasonController.text.trim(),
        items: [
          SupplyOrderItem(
            id: '',
            stockItemId: stockItemId,
            name: _item,
            requestedQuantity: _quantity.toDouble(),
            unit: 'كجم',
          ),
        ],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء طلب التوريد رقم ${order.orderNumber.isNotEmpty ? order.orderNumber : order.id} بنجاح',
            ),
          ),
        );
        Navigator.of(context).maybePop(order);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء طلب التوريد: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
