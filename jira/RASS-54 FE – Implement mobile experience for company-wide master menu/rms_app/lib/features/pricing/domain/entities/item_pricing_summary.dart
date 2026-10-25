class ItemPricingSummary {
  final String itemId;
  final String itemNameAr;
  final String itemNameEn;
  final String itemSku;
  final String categoryName;
  final double currentPrice;
  final double cost;
  final String? effectiveSince;
  final double? upcomingPrice;
  final String? upcomingEffectiveDate;
  final String? upcomingStatus;

  const ItemPricingSummary({
    required this.itemId,
    required this.itemNameAr,
    this.itemNameEn = '',
    this.itemSku = '',
    this.categoryName = '',
    required this.currentPrice,
    this.cost = 0.0,
    this.effectiveSince,
    this.upcomingPrice,
    this.upcomingEffectiveDate,
    this.upcomingStatus,
  });

  factory ItemPricingSummary.fromJson(Map<String, dynamic> json) {
    return ItemPricingSummary(
      itemId: json['itemId']?.toString() ?? json['id']?.toString() ?? '',
      itemNameAr: json['itemNameAr']?.toString() ?? json['nameAr']?.toString() ?? 'صنف غير محدد',
      itemNameEn: json['itemNameEn']?.toString() ?? json['nameEn']?.toString() ?? '',
      itemSku: json['itemSku']?.toString() ?? json['sku']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? json['category_name']?.toString() ?? 'عام',
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      effectiveSince: json['effectiveSince']?.toString() ?? json['effective_date']?.toString(),
      upcomingPrice: (json['upcomingPrice'] as num?)?.toDouble(),
      upcomingEffectiveDate: json['upcomingEffectiveDate']?.toString(),
      upcomingStatus: json['upcomingStatus']?.toString(),
    );
  }
}
