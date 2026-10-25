import '../../domain/entities/menu_category.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/menu_item_request.dart';
import '../../domain/repositories/menu_repository.dart';

class MockMenuRepository implements MenuRepository {
  final List<MenuCategory> _categories = [
    const MenuCategory(
      id: 'cat_burgers',
      nameAr: 'برجر وسندوتشات',
      nameEn: 'Burgers & Sandwiches',
      itemsCount: 16,
      sortOrder: 1,
    ),
    const MenuCategory(
      id: 'cat_mains',
      nameAr: 'وجبات رئيسية',
      nameEn: 'Main Courses',
      itemsCount: 12,
      sortOrder: 2,
    ),
    const MenuCategory(
      id: 'cat_apps',
      nameAr: 'مقبلات وصوصات',
      nameEn: 'Appetizers & Dips',
      itemsCount: 8,
      sortOrder: 3,
    ),
    const MenuCategory(
      id: 'cat_drinks',
      nameAr: 'مشروبات وبار',
      nameEn: 'Drinks & Beverages',
      itemsCount: 8,
      sortOrder: 4,
    ),
    const MenuCategory(
      id: 'cat_desserts',
      nameAr: 'حلويات',
      nameEn: 'Desserts',
      itemsCount: 4,
      sortOrder: 5,
    ),
  ];

  final List<MenuItem> _items = [
    const MenuItem(
      id: 'item_1',
      sku: 'BURG-1024',
      barcode: '6223001849201',
      nameAr: 'برجر كلاسيك سينجل',
      nameEn: 'Classic Burger Single',
      categoryId: 'cat_burgers',
      categoryName: 'برجر وسندوتشات',
      price: 120.00,
      cost: 58.50,
      isActive: true,
      description: 'شريحة لحم بقري صافي 150 جرام مع جبنة الشيدر الذائبة والخس والصلصة الخاصة في خبز البريوش الطازج.',
      kitchenStation: 'محطة البرجر واللحوم',
      branches: ['كافة الفروع'],
      allergens: ['جلوتين', 'منتجات ألبان'],
    ),
    const MenuItem(
      id: 'item_2',
      sku: 'CHK-04',
      barcode: '6223001849202',
      nameAr: 'تشيكن تندر سوبريم 5 قطع',
      nameEn: 'Chicken Tenders Supreme (5 pcs)',
      categoryId: 'cat_mains',
      categoryName: 'وجبات رئيسية',
      price: 145.00,
      cost: 65.00,
      isActive: true,
      description: 'أصابع صدور دجاج طازجة مقرمشة مع بطاطس مقلية وصوص هوني ماسترد وصوص الباربكيو.',
      kitchenStation: 'محطة القلي والمقرمشات',
      branches: ['كافة الفروع'],
      allergens: ['جلوتين'],
    ),
    const MenuItem(
      id: 'item_3',
      sku: 'BURG-2048',
      barcode: '6223001849203',
      nameAr: 'دبل سموكد بيكون برجر',
      nameEn: 'Double Smoked Bacon Burger',
      categoryId: 'cat_burgers',
      categoryName: 'برجر وسندوتشات',
      price: 195.00,
      cost: 92.00,
      isActive: true,
      description: 'شريحتان لحم بقري 300 جرام مع بيكون بقري مدخن وجبنة جودا وصلصة سموكي باربيكيو.',
      kitchenStation: 'محطة البرجر واللحوم',
      branches: ['فرع وسط البلد', 'فرع المعادي'],
      allergens: ['جلوتين', 'ألبان'],
    ),
    const MenuItem(
      id: 'item_4',
      sku: 'APP-02',
      barcode: '6223001849204',
      nameAr: 'حلقات بصل كريسبي مع صوص رانش',
      nameEn: 'Crispy Onion Rings with Ranch',
      categoryId: 'cat_apps',
      categoryName: 'مقبلات وصوصات',
      price: 65.00,
      cost: 22.00,
      isActive: true,
      description: 'حلقات بصل ذهبية مقرمشة محضرة يدوياً ومتبلة بالأعشاب مع صوص الرانش المنعش.',
      kitchenStation: 'محطة المقبلات والسلطات',
      branches: ['كافة الفروع'],
      allergens: ['جلوتين', 'ألبان'],
    ),
    const MenuItem(
      id: 'item_5',
      sku: 'DRK-01',
      barcode: '6223001849205',
      nameAr: 'عصير برتقال طازج معصور',
      nameEn: 'Fresh Squeezed Orange Juice',
      categoryId: 'cat_drinks',
      categoryName: 'مشروبات وبار',
      price: 45.00,
      cost: 18.00,
      isActive: true,
      description: 'عصير برتقال طبيعي 100% بدون سكر مضاف أو مواد حافظة.',
      kitchenStation: 'محطة المشروبات والبار',
      branches: ['كافة الفروع'],
      allergens: [],
    ),
  ];

  final List<MenuItemRequest> _requests = [
    MenuItemRequest(
      id: 'req_1',
      requestNumber: 'REQ-MENU-4819',
      itemNameAr: 'ساندوتش فاهيتا لحم مكسيكي',
      itemNameEn: 'Mexican Beef Fajita Sandwich',
      categoryName: 'برجر وسندوتشات',
      proposedPrice: 155.00,
      estimatedCost: 72.00,
      branchName: 'فرع وسط البلد #01',
      requestedByName: 'م. ألفاريز (مدير الفرع)',
      requestDate: DateTime.now().subtract(const Duration(hours: 3)),
      status: MenuItemRequestStatus.pending,
      reason: 'طلب متكرر من زبائن الفرع وإضافة تنوع للمنيو في وجبات الغداء.',
      notes: 'المكونات متوفرة في مخزن الفرع ولا تتطلب معدات إضافية.',
    ),
    MenuItemRequest(
      id: 'req_2',
      requestNumber: 'REQ-MENU-4818',
      itemNameAr: 'سلطة سيزر دجاج مشوي',
      itemNameEn: 'Grilled Chicken Caesar Salad',
      categoryName: 'مقبلات وصوصات',
      proposedPrice: 95.00,
      estimatedCost: 40.00,
      branchName: 'فرع المعادي #02',
      requestedByName: 'أحمد نبيل (مدير الفرع)',
      requestDate: DateTime.now().subtract(const Duration(days: 1)),
      status: MenuItemRequestStatus.pending,
      reason: 'طلب خيارات صحية من رواد الصالة الرياضية المجاورة.',
    ),
    MenuItemRequest(
      id: 'req_3',
      requestNumber: 'REQ-MENU-4817',
      itemNameAr: 'ميلك شيك كراميل مملح',
      itemNameEn: 'Salted Caramel Milkshake',
      categoryName: 'مشروبات وبار',
      proposedPrice: 65.00,
      estimatedCost: 24.00,
      branchName: 'فرع التجمع #03',
      requestedByName: 'سارة مراد (مدير الفرع)',
      requestDate: DateTime.now().subtract(const Duration(days: 3)),
      status: MenuItemRequestStatus.approved,
      reason: 'زيادة مبيعات ركن المشروبات والحلويات في الفترة المسائية.',
    ),
    MenuItemRequest(
      id: 'req_4',
      requestNumber: 'REQ-MENU-4816',
      itemNameAr: 'برجر ترافل مشروم فاخر',
      itemNameEn: 'Truffle Mushroom Burger',
      categoryName: 'برجر وسندوتشات',
      proposedPrice: 240.00,
      estimatedCost: 140.00,
      branchName: 'فرع الشيخ زايد #04',
      requestedByName: 'كريم عادل (مدير الفرع)',
      requestDate: DateTime.now().subtract(const Duration(days: 5)),
      status: MenuItemRequestStatus.rejected,
      reason: 'هامش الربح منخفض جداً وتكلفة زيت الترافل مرتفعة على الميزانية الحالية.',
    ),
  ];

  @override
  Future<List<MenuItem>> getMenuItems() async {
    return List.unmodifiable(_items);
  }

  @override
  Future<MenuItem?> getMenuItemById(String id) async {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MenuCategory>> getCategories() async {
    return List.unmodifiable(_categories);
  }

  @override
  Future<void> addMenuItem(MenuItem item) => saveMenuItem(item);

  @override
  Future<void> saveMenuItem(MenuItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    _items.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> addCategory(MenuCategory category) async {
    _categories.add(category);
  }

  @override
  Future<void> updateCategory(MenuCategory category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      _categories[index] = category;
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> updateCategoryOrder(List<MenuCategory> categories) async {
    _categories.clear();
    _categories.addAll(categories);
  }

  @override
  Future<List<MenuItemRequest>> getMenuItemRequests() async {
    return List.unmodifiable(_requests);
  }

  @override
  Future<MenuItemRequest?> getMenuItemRequestById(String id) async {
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> createMenuItemRequest(MenuItemRequest request) async {
    _requests.insert(0, request);
  }

  @override
  Future<void> reviewMenuItemRequest({
    required String requestId,
    required bool isApproved,
    String? note,
    String? categoryId,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      final req = _requests[index];
      _requests[index] = req.copyWith(
        status: isApproved ? MenuItemRequestStatus.approved : MenuItemRequestStatus.rejected,
        notes: note ?? req.notes,
      );
    }
  }
}
