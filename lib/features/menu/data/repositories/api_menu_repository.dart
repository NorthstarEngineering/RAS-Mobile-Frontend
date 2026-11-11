import '../../../../core/network/authenticated_api.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../domain/entities/menu_category.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/menu_item_request.dart';
import '../../domain/repositories/menu_repository.dart';

class ApiMenuRepository implements MenuRepository {
  ApiMenuRepository(this.api);
  final AuthenticatedApi api;
  static const _path = '/api/v1/menu';

  Future<UserSession> _session() async {
    final session = await api.auth.getCurrentSession();
    if (session == null) throw const FormatException('يرجى تسجيل الدخول');
    return session;
  }

  Future<String> _ceoRole() async {
    final session = await _session();
    if (session.role != StaffRole.ceo) {
      throw const FormatException('هذه العملية متاحة للمدير التنفيذي فقط');
    }
    return session.role.code.toUpperCase();
  }

  List<Map<String, dynamic>> _rows(dynamic payload) {
    if (payload is! List) {
      throw const FormatException('استجابة القائمة غير صالحة');
    }
    return payload.map(_object).toList();
  }

  Map<String, dynamic> _object(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('استجابة الخدمة غير صالحة');
    }
    return payload;
  }

  String _text(Map<String, dynamic> row, String key) {
    final field = row[key];
    if (field is! String) throw FormatException('حقل غير صالح: $key');
    return field;
  }

  String _optionalText(Map<String, dynamic> row, String key) {
    return row[key] == null ? '' : _text(row, key);
  }

  int _integer(Map<String, dynamic> row, String key) {
    final field = row[key];
    if (field is! int) throw FormatException('عدد صحيح غير صالح: $key');
    return field;
  }

  bool _active(Map<String, dynamic> row) {
    final active = row['is_active'];
    if (active is! bool) throw const FormatException('حالة الصنف غير صالحة');
    return active;
  }

  double _number(Map<String, dynamic> row, String key) {
    final field = row[key];
    if (field is! num || !field.isFinite) {
      throw FormatException('قيمة رقمية غير صالحة: $key');
    }
    return field.toDouble();
  }

  MenuItem _menuItem(Map<String, dynamic> row, List<MenuCategory> categories) {
    final categoryId = _optionalText(row, 'category_id');
    final matching = categories.where((category) => category.id == categoryId);
    return MenuItem(
      id: _text(row, 'id'),
      sku: _text(row, 'sku'),
      barcode: '',
      nameAr: _text(row, 'name'),
      nameEn: _optionalText(row, 'name_en'),
      categoryId: categoryId,
      categoryName: matching.isEmpty ? 'بدون تصنيف' : matching.first.nameAr,
      price: _number(row, 'selling_price'),
      cost: 0,
      taxRate: 0,
      isActive: _active(row),
      description: _optionalText(row, 'description'),
      kitchenStation: _optionalText(row, 'kds_station'),
      prepTimeMinutes: row['prep_time_minutes'] == null
          ? 0
          : _integer(row, 'prep_time_minutes'),
      branches: const [],
    );
  }

  @override
  Future<List<MenuItem>> getMenuItems() async {
    final rows = _rows(await api.get('$_path/items'));
    final categories = await getCategories();
    return rows.map((row) => _menuItem(row, categories)).toList();
  }

  @override
  Future<MenuItem?> getMenuItemById(String id) async {
    Map<String, dynamic> row;
    try {
      row = _object(await api.get('$_path/items/${Uri.encodeComponent(id)}'));
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
    return _menuItem(row, await getCategories());
  }

  @override
  Future<List<MenuCategory>> getCategories() async {
    final rows = _rows(await api.get('$_path/categories'));
    return rows
        .map(
          (row) => MenuCategory(
            id: _text(row, 'id'),
            nameAr: _text(row, 'name'),
            nameEn: '',
            itemsCount: 0,
            sortOrder: _integer(row, 'sort_order'),
            isActive: _active(row),
          ),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> saveMenuItem(MenuItem item) async {
    final role = await _ceoRole();
    final payload = <String, dynamic>{
      'name': item.nameAr,
      'name_en': item.nameEn,
      'category_id': item.categoryId,
      'selling_price': item.price,
      'kds_station': item.kitchenStation,
      'prep_time_minutes': item.prepTimeMinutes,
      'description': item.description,
      'actor_role': role,
    };
    if (item.id.isEmpty) {
      await api.post('$_path/items', {...payload, 'sku': item.sku});
    } else {
      await api.patch('$_path/items/${Uri.encodeComponent(item.id)}', {
        ...payload,
        'is_active': item.isActive,
      });
    }
  }

  @override
  Future<void> addCategory(MenuCategory category) async {
    await _ceoRole();
    await api.post('$_path/categories', {
      'name': category.nameAr,
      'sort_order': category.sortOrder,
    });
  }

  MenuItemRequest _menuRequest(Map<String, dynamic> row) {
    final status = _text(row, 'status').toLowerCase();
    return MenuItemRequest(
      id: _text(row, 'id'),
      requestNumber: _text(row, 'id'),
      itemNameAr: _text(row, 'item_name'),
      itemNameEn: '',
      categoryName: '',
      proposedPrice: _number(row, 'requested_price'),
      estimatedCost: 0,
      branchName: _text(row, 'branch_id'),
      requestedByName: _text(row, 'requested_by'),
      requestDate: DateTime.parse(_text(row, 'created_at')),
      status: MenuItemRequestStatus.values.firstWhere(
        (entry) => entry.name == status,
        orElse: () => throw const FormatException('حالة الطلب غير صالحة'),
      ),
      reason: _optionalText(row, 'justification'),
      notes: row['rejection_reason'] == null
          ? _optionalText(row, 'description')
          : _text(row, 'rejection_reason'),
    );
  }

  @override
  Future<List<MenuItemRequest>> getMenuItemRequests() async {
    final rows = _rows(await api.get('$_path/requests'));
    return rows.map(_menuRequest).toList();
  }

  @override
  Future<MenuItemRequest?> getMenuItemRequestById(String id) async {
    final requests = await getMenuItemRequests();
    final matching = requests.where((request) => request.id == id);
    return matching.isEmpty ? null : matching.first;
  }

  @override
  Future<void> createMenuItemRequest(MenuRequestDraft draft) async {
    final session = await _session();
    if (session.role != StaffRole.branchManager || session.branchId.isEmpty) {
      throw const FormatException('الطلب يحتاج حساب مدير فرع مرتبط بفرع');
    }
    await api.post('$_path/requests', {
      'branch_id': session.branchId,
      'item_name': draft.name,
      'requested_price': draft.price,
      'description': draft.description,
      'justification': draft.justification,
    });
  }

  @override
  Future<void> approveMenuItemRequest(String requestId, String sku) async {
    await api.patch(
      '$_path/requests/${Uri.encodeComponent(requestId)}/approve',
      {'sku': sku, 'actor_role': await _ceoRole()},
    );
  }

  @override
  Future<void> rejectMenuItemRequest(String requestId, String reason) async {
    await api.patch(
      '$_path/requests/${Uri.encodeComponent(requestId)}/reject',
      {'reason': reason, 'actor_role': await _ceoRole()},
    );
  }
}
