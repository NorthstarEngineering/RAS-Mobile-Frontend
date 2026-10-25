class MenuCategory {
  final String id;
  final String nameAr;
  final String nameEn;
  final int itemsCount;
  final int sortOrder;
  final bool isActive;

  const MenuCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.itemsCount,
    required this.sortOrder,
    this.isActive = true,
  });
}
