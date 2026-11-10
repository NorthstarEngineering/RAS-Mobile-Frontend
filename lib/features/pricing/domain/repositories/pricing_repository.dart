import '../entities/price_change_request.dart';
import '../entities/price_history_entry.dart';

abstract class PricingRepository {
  Future<List<PriceChangeRequest>> getPriceChangeRequests();
  Future<PriceChangeRequest?> getPriceChangeRequestById(String id);
  Future<void> reviewPriceChangeRequest({
    required String requestId,
    required bool isApproved,
    DateTime? effectiveDate,
    String? note,
  });
  Future<List<PriceHistoryEntry>> getPriceHistory(String itemId);
}
