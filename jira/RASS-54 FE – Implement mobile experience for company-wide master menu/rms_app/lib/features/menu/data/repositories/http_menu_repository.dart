import '../../../../core/network/api_client.dart';
import '../../domain/entities/menu_category.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/menu_item_request.dart';
import '../../domain/repositories/menu_repository.dart';

class HttpMenuRepository implements MenuRepository {
  HttpMenuRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // Local cache updated ONLY on confirmed API success
  final List<MenuItem> _cachedItems = [];
  final List<MenuCategory> _cachedCategories = [];
  final List<MenuItemRequest> _cachedRequests = [];

  @override
  Future<List<MenuItem>> getMenuItems() async {
    try {
      final res = await _apiClient.get('/menu/items');
      if (res.success && res.data is List) {
        final list = (res.data as List).map((json) {
          final m = json as Map<String, dynamic>;
          return _mapJsonToMenuItem(m);
        }).toList();
        _cachedItems
          ..clear()
          ..addAll(list);
        return List.unmodifiable(_cachedItems);
      }
    } catch (e) {
      if (_cachedItems.isNotEmpty) {
        return List.unmodifiable(_cachedItems);
      }
      rethrow;
    }
    return List.unmodifiable(_cachedItems);
  }

  @override
  Future<MenuItem?> getMenuItemById(String id) async {
    try {
      final res = await _apiClient.get('/menu/items/$id');
      if (res.success && res.data is Map<String, dynamic>) {
        final item = _mapJsonToMenuItem(res.data as Map<String, dynamic>);
        return item;
      }
    } catch (_) {}
    try {
      return _cachedItems.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MenuCategory>> getCategories() async {
    try {
      final res = await _apiClient.get('/menu/categories');
      if (res.success && res.data is List) {
        final list = (res.data as List).map((json) {
          final m = json as Map<String, dynamic>;
          return MenuCategory(
            id: m['id'] as String,
            nameAr: m['nameAr'] as String,
            nameEn: m['nameEn'] as String,
            itemsCount: (m['itemsCount'] as num?)?.toInt() ?? 0,
            sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
            isActive: m['isActive'] as bool? ?? true,
          );
        }).toList();
        _cachedCategories
          ..clear()
          ..addAll(list);
        return List.unmodifiable(_cachedCategories);
      }
    } catch (e) {
      if (_cachedCategories.isNotEmpty) {
        return List.unmodifiable(_cachedCategories);
      }
      rethrow;
    }
    return List.unmodifiable(_cachedCategories);
  }

  @override
  Future<void> addMenuItem(MenuItem item) async {
    final payload = {
      'id': item.id,
      'sku': item.sku,
      'barcode': item.barcode,
      'nameAr': item.nameAr,
      'nameEn': item.nameEn,
      'categoryId': item.categoryId,
      'categoryName': item.categoryName,
      'price': item.price,
      'cost': item.cost,
      'kitchenStation': item.kitchenStation,
      'isActive': item.isActive,
      'description': item.description,
      'branches': item.branches,
      'allergens': item.allergens,
    };
    final res = await _apiClient.post('/menu/items', body: payload);
    if (!res.success) {
      throw NetworkException(res.message ?? 'فشل إضافة الصنف');
    }
    final index = _cachedItems.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _cachedItems[index] = item;
    } else {
      _cachedItems.add(item);
    }
  }

  @override
  Future<void> saveMenuItem(MenuItem item) async {
    final payload = {
      'id': item.id,
      'sku': item.sku,
      'barcode': item.barcode,
      'nameAr': item.nameAr,
      'nameEn': item.nameEn,
      'categoryId': item.categoryId,
      'categoryName': item.categoryName,
      'price': item.price,
      'cost': item.cost,
      'kitchenStation': item.kitchenStation,
      'isActive': item.isActive,
      'description': item.description,
      'branches': item.branches,
      'allergens': item.allergens,
    };

    bool exists = _cachedItems.any((i) => i.id == item.id);
    if (!exists) {
      final remote = await _checkRemoteItemExists(item.id);
      if (remote) {
        exists = true;
      }
    }

    if (exists) {
      final res = await _apiClient.put('/menu/items/${item.id}', body: payload);
      if (!res.success) {
        throw NetworkException(res.message ?? 'فشل تعديل الصنف');
      }
    } else {
      final res = await _apiClient.post('/menu/items', body: payload);
      if (!res.success) {
        throw NetworkException(res.message ?? 'فشل إضافة الصنف');
      }
    }

    final index = _cachedItems.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _cachedItems[index] = item;
    } else {
      _cachedItems.add(item);
    }
  }

  Future<bool> _checkRemoteItemExists(String id) async {
    try {
      final res = await _apiClient.get('/menu/items/$id');
      return res.success && res.data != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    final res = await _apiClient.delete('/menu/items/$id');
    if (!res.success) {
      throw NetworkException(res.message ?? 'Failed to delete menu item $id');
    }
    _cachedItems.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> addCategory(MenuCategory category) async {
    final payload = {
      'id': category.id,
      'nameAr': category.nameAr,
      'nameEn': category.nameEn,
      'sortOrder': category.sortOrder,
      'isActive': category.isActive,
    };
    final res = await _apiClient.post('/menu/categories', body: payload);
    if (!res.success) {
      throw NetworkException(res.message ?? 'فشل إضافة الفئة');
    }
    _cachedCategories.add(category);
  }

  @override
  Future<void> updateCategory(MenuCategory category) async {
    final payload = {
      'nameAr': category.nameAr,
      'nameEn': category.nameEn,
      'sortOrder': category.sortOrder,
      'isActive': category.isActive,
    };
    final res = await _apiClient.put('/menu/categories/${category.id}', body: payload);
    if (!res.success) {
      throw NetworkException(res.message ?? 'فشل تحديث الفئة');
    }
    final index = _cachedCategories.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      _cachedCategories[index] = category;
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    final res = await _apiClient.delete('/menu/categories/$id');
    if (!res.success) {
      throw NetworkException(res.message ?? 'فشل حذف الفئة');
    }
    _cachedCategories.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> updateCategoryOrder(List<MenuCategory> categories) async {
    final payload = categories.asMap().entries.map((entry) {
      return {
        'id': entry.value.id,
        'sortOrder': entry.key + 1,
      };
    }).toList();
    final res = await _apiClient.put('/menu/categories/reorder', body: payload);
    if (!res.success) {
      throw NetworkException(res.message ?? 'فشل تحديث ترتيب الفئات');
    }
    _cachedCategories
      ..clear()
      ..addAll(categories);
  }

  @override
  Future<List<MenuItemRequest>> getMenuItemRequests() async {
    try {
      final res = await _apiClient.get('/menu/requests');
      if (res.success && res.data is List) {
        final list = (res.data as List).map((json) {
          final m = json as Map<String, dynamic>;
          return _mapJsonToMenuItemRequest(m);
        }).toList();
        _cachedRequests
          ..clear()
          ..addAll(list);
        return List.unmodifiable(_cachedRequests);
      }
    } catch (e) {
      if (_cachedRequests.isNotEmpty) {
        return List.unmodifiable(_cachedRequests);
      }
      rethrow;
    }
    return List.unmodifiable(_cachedRequests);
  }

  @override
  Future<MenuItemRequest?> getMenuItemRequestById(String id) async {
    try {
      final res = await _apiClient.get('/menu/requests/$id');
      if (res.success && res.data is Map<String, dynamic>) {
        return _mapJsonToMenuItemRequest(res.data as Map<String, dynamic>);
      }
    } catch (_) {}
    try {
      return _cachedRequests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> createMenuItemRequest(MenuItemRequest request) async {
    final payload = {
      'id': request.id,
      'nameAr': request.itemNameAr,
      'nameEn': request.itemNameEn,
      'categoryId': request.categoryId,
      'categoryName': request.categoryName,
      'branchId': request.branchId,
      'proposedPrice': request.proposedPrice,
      'estimatedCost': request.estimatedCost,
      'reason': request.reason,
      'notes': request.notes,
    };
    final res = await _apiClient.post('/menu/requests', body: payload);
    if (!res.success) {
      throw NetworkException(res.message ?? 'فشل إنشاء طلب الصنف');
    }
    _cachedRequests.insert(0, request);
  }

  @override
  Future<void> reviewMenuItemRequest({
    required String requestId,
    required bool isApproved,
    String? note,
    String? categoryId,
  }) async {
    final action = isApproved ? 'approve' : 'reject';
    final payload = <String, dynamic>{
      'reviewNotes': note ?? (isApproved ? 'معتمد من الإدارة التنفيذية' : 'مرفوض من الإدارة التنفيذية'),
      'status': isApproved ? 'approved' : 'rejected',
    };
    if (categoryId != null && categoryId.isNotEmpty) {
      payload['categoryId'] = categoryId;
    }
    final res = await _apiClient.post('/menu/requests/$requestId/$action', body: payload);
    if (!res.success) {
      throw NetworkException(res.message ?? 'فشل مراجعة طلب الصنف');
    }
    final index = _cachedRequests.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      final old = _cachedRequests[index];
      _cachedRequests[index] = old.copyWith(
        status: isApproved ? MenuItemRequestStatus.approved : MenuItemRequestStatus.rejected,
        notes: note ?? old.notes,
      );
    }
  }

  MenuItemRequest _mapJsonToMenuItemRequest(Map<String, dynamic> m) {
    MenuItemRequestStatus status = MenuItemRequestStatus.pending;
    final statusStr = (m['status'] as String? ?? 'pending').toLowerCase();
    if (statusStr == 'approved') {
      status = MenuItemRequestStatus.approved;
    } else if (statusStr == 'rejected') {
      status = MenuItemRequestStatus.rejected;
    }

    DateTime requestDate;
    try {
      requestDate = DateTime.parse(m['requestDate'] as String);
    } catch (_) {
      requestDate = DateTime.now();
    }

    return MenuItemRequest(
      id: m['id'] as String,
      requestNumber: m['requestNumber'] as String? ?? 'REQ-${(m['id'] as String).substring(0, 8)}',
      itemNameAr: m['itemNameAr'] as String? ?? '',
      itemNameEn: m['itemNameEn'] as String? ?? '',
      categoryId: m['categoryId'] as String?,
      categoryName: m['categoryName'] as String? ?? 'عام',
      proposedPrice: (m['proposedPrice'] as num?)?.toDouble() ?? 0.0,
      estimatedCost: (m['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      branchId: m['branchId'] as String?,
      branchName: m['branchName'] as String? ?? 'الفرع الرئيسي',
      requestedByName: m['requestedByName'] as String? ?? 'مدير الفرع',
      requestDate: requestDate,
      status: status,
      reason: m['reason'] as String? ?? '',
      notes: m['notes'] as String? ?? '',
    );
  }

  MenuItem _mapJsonToMenuItem(Map<String, dynamic> m) {
    return MenuItem(
      id: m['id'] as String,
      sku: m['sku'] as String? ?? '',
      barcode: m['barcode'] as String? ?? '',
      nameAr: m['nameAr'] as String? ?? '',
      nameEn: m['nameEn'] as String? ?? '',
      categoryId: m['categoryId'] as String? ?? '',
      categoryName: m['categoryName'] as String? ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      cost: (m['cost'] as num?)?.toDouble() ?? 0.0,
      kitchenStation: m['kitchenStation'] as String? ?? 'محطة البرجر واللحوم',
      isActive: m['isActive'] as bool? ?? true,
      description: m['description'] as String? ?? '',
      branches: (m['branches'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['كافة الفروع'],
      allergens: (m['allergens'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
