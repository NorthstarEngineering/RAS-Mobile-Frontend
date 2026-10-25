import '../entities/item_pricing_summary.dart';
import '../entities/price_change_request.dart';
import '../entities/price_history_entry.dart';

abstract class PricingRepository {
  Future<List<PriceChangeRequest>> getPriceChangeRequests();
  Future<PriceChangeRequest?> getPriceChangeRequestById(String id);
  Future<PriceChangeRequest> createPriceChangeRequest({
    required String itemId,
    required double proposedPrice,
    required String reason,
    double? currentPrice,
    DateTime? effectiveDate,
    String? requestedByUserId,
  });
  Future<void> reviewPriceChangeRequest({
    required String requestId,
    required bool isApproved,
    DateTime? effectiveDate,
    String? note,
    double? approvedPrice,
  });
  Future<List<PriceHistoryEntry>> getPriceHistory(String itemId);
  Future<ItemPricingSummary?> getItemPricingSummary(String itemId);
  Future<List<Map<String, dynamic>>> getActiveMenuItems();
}
