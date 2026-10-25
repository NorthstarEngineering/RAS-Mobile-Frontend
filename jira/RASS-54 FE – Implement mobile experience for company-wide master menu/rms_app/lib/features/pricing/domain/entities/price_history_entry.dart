class PriceHistoryEntry {
  final String id;
  final String itemId;
  final double oldPrice;
  final double newPrice;
  final DateTime effectiveDate;
  final String approvedByName;
  final String reason;

  const PriceHistoryEntry({
    required this.id,
    required this.itemId,
    required this.oldPrice,
    required this.newPrice,
    required this.effectiveDate,
    required this.approvedByName,
    required this.reason,
  });

  double get difference => newPrice - oldPrice;
  double get percentageChange => ((newPrice - oldPrice) / oldPrice) * 100;
}
