import '../entities/menu_category.dart';
import '../entities/menu_item.dart';
import '../entities/menu_item_request.dart';

abstract class MenuRepository {
  Future<List<MenuItem>> getMenuItems();
  Future<MenuItem?> getMenuItemById(String id);
  Future<List<MenuCategory>> getCategories();
  Future<void> saveMenuItem(MenuItem item);
  Future<void> deleteMenuItem(String id);
  Future<void> addCategory(MenuCategory category);
  Future<void> updateCategoryOrder(List<MenuCategory> categories);
  Future<List<MenuItemRequest>> getMenuItemRequests();
  Future<MenuItemRequest?> getMenuItemRequestById(String id);
  Future<void> reviewMenuItemRequest({
    required String requestId,
    required bool isApproved,
    String? note,
  });
}
