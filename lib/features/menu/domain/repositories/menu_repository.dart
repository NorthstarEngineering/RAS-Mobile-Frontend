import '../entities/menu_category.dart';
import '../entities/menu_item.dart';
import '../entities/menu_item_request.dart';

abstract class MenuRepository {
  Future<List<MenuItem>> getMenuItems();
  Future<MenuItem?> getMenuItemById(String id);
  Future<List<MenuCategory>> getCategories();
  Future<void> saveMenuItem(MenuItem item);
  Future<void> addCategory(MenuCategory category);
  Future<List<MenuItemRequest>> getMenuItemRequests();
  Future<MenuItemRequest?> getMenuItemRequestById(String id);
  Future<void> createMenuItemRequest(MenuRequestDraft draft);
  Future<void> approveMenuItemRequest(String requestId, String sku);
  Future<void> rejectMenuItemRequest(String requestId, String reason);
}

class MenuRequestDraft {
  const MenuRequestDraft({
    required this.name,
    required this.price,
    this.description = '',
    this.justification = '',
  });
  final String name;
  final double price;
  final String description;
  final String justification;
}
