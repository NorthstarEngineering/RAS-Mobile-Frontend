import '../../../../core/network/authenticated_api.dart';

class ItemCost {
  const ItemCost(this.amount, this.grossProfit, this.foodCostPercent);
  final double amount;
  final double grossProfit;
  final double foodCostPercent;
}

class ApiItemCostRepository {
  const ApiItemCostRepository(this._api);
  final AuthenticatedApi _api;

  Future<ItemCost?> getCost(String itemId) async {
    final path = '/api/v1/cost/items/${Uri.encodeComponent(itemId)}';
    try {
      final payload = await _api.get(path);
      if (payload is! Map<String, dynamic> ||
          payload['menu_item_id'] != itemId) {
        throw const FormatException('بيانات تكلفة الصنف غير صالحة');
      }
      return ItemCost(
        _number(payload['cost_amount']),
        _number(payload['gross_profit']),
        _number(payload['food_cost_pct']),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  double _number(Object? field) {
    if (field is! num || !field.isFinite) {
      throw const FormatException('قيمة تكلفة غير صالحة');
    }
    return field.toDouble();
  }
}
