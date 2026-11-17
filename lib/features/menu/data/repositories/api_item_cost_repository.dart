import '../../../../core/network/authenticated_api.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
}

class ItemCost {
  const ItemCost(
    this.amount,
    this.grossProfit,
    this.foodCostPercent,
    this.components,
  );
  final double amount;
  final double grossProfit;
  final double foodCostPercent;
  final List<Map<String, Object?>> components;
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
        _components(payload['components']),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ItemCost?> updateAmount(String itemId, double amount) async {
    final current = await getCost(itemId);
    await _api.post('/api/v1/cost/items', {
      'menu_item_id': itemId,
      'cost_amount': amount,
      'components': current?.components ?? const [],
    });
    return getCost(itemId);
  }

  List<Map<String, Object?>> _components(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const FormatException('مكونات الصنف غير صالحة');
    }
    return raw.map((component) {
      if (component is! Map<String, dynamic> ||
          component['good_id'] is! String ||
          component['unit'] is! String) {
        throw const FormatException('مكونات الصنف غير صالحة');
      }
      return <String, Object?>{
        'good_id': component['good_id'],
        'unit': component['unit'],
        'quantity': _number(component['quantity']),
      };
    }).toList();
  }

  double _number(Object? field) {
    if (field is! num || !field.isFinite) {
      throw const FormatException('قيمة تكلفة غير صالحة');
    }
    return field.toDouble();
  }
}
