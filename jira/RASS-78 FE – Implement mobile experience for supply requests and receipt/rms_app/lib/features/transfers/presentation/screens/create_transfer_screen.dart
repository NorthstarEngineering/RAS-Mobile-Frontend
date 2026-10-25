import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_transfers_repository.dart';
import '../../domain/repositories/transfers_repository.dart';

class CreateTransferScreen extends StatefulWidget {
  const CreateTransferScreen({super.key});
  @override
  State<CreateTransferScreen> createState() => _CreateTransferScreenState();
}

class _CreateTransferScreenState extends State<CreateTransferScreen> {
  String _sourceBranchId = 'br_01';
  String _sourceBranchName = 'فرع وسط البلد (#01)';
  String _destinationBranchId = 'br_02';
  String _destinationBranchName = 'فرع المعادي (#02)';

  String _selectedItemName = 'لحم بقري مفروم (خام)';
  String? _selectedStockItemId;
  String _selectedUnit = 'كجم';
  double _availableSourceStock = 85.0;
  double _safetyStock = 25.0;

  int _quantity = 5;
  bool _urgent = true;
  bool _isSubmitting = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _items = [];

  final TextEditingController _notesController = TextEditingController();

  TransfersRepository get _repository {
    if (sl.isRegistered<TransfersRepository>()) {
      return sl<TransfersRepository>();
    }
    return HttpTransfersRepository.instance;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final branches = await _repository.getBranches();
      if (mounted && branches.isNotEmpty) {
        setState(() {
          _branches = branches;
          _sourceBranchId = branches[0]['id'].toString();
          _sourceBranchName = branches[0]['name_ar'].toString();
          if (branches.length > 1) {
            _destinationBranchId = branches[1]['id'].toString();
            _destinationBranchName = branches[1]['name_ar'].toString();
          }
        });
      }
      await _loadBranchItems(_sourceBranchId);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBranchItems(String branchId) async {
    try {
      final items = await _repository.getAvailableItems(branchId: branchId);
      if (mounted) {
        setState(() {
          _items = items;
          if (items.isNotEmpty) {
            final first = items[0];
            _selectedItemName = (first['name'] ?? 'صنف').toString();
            _selectedStockItemId = first['id']?.toString();
            _selectedUnit = (first['unit'] ?? 'كجم').toString();
            final q = first['quantity'];
            _availableSourceStock = (q is num) ? q.toDouble() : double.tryParse(q.toString()) ?? 0.0;
            final s = first['safety_stock'];
            _safetyStock = (s is num) ? s.toDouble() : double.tryParse(s.toString()) ?? 0.0;
            _quantity = (_availableSourceStock >= 5) ? 5 : (_availableSourceStock > 0 ? _availableSourceStock.toInt() : 1);
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const RmsOpsScaffold(
        title: 'إنشاء تحويل',
        showProfile: false,
        children: [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ],
      );
    }

    return RmsOpsScaffold(
      title: 'إنشاء تحويل',
      showProfile: false,
      children: [
        const RmsOpsBanner(
          title: 'سياسة التحويلات اللحظية',
          message:
              'التحويلات بين الفروع تخضع لموازنة المخزون وتغطية الحد الأدنى، مع موافقة مدير الفرع المصدر.',
        ),
        const SizedBox(height: 12),
        _routeSection(),
        const SizedBox(height: 12),
        _itemSection(),
        const SizedBox(height: 12),
        _prioritySection(),
        const SizedBox(height: 12),
        _impactPreview(),
        const SizedBox(height: 12),
        RmsPrimaryButton(
          label: 'إرسال طلب التحويل للمراجعة والاعتماد',
          icon: Icons.send_outlined,
          onPressed: _submit,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('إلغاء وتراجع'),
        ),
      ],
    );
  }

  Widget _routeSection() {
    final destBranches = _branches.where((b) => b['id'].toString() != _sourceBranchId).toList();

    return RmsOpsSection(
      title: 'تحديد مسار التحويل',
      icon: Icons.swap_horiz,
      child: Column(
        children: [
          ListTile(
            title: const Text('الفرع المصدر (المحول منه)'),
            subtitle: Text('$_sourceBranchName • المخزون التشغيلي'),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: destBranches.isNotEmpty ? _destinationBranchId : null,
            decoration: const InputDecoration(
              labelText: 'الفرع المستلم (المحول إليه)',
            ),
            items: destBranches.map((branch) {
              final id = branch['id'].toString();
              final name = branch['name_ar'].toString();
              return DropdownMenuItem<String>(
                value: id,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                final found = destBranches.firstWhere((b) => b['id'].toString() == val, orElse: () => {});
                setState(() {
                  _destinationBranchId = val;
                  if (found.isNotEmpty) _destinationBranchName = found['name_ar'].toString();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _itemSection() => RmsOpsSection(
    title: 'الصنف والكمية المنقولة',
    icon: Icons.inventory_2_outlined,
    child: Column(
      children: [
        if (_items.isNotEmpty)
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedStockItemId ?? (_items.isNotEmpty ? _items[0]['id'].toString() : null),
            decoration: const InputDecoration(labelText: 'الصنف المطلوب تحويله'),
            items: _items.map((itm) {
              final id = itm['id'].toString();
              final name = itm['name'].toString();
              final q = itm['quantity'];
              final u = itm['unit'] ?? 'وحدة';
              return DropdownMenuItem<String>(
                value: id,
                child: Text(
                  '$name (المتاح: $q $u)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                final itm = _items.firstWhere((e) => e['id'].toString() == val, orElse: () => {});
                if (itm.isNotEmpty) {
                  setState(() {
                    _selectedStockItemId = val;
                    _selectedItemName = itm['name'].toString();
                    _selectedUnit = (itm['unit'] ?? 'كجم').toString();
                    final q = itm['quantity'];
                    _availableSourceStock = (q is num) ? q.toDouble() : double.tryParse(q.toString()) ?? 0.0;
                    final s = itm['safety_stock'];
                    _safetyStock = (s is num) ? s.toDouble() : double.tryParse(s.toString()) ?? 0.0;
                    if (_quantity > _availableSourceStock.toInt()) {
                      _quantity = _availableSourceStock.toInt() > 0 ? _availableSourceStock.toInt() : 1;
                    }
                  });
                }
              }
            },
          )
        else
          ListTile(
            title: Text(_selectedItemName),
            subtitle: const Text('لا توجد أصناف أخرى متاحة للتحويل بهذا الفرع'),
          ),
        const SizedBox(height: 8),
        RmsOpsMetric(
          label: 'رصيد المصدر الحقيقي',
          value: '$_availableSourceStock $_selectedUnit • حد الأمان $_safetyStock $_selectedUnit',
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => setState(
                () => _quantity = (_quantity - 1).clamp(1, _availableSourceStock.toInt() > 0 ? _availableSourceStock.toInt() : 1),
              ),
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Text(
                '$_quantity $_selectedUnit',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(
                () => _quantity = (_quantity + 1).clamp(1, _availableSourceStock.toInt() > 0 ? _availableSourceStock.toInt() : 100),
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _prioritySection() => RmsOpsSection(
    title: 'أولوية التحويل ومبرره',
    child: Column(
      children: [
        SwitchListTile(
          value: _urgent,
          onChanged: (value) => setState(() => _urgent = value),
          title: const Text('أولوية قصوى (عاجل)'),
        ),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'سبب التحويل التشغيلي'),
        ),
      ],
    ),
  );

  Widget _impactPreview() {
    final remain = (_availableSourceStock - _quantity).clamp(0.0, 999999.0);
    return RmsOpsBanner(
      title: 'الأثر التقديري بعد الاعتماد',
      message:
          'رصيد المصدر بعد التحويل: $remain $_selectedUnit • المستلم: $_quantity $_selectedUnit',
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final order = await _repository.createTransfer(
        sourceBranch: _sourceBranchName,
        sourceBranchId: _sourceBranchId,
        destinationBranch: _destinationBranchName,
        destinationBranchId: _destinationBranchId,
        item: _selectedItemName,
        stockItemId: _selectedStockItemId,
        quantity: _quantity.toDouble(),
        isUrgent: _urgent,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء طلب التحويل ${order.id} بنجاح')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إنشاء التحويل: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
