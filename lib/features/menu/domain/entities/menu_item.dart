class MenuItem {
  final String id;
  final String sku;
  final String barcode;
  final String nameAr;
  final String nameEn;
  final String categoryId;
  final String categoryName;
  final double price;
  final double cost;
  final double taxRate;
  final bool isActive;
  final String imageUrl;
  final String description;
  final String kitchenStation;
  final List<String> branches;
  final List<String> allergens;

  const MenuItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.nameAr,
    required this.nameEn,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.cost,
    this.taxRate = 0.14,
    this.isActive = true,
    this.imageUrl = '',
    this.description = '',
    this.kitchenStation = 'المطبخ الساخن',
    this.branches = const ['كافة الفروع'],
    this.allergens = const [],
  });

  MenuItem copyWith({
    String? id,
    String? sku,
    String? barcode,
    String? nameAr,
    String? nameEn,
    String? categoryId,
    String? categoryName,
    double? price,
    double? cost,
    double? taxRate,
    bool? isActive,
    String? imageUrl,
    String? description,
    String? kitchenStation,
    List<String>? branches,
    List<String>? allergens,
  }) {
    return MenuItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      taxRate: taxRate ?? this.taxRate,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      kitchenStation: kitchenStation ?? this.kitchenStation,
      branches: branches ?? this.branches,
      allergens: allergens ?? this.allergens,
    );
  }
}
