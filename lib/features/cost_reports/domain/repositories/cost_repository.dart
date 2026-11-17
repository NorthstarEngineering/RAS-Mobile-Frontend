import 'package:equatable/equatable.dart';

// ============================================================================
// COGS Report Domain Entities
// ============================================================================

class CategoryCogsData extends Equatable {
  const CategoryCogsData({
    required this.categoryName,
    required this.costAmount,
    required this.percentageOfTotalCost,
  });

  factory CategoryCogsData.fromJson(Map<String, dynamic> json) =>
      CategoryCogsData(
        categoryName: json['categoryName']?.toString() ??
            json['category_name']?.toString() ??
            '',
        costAmount: (json['costAmount'] ?? json['cost_amount'] as num?)
                ?.toDouble() ??
            0.0,
        percentageOfTotalCost: (json['percentageOfTotalCost'] ??
                json['percentage_of_total_cost'] as num?)
            ?.toDouble() ??
            0.0,
      );

  final String categoryName;
  final double costAmount;
  final double percentageOfTotalCost;

  Map<String, dynamic> toJson() => {
        'categoryName': categoryName,
        'costAmount': costAmount,
        'percentageOfTotalCost': percentageOfTotalCost,
      };

  @override
  List<Object?> get props => [categoryName, costAmount, percentageOfTotalCost];
}

class TopCogsItemData extends Equatable {
  const TopCogsItemData({
    required this.itemId,
    required this.itemName,
    required this.quantitySold,
    required this.unitCost,
    required this.totalCost,
  });

  factory TopCogsItemData.fromJson(Map<String, dynamic> json) =>
      TopCogsItemData(
        itemId: json['itemId']?.toString() ?? json['item_id']?.toString() ?? '',
        itemName:
            json['itemName']?.toString() ?? json['item_name']?.toString() ?? '',
        quantitySold: (json['quantitySold'] ?? json['quantity_sold'] as num?)
                ?.toDouble() ??
            0.0,
        unitCost: (json['unitCost'] ?? json['unit_cost'] as num?)?.toDouble() ??
            0.0,
        totalCost:
            (json['totalCost'] ?? json['total_cost'] as num?)?.toDouble() ??
                0.0,
      );

  final String itemId;
  final String itemName;
  final double quantitySold;
  final double unitCost;
  final double totalCost;

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'itemName': itemName,
        'quantitySold': quantitySold,
        'unitCost': unitCost,
        'totalCost': totalCost,
      };

  @override
  List<Object?> get props =>
      [itemId, itemName, quantitySold, unitCost, totalCost];
}

class CogsReportData extends Equatable {
  const CogsReportData({
    required this.period,
    required this.branchId,
    required this.branchName,
    required this.netSales,
    required this.totalCogs,
    required this.cogsPercentage,
    required this.targetCogsPercentage,
    required this.operationalStatus,
    required this.isWithinBudget,
    required this.categoryBreakdown,
    required this.topContributingItems,
    this.theoreticalCogs = 0.0,
    this.actualStockConsumption = 0.0,
  });

  factory CogsReportData.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categoryBreakdown'] ?? json['category_breakdown'];
    final rawTop =
        json['topContributingItems'] ?? json['top_contributing_items'];

    return CogsReportData(
      period: json['period']?.toString() ?? 'وردية اليوم • 16 أبريل 2024',
      branchId: json['branchId']?.toString() ??
          json['branch_id']?.toString() ??
          'br_01',
      branchName: json['branchName']?.toString() ??
          json['branch_name']?.toString() ??
          'فرع وسط البلد (#01)',
      netSales: (json['netSales'] ?? json['net_sales'] as num?)?.toDouble() ??
          42300.0,
      totalCogs: (json['totalCogs'] ?? json['total_cogs'] as num?)?.toDouble() ??
          12690.0,
      cogsPercentage: (json['cogsPercentage'] ?? json['cogs_percentage'] as num?)
              ?.toDouble() ??
          30.0,
      targetCogsPercentage: (json['targetCogsPercentage'] ??
              json['target_cogs_percentage'] as num?)
          ?.toDouble() ??
          31.5,
      operationalStatus: json['operationalStatus']?.toString() ??
          json['operational_status']?.toString() ??
          'وفق الميزانية',
      isWithinBudget: json['isWithinBudget'] as bool? ??
          json['is_within_budget'] as bool? ??
          true,
      categoryBreakdown: rawCats is List
          ? rawCats
              .whereType<Map<String, dynamic>>()
              .map(CategoryCogsData.fromJson)
              .toList()
          : const [],
      topContributingItems: rawTop is List
          ? rawTop
              .whereType<Map<String, dynamic>>()
              .map(TopCogsItemData.fromJson)
              .toList()
          : const [],
      theoreticalCogs: (json['theoreticalCogs'] ?? json['theoretical_cogs'] as num?)
              ?.toDouble() ??
          0.0,
      actualStockConsumption: (json['actualStockConsumption'] ??
              json['actual_stock_consumption'] as num?)
          ?.toDouble() ??
          0.0,
    );
  }

  final String period;
  final String branchId;
  final String branchName;
  final double netSales;
  final double totalCogs;
  final double cogsPercentage;
  final double targetCogsPercentage;
  final String operationalStatus;
  final bool isWithinBudget;
  final List<CategoryCogsData> categoryBreakdown;
  final List<TopCogsItemData> topContributingItems;
  final double theoreticalCogs;
  final double actualStockConsumption;

  Map<String, dynamic> toJson() => {
        'period': period,
        'branchId': branchId,
        'branchName': branchName,
        'netSales': netSales,
        'totalCogs': totalCogs,
        'cogsPercentage': cogsPercentage,
        'targetCogsPercentage': targetCogsPercentage,
        'operationalStatus': operationalStatus,
        'isWithinBudget': isWithinBudget,
        'categoryBreakdown': categoryBreakdown.map((e) => e.toJson()).toList(),
        'topContributingItems':
            topContributingItems.map((e) => e.toJson()).toList(),
        'theoreticalCogs': theoreticalCogs,
        'actualStockConsumption': actualStockConsumption,
      };

  @override
  List<Object?> get props => [
        period,
        branchId,
        branchName,
        netSales,
        totalCogs,
        cogsPercentage,
        targetCogsPercentage,
        operationalStatus,
        isWithinBudget,
        categoryBreakdown,
        topContributingItems,
      ];
}

// ============================================================================
// Consumption Variance Domain Entities
// ============================================================================

class VarianceIngredientData extends Equatable {
  const VarianceIngredientData({
    this.stockItemId,
    required this.sku,
    required this.nameAr,
    required this.theoreticalQty,
    required this.actualQty,
    required this.varianceQty,
    required this.unit,
    required this.unitCost,
    required this.varianceCost,
    required this.variancePercentage,
    required this.isCritical,
    required this.status,
  });

  factory VarianceIngredientData.fromJson(Map<String, dynamic> json) =>
      VarianceIngredientData(
        stockItemId: json['stockItemId']?.toString() ??
            json['stock_item_id']?.toString(),
        sku: json['sku']?.toString() ?? '',
        nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString() ?? '',
        theoreticalQty: (json['theoreticalQty'] ?? json['theoretical_qty'] as num?)
                ?.toDouble() ??
            0.0,
        actualQty:
            (json['actualQty'] ?? json['actual_qty'] as num?)?.toDouble() ??
                0.0,
        varianceQty: (json['varianceQty'] ?? json['variance_qty'] as num?)
                ?.toDouble() ??
            0.0,
        unit: json['unit']?.toString() ?? 'كجم',
        unitCost: (json['unitCost'] ?? json['unit_cost'] as num?)?.toDouble() ??
            0.0,
        varianceCost: (json['varianceCost'] ?? json['variance_cost'] as num?)
                ?.toDouble() ??
            0.0,
        variancePercentage: (json['variancePercentage'] ??
                json['variance_percentage'] as num?)
            ?.toDouble() ??
            0.0,
        isCritical: json['isCritical'] as bool? ??
            json['is_critical'] as bool? ??
            false,
        status: json['status']?.toString() ?? 'طبيعي',
      );

  final String? stockItemId;
  final String sku;
  final String nameAr;
  final double theoreticalQty;
  final double actualQty;
  final double varianceQty;
  final String unit;
  final double unitCost;
  final double varianceCost;
  final double variancePercentage;
  final bool isCritical;
  final String status;

  Map<String, dynamic> toJson() => {
        'stockItemId': stockItemId,
        'sku': sku,
        'nameAr': nameAr,
        'theoreticalQty': theoreticalQty,
        'actualQty': actualQty,
        'varianceQty': varianceQty,
        'unit': unit,
        'unitCost': unitCost,
        'varianceCost': varianceCost,
        'variancePercentage': variancePercentage,
        'isCritical': isCritical,
        'status': status,
      };

  @override
  List<Object?> get props => [
        stockItemId,
        sku,
        nameAr,
        theoreticalQty,
        actualQty,
        varianceQty,
        unit,
        unitCost,
        varianceCost,
        variancePercentage,
        isCritical,
        status,
      ];
}

class ConsumptionVarianceData extends Equatable {
  const ConsumptionVarianceData({
    required this.period,
    required this.branchId,
    required this.totalTheoreticalCost,
    required this.totalActualCost,
    required this.totalVarianceCost,
    required this.overallVarianceRate,
    required this.monitoredItemsCount,
    required this.criticalItemsCount,
    required this.items,
    required this.sopPolicyNote,
  });

  factory ConsumptionVarianceData.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ConsumptionVarianceData(
      period: json['period']?.toString() ??
          'مقارنة الاستهلاك الفعلي والنظري • 16 أبريل 2024',
      branchId: json['branchId']?.toString() ??
          json['branch_id']?.toString() ??
          'br_01',
      totalTheoreticalCost: (json['totalTheoreticalCost'] ??
              json['total_theoretical_cost'] as num?)
          ?.toDouble() ??
          0.0,
      totalActualCost: (json['totalActualCost'] ??
              json['total_actual_cost'] as num?)
          ?.toDouble() ??
          0.0,
      totalVarianceCost: (json['totalVarianceCost'] ??
              json['total_variance_cost'] as num?)
          ?.toDouble() ??
          -840.0,
      overallVarianceRate: (json['overallVarianceRate'] ??
              json['overall_variance_rate'] as num?)
          ?.toDouble() ??
          2.8,
      monitoredItemsCount: (json['monitoredItemsCount'] ??
              json['monitored_items_count'] as num?)
          ?.toInt() ??
          6,
      criticalItemsCount: (json['criticalItemsCount'] ??
              json['critical_items_count'] as num?)
          ?.toInt() ??
          2,
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(VarianceIngredientData.fromJson)
              .toList()
          : const [],
      sopPolicyNote: json['sopPolicyNote']?.toString() ??
          json['sop_policy_note']?.toString() ??
          'الانحراف الموجب الأكبر من 5% يستوجب إعادة معايرة الأوزان وفحص دورة التحضير قبل اعتماد الفاقد.',
    );
  }

  final String period;
  final String branchId;
  final double totalTheoreticalCost;
  final double totalActualCost;
  final double totalVarianceCost;
  final double overallVarianceRate;
  final int monitoredItemsCount;
  final int criticalItemsCount;
  final List<VarianceIngredientData> items;
  final String sopPolicyNote;

  Map<String, dynamic> toJson() => {
        'period': period,
        'branchId': branchId,
        'totalTheoreticalCost': totalTheoreticalCost,
        'totalActualCost': totalActualCost,
        'totalVarianceCost': totalVarianceCost,
        'overallVarianceRate': overallVarianceRate,
        'monitoredItemsCount': monitoredItemsCount,
        'criticalItemsCount': criticalItemsCount,
        'items': items.map((e) => e.toJson()).toList(),
        'sopPolicyNote': sopPolicyNote,
      };

  @override
  List<Object?> get props => [
        period,
        branchId,
        totalTheoreticalCost,
        totalActualCost,
        totalVarianceCost,
        overallVarianceRate,
        monitoredItemsCount,
        criticalItemsCount,
        items,
        sopPolicyNote,
      ];
}

// ============================================================================
// Recipe Cost Domain Entities
// ============================================================================

class RecipeIngredientData extends Equatable {
  const RecipeIngredientData({
    required this.id,
    this.stockItemId,
    required this.nameAr,
    this.nameEn,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.totalCost,
    required this.percentageOfCost,
  });

  factory RecipeIngredientData.fromJson(Map<String, dynamic> json) =>
      RecipeIngredientData(
        id: json['id']?.toString() ?? '',
        stockItemId: json['stockItemId']?.toString() ??
            json['stock_item_id']?.toString(),
        nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString() ?? '',
        nameEn: json['nameEn']?.toString() ?? json['name_en']?.toString(),
        quantity:
            (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit']?.toString() ?? 'كجم',
        unitCost: (json['unitCost'] ?? json['unit_cost'] as num?)?.toDouble() ??
            0.0,
        totalCost:
            (json['totalCost'] ?? json['total_cost'] as num?)?.toDouble() ??
                0.0,
        percentageOfCost: (json['percentageOfCost'] ??
                json['percentage_of_cost'] as num?)
            ?.toDouble() ??
            0.0,
      );

  final String id;
  final String? stockItemId;
  final String nameAr;
  final String? nameEn;
  final double quantity;
  final String unit;
  final double unitCost;
  final double totalCost;
  final double percentageOfCost;

  Map<String, dynamic> toJson() => {
        'id': id,
        'stockItemId': stockItemId,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'quantity': quantity,
        'unit': unit,
        'unitCost': unitCost,
        'totalCost': totalCost,
        'percentageOfCost': percentageOfCost,
      };

  @override
  List<Object?> get props => [
        id,
        stockItemId,
        nameAr,
        nameEn,
        quantity,
        unit,
        unitCost,
        totalCost,
        percentageOfCost,
      ];
}

class RecipeCostData extends Equatable {
  const RecipeCostData({
    required this.itemId,
    required this.sku,
    required this.nameAr,
    this.nameEn,
    required this.categoryName,
    required this.portionSize,
    required this.prepTime,
    required this.sellingPrice,
    required this.recipeCost,
    required this.grossProfit,
    required this.foodCostPercentage,
    required this.targetFoodCostPercentage,
    required this.varianceFromTarget,
    required this.targetStatus,
    required this.isWithinTarget,
    required this.ingredients,
  });

  factory RecipeCostData.fromJson(Map<String, dynamic> json) {
    final rawIng = json['ingredients'];
    return RecipeCostData(
      itemId: json['itemId']?.toString() ?? json['item_id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? json['name_en']?.toString(),
      categoryName: json['categoryName']?.toString() ??
          json['category_name']?.toString() ??
          'البرجر والسندوتشات',
      portionSize: json['portionSize']?.toString() ??
          json['portion_size']?.toString() ??
          'حصة 265 جم صافي',
      prepTime: json['prepTime']?.toString() ??
          json['prep_time']?.toString() ??
          '6–8 دقائق',
      sellingPrice: (json['sellingPrice'] ?? json['selling_price'] as num?)
              ?.toDouble() ??
          180.0,
      recipeCost: (json['recipeCost'] ?? json['recipe_cost'] as num?)
              ?.toDouble() ??
          54.0,
      grossProfit: (json['grossProfit'] ?? json['gross_profit'] as num?)
              ?.toDouble() ??
          126.0,
      foodCostPercentage: (json['foodCostPercentage'] ??
              json['food_cost_percentage'] as num?)
          ?.toDouble() ??
          30.0,
      targetFoodCostPercentage: (json['targetFoodCostPercentage'] ??
              json['target_food_cost_percentage'] as num?)
          ?.toDouble() ??
          32.0,
      varianceFromTarget: (json['varianceFromTarget'] ??
              json['variance_from_target'] as num?)
          ?.toDouble() ??
          -2.0,
      targetStatus: json['targetStatus']?.toString() ??
          json['target_status']?.toString() ??
          'أداء متميز',
      isWithinTarget: json['isWithinTarget'] as bool? ??
          json['is_within_target'] as bool? ??
          true,
      ingredients: rawIng is List
          ? rawIng
              .whereType<Map<String, dynamic>>()
              .map(RecipeIngredientData.fromJson)
              .toList()
          : const [],
    );
  }

  final String itemId;
  final String sku;
  final String nameAr;
  final String? nameEn;
  final String categoryName;
  final String portionSize;
  final String prepTime;
  final double sellingPrice;
  final double recipeCost;
  final double grossProfit;
  final double foodCostPercentage;
  final double targetFoodCostPercentage;
  final double varianceFromTarget;
  final String targetStatus;
  final bool isWithinTarget;
  final List<RecipeIngredientData> ingredients;

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'sku': sku,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'categoryName': categoryName,
        'portionSize': portionSize,
        'prepTime': prepTime,
        'sellingPrice': sellingPrice,
        'recipeCost': recipeCost,
        'grossProfit': grossProfit,
        'foodCostPercentage': foodCostPercentage,
        'targetFoodCostPercentage': targetFoodCostPercentage,
        'varianceFromTarget': varianceFromTarget,
        'targetStatus': targetStatus,
        'isWithinTarget': isWithinTarget,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [
        itemId,
        sku,
        nameAr,
        sellingPrice,
        recipeCost,
        grossProfit,
        foodCostPercentage,
        ingredients,
      ];
}

// ============================================================================
// Gross Profit Report Domain Entities
// ============================================================================

class ChannelProfitData extends Equatable {
  const ChannelProfitData({
    required this.channel,
    required this.channelLabel,
    required this.revenue,
    required this.cost,
    required this.grossProfit,
    required this.marginPercentage,
  });

  factory ChannelProfitData.fromJson(Map<String, dynamic> json) =>
      ChannelProfitData(
        channel: json['channel']?.toString() ?? '',
        channelLabel: json['channelLabel']?.toString() ??
            json['channel_label']?.toString() ??
            '',
        revenue:
            (json['revenue'] as num?)?.toDouble() ?? 0.0,
        cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
        grossProfit: (json['grossProfit'] ?? json['gross_profit'] as num?)
                ?.toDouble() ??
            0.0,
        marginPercentage: (json['marginPercentage'] ??
                json['margin_percentage'] as num?)
            ?.toDouble() ??
            0.0,
      );

  final String channel;
  final String channelLabel;
  final double revenue;
  final double cost;
  final double grossProfit;
  final double marginPercentage;

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'channelLabel': channelLabel,
        'revenue': revenue,
        'cost': cost,
        'grossProfit': grossProfit,
        'marginPercentage': marginPercentage,
      };

  @override
  List<Object?> get props =>
      [channel, channelLabel, revenue, cost, grossProfit, marginPercentage];
}

class CategoryProfitData extends Equatable {
  const CategoryProfitData({
    required this.categoryName,
    required this.revenue,
    required this.cost,
    required this.grossProfit,
    required this.marginPercentage,
  });

  factory CategoryProfitData.fromJson(Map<String, dynamic> json) =>
      CategoryProfitData(
        categoryName: json['categoryName']?.toString() ??
            json['category_name']?.toString() ??
            '',
        revenue:
            (json['revenue'] as num?)?.toDouble() ?? 0.0,
        cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
        grossProfit: (json['grossProfit'] ?? json['gross_profit'] as num?)
                ?.toDouble() ??
            0.0,
        marginPercentage: (json['marginPercentage'] ??
                json['margin_percentage'] as num?)
            ?.toDouble() ??
            0.0,
      );

  final String categoryName;
  final double revenue;
  final double cost;
  final double grossProfit;
  final double marginPercentage;

  Map<String, dynamic> toJson() => {
        'categoryName': categoryName,
        'revenue': revenue,
        'cost': cost,
        'grossProfit': grossProfit,
        'marginPercentage': marginPercentage,
      };

  @override
  List<Object?> get props =>
      [categoryName, revenue, cost, grossProfit, marginPercentage];
}

class GrossProfitReportData extends Equatable {
  const GrossProfitReportData({
    required this.period,
    required this.branchId,
    required this.totalRevenue,
    required this.totalCogs,
    required this.grossProfit,
    required this.grossProfitMargin,
    required this.channelBreakdown,
    required this.categoryRanking,
    required this.equation,
  });

  factory GrossProfitReportData.fromJson(Map<String, dynamic> json) {
    final rawChan = json['channelBreakdown'] ?? json['channel_breakdown'];
    final rawCats = json['categoryRanking'] ?? json['category_ranking'];

    return GrossProfitReportData(
      period: json['period']?.toString() ?? 'وردية اليوم • 16 أبريل 2024',
      branchId: json['branchId']?.toString() ??
          json['branch_id']?.toString() ??
          'br_01',
      totalRevenue: (json['totalRevenue'] ?? json['total_revenue'] as num?)
              ?.toDouble() ??
          42300.0,
      totalCogs: (json['totalCogs'] ?? json['total_cogs'] as num?)?.toDouble() ??
          12690.0,
      grossProfit: (json['grossProfit'] ?? json['gross_profit'] as num?)
              ?.toDouble() ??
          29610.0,
      grossProfitMargin: (json['grossProfitMargin'] ??
              json['gross_profit_margin'] as num?)
          ?.toDouble() ??
          70.0,
      channelBreakdown: rawChan is List
          ? rawChan
              .whereType<Map<String, dynamic>>()
              .map(ChannelProfitData.fromJson)
              .toList()
          : const [],
      categoryRanking: rawCats is List
          ? rawCats
              .whereType<Map<String, dynamic>>()
              .map(CategoryProfitData.fromJson)
              .toList()
          : const [],
      equation: json['equation']?.toString() ??
          '42,300.00 ج.م الإيرادات − 12,690.00 ج.م تكلفة المبيعات = 29,610.00 ج.م إجمالي الربح',
    );
  }

  final String period;
  final String branchId;
  final double totalRevenue;
  final double totalCogs;
  final double grossProfit;
  final double grossProfitMargin;
  final List<ChannelProfitData> channelBreakdown;
  final List<CategoryProfitData> categoryRanking;
  final String equation;

  Map<String, dynamic> toJson() => {
        'period': period,
        'branchId': branchId,
        'totalRevenue': totalRevenue,
        'totalCogs': totalCogs,
        'grossProfit': grossProfit,
        'grossProfitMargin': grossProfitMargin,
        'channelBreakdown': channelBreakdown.map((e) => e.toJson()).toList(),
        'categoryRanking': categoryRanking.map((e) => e.toJson()).toList(),
        'equation': equation,
      };

  @override
  List<Object?> get props => [
        period,
        branchId,
        totalRevenue,
        totalCogs,
        grossProfit,
        grossProfitMargin,
        channelBreakdown,
        categoryRanking,
      ];
}

// ============================================================================
// Labor Cost Report Domain Entities
// ============================================================================

class WageMixData extends Equatable {
  const WageMixData({
    required this.type,
    required this.label,
    required this.amount,
    required this.percentageOfTotal,
  });

  factory WageMixData.fromJson(Map<String, dynamic> json) => WageMixData(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        percentageOfTotal: (json['percentageOfTotal'] ??
                json['percentage_of_total'] as num?)
            ?.toDouble() ??
            0.0,
      );

  final String type;
  final String label;
  final double amount;
  final double percentageOfTotal;

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        'amount': amount,
        'percentageOfTotal': percentageOfTotal,
      };

  @override
  List<Object?> get props => [type, label, amount, percentageOfTotal];
}

class DepartmentLaborData extends Equatable {
  const DepartmentLaborData({
    required this.department,
    required this.departmentLabel,
    required this.amount,
    required this.percentageOfTotal,
  });

  factory DepartmentLaborData.fromJson(Map<String, dynamic> json) =>
      DepartmentLaborData(
        department: json['department']?.toString() ?? '',
        departmentLabel: json['departmentLabel']?.toString() ??
            json['department_label']?.toString() ??
            '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        percentageOfTotal: (json['percentageOfTotal'] ??
                json['percentage_of_total'] as num?)
            ?.toDouble() ??
            0.0,
      );

  final String department;
  final String departmentLabel;
  final double amount;
  final double percentageOfTotal;

  Map<String, dynamic> toJson() => {
        'department': department,
        'departmentLabel': departmentLabel,
        'amount': amount,
        'percentageOfTotal': percentageOfTotal,
      };

  @override
  List<Object?> get props =>
      [department, departmentLabel, amount, percentageOfTotal];
}

class LaborCostReportData extends Equatable {
  const LaborCostReportData({
    required this.period,
    required this.branchId,
    required this.totalLaborCost,
    required this.actualWorkingHours,
    required this.laborToSalesRatio,
    required this.laborToProfitRatio,
    required this.wageMix,
    required this.departmentBreakdown,
  });

  factory LaborCostReportData.fromJson(Map<String, dynamic> json) {
    final rawWage = json['wageMix'] ?? json['wage_mix'];
    final rawDept = json['departmentBreakdown'] ?? json['department_breakdown'];

    return LaborCostReportData(
      period: json['period']?.toString() ?? 'وردية اليوم • 16 أبريل 2024',
      branchId: json['branchId']?.toString() ??
          json['branch_id']?.toString() ??
          'br_01',
      totalLaborCost: (json['totalLaborCost'] ?? json['total_labor_cost'] as num?)
              ?.toDouble() ??
          4850.0,
      actualWorkingHours: (json['actualWorkingHours'] ??
              json['actual_working_hours'] as num?)
          ?.toDouble() ??
          72.0,
      laborToSalesRatio: (json['laborToSalesRatio'] ??
              json['labor_to_sales_ratio'] as num?)
          ?.toDouble() ??
          11.5,
      laborToProfitRatio: (json['laborToProfitRatio'] ??
              json['labor_to_profit_ratio'] as num?)
          ?.toDouble() ??
          16.4,
      wageMix: rawWage is List
          ? rawWage
              .whereType<Map<String, dynamic>>()
              .map(WageMixData.fromJson)
              .toList()
          : const [],
      departmentBreakdown: rawDept is List
          ? rawDept
              .whereType<Map<String, dynamic>>()
              .map(DepartmentLaborData.fromJson)
              .toList()
          : const [],
    );
  }

  final String period;
  final String branchId;
  final double totalLaborCost;
  final double actualWorkingHours;
  final double laborToSalesRatio;
  final double laborToProfitRatio;
  final List<WageMixData> wageMix;
  final List<DepartmentLaborData> departmentBreakdown;

  Map<String, dynamic> toJson() => {
        'period': period,
        'branchId': branchId,
        'totalLaborCost': totalLaborCost,
        'actualWorkingHours': actualWorkingHours,
        'laborToSalesRatio': laborToSalesRatio,
        'laborToProfitRatio': laborToProfitRatio,
        'wageMix': wageMix.map((e) => e.toJson()).toList(),
        'departmentBreakdown':
            departmentBreakdown.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [
        period,
        branchId,
        totalLaborCost,
        actualWorkingHours,
        laborToSalesRatio,
        laborToProfitRatio,
        wageMix,
        departmentBreakdown,
      ];
}

// ============================================================================
// Contribution Report Domain Entities
// ============================================================================

class WaterfallStepData extends Equatable {
  const WaterfallStepData({
    required this.step,
    required this.label,
    required this.amount,
    required this.isDeduction,
  });

  factory WaterfallStepData.fromJson(Map<String, dynamic> json) =>
      WaterfallStepData(
        step: (json['step'] as num?)?.toInt() ?? 1,
        label: json['label']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        isDeduction: json['isDeduction'] as bool? ??
            json['is_deduction'] as bool? ??
            false,
      );

  final int step;
  final String label;
  final double amount;
  final bool isDeduction;

  Map<String, dynamic> toJson() => {
        'step': step,
        'label': label,
        'amount': amount,
        'isDeduction': isDeduction,
      };

  @override
  List<Object?> get props => [step, label, amount, isDeduction];
}

class ChannelContributionData extends Equatable {
  const ChannelContributionData({
    required this.channel,
    required this.channelLabel,
    required this.revenue,
    required this.contributionAmount,
    required this.contributionMarginPercentage,
  });

  factory ChannelContributionData.fromJson(Map<String, dynamic> json) =>
      ChannelContributionData(
        channel: json['channel']?.toString() ?? '',
        channelLabel: json['channelLabel']?.toString() ??
            json['channel_label']?.toString() ??
            '',
        revenue:
            (json['revenue'] as num?)?.toDouble() ?? 0.0,
        contributionAmount: (json['contributionAmount'] ??
                json['contribution_amount'] as num?)
            ?.toDouble() ??
            0.0,
        contributionMarginPercentage:
            (json['contributionMarginPercentage'] ??
                    json['contribution_margin_percentage'] as num?)
                ?.toDouble() ??
                0.0,
      );

  final String channel;
  final String channelLabel;
  final double revenue;
  final double contributionAmount;
  final double contributionMarginPercentage;

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'channelLabel': channelLabel,
        'revenue': revenue,
        'contributionAmount': contributionAmount,
        'contributionMarginPercentage': contributionMarginPercentage,
      };

  @override
  List<Object?> get props => [
        channel,
        channelLabel,
        revenue,
        contributionAmount,
        contributionMarginPercentage,
      ];
}

class ContributionReportData extends Equatable {
  const ContributionReportData({
    required this.period,
    required this.branchId,
    required this.totalRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.laborCost,
    required this.contributionMargin,
    required this.contributionMarginPercentage,
    required this.waterfall,
    required this.channelBreakdown,
  });

  factory ContributionReportData.fromJson(Map<String, dynamic> json) {
    final rawWater = json['waterfall'];
    final rawChan = json['channelBreakdown'] ?? json['channel_breakdown'];

    return ContributionReportData(
      period: json['period']?.toString() ?? 'وردية اليوم • 16 أبريل 2024',
      branchId: json['branchId']?.toString() ??
          json['branch_id']?.toString() ??
          'br_01',
      totalRevenue: (json['totalRevenue'] ?? json['total_revenue'] as num?)
              ?.toDouble() ??
          42300.0,
      cogs: (json['cogs'] as num?)?.toDouble() ?? 12690.0,
      grossProfit: (json['grossProfit'] ?? json['gross_profit'] as num?)
              ?.toDouble() ??
          29610.0,
      laborCost: (json['laborCost'] ?? json['labor_cost'] as num?)?.toDouble() ??
          4850.0,
      contributionMargin: (json['contributionMargin'] ??
              json['contribution_margin'] as num?)
          ?.toDouble() ??
          24760.0,
      contributionMarginPercentage: (json['contributionMarginPercentage'] ??
              json['contribution_margin_percentage'] as num?)
          ?.toDouble() ??
          58.53,
      waterfall: rawWater is List
          ? rawWater
              .whereType<Map<String, dynamic>>()
              .map(WaterfallStepData.fromJson)
              .toList()
          : const [],
      channelBreakdown: rawChan is List
          ? rawChan
              .whereType<Map<String, dynamic>>()
              .map(ChannelContributionData.fromJson)
              .toList()
          : const [],
    );
  }

  final String period;
  final String branchId;
  final double totalRevenue;
  final double cogs;
  final double grossProfit;
  final double laborCost;
  final double contributionMargin;
  final double contributionMarginPercentage;
  final List<WaterfallStepData> waterfall;
  final List<ChannelContributionData> channelBreakdown;

  Map<String, dynamic> toJson() => {
        'period': period,
        'branchId': branchId,
        'totalRevenue': totalRevenue,
        'cogs': cogs,
        'grossProfit': grossProfit,
        'laborCost': laborCost,
        'contributionMargin': contributionMargin,
        'contributionMarginPercentage': contributionMarginPercentage,
        'waterfall': waterfall.map((e) => e.toJson()).toList(),
        'channelBreakdown': channelBreakdown.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [
        period,
        branchId,
        totalRevenue,
        cogs,
        grossProfit,
        laborCost,
        contributionMargin,
        contributionMarginPercentage,
        waterfall,
        channelBreakdown,
      ];
}

// ============================================================================
// Inventory Valuation Domain Entities
// ============================================================================

class InventoryCategoryValuationData extends Equatable {
  const InventoryCategoryValuationData({
    required this.category,
    required this.totalValue,
    required this.percentageOfTotal,
    required this.itemsCount,
  });

  factory InventoryCategoryValuationData.fromJson(Map<String, dynamic> json) =>
      InventoryCategoryValuationData(
        category: json['category']?.toString() ?? '',
        totalValue: (json['totalValue'] ?? json['total_value'] as num?)
                ?.toDouble() ??
            0.0,
        percentageOfTotal: (json['percentageOfTotal'] ??
                json['percentage_of_total'] as num?)
            ?.toDouble() ??
            0.0,
        itemsCount: (json['itemsCount'] ?? json['items_count'] as num?)
                ?.toInt() ??
            0,
      );

  final String category;
  final double totalValue;
  final double percentageOfTotal;
  final int itemsCount;

  Map<String, dynamic> toJson() => {
        'category': category,
        'totalValue': totalValue,
        'percentageOfTotal': percentageOfTotal,
        'itemsCount': itemsCount,
      };

  @override
  List<Object?> get props => [category, totalValue, percentageOfTotal, itemsCount];
}

class InventoryStockItemData extends Equatable {
  const InventoryStockItemData({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.totalValue,
    required this.stockLevel,
    this.location,
  });

  factory InventoryStockItemData.fromJson(Map<String, dynamic> json) =>
      InventoryStockItemData(
        id: json['id']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        quantity:
            (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit']?.toString() ?? 'كجم',
        unitCost: (json['unitCost'] ?? json['unit_cost'] as num?)?.toDouble() ??
            0.0,
        totalValue: (json['totalValue'] ?? json['total_value'] as num?)
                ?.toDouble() ??
            0.0,
        stockLevel: json['stockLevel']?.toString() ??
            json['stock_level']?.toString() ??
            'available',
        location: json['location']?.toString(),
      );

  final String id;
  final String sku;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final double unitCost;
  final double totalValue;
  final String stockLevel;
  final String? location;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'unitCost': unitCost,
        'totalValue': totalValue,
        'stockLevel': stockLevel,
        'location': location,
      };

  @override
  List<Object?> get props => [
        id,
        sku,
        name,
        category,
        quantity,
        unit,
        unitCost,
        totalValue,
        stockLevel,
        location,
      ];
}

class InventoryValuationData extends Equatable {
  const InventoryValuationData({
    this.branchId,
    required this.totalInventoryValue,
    required this.categoryBreakdown,
    required this.stockItems,
    required this.totalItemsCount,
    required this.criticalItemsCount,
    required this.lowStockItemsCount,
  });

  factory InventoryValuationData.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categoryBreakdown'] ?? json['category_breakdown'];
    final rawItems = json['stockItems'] ?? json['stock_items'];

    return InventoryValuationData(
      branchId: json['branchId']?.toString() ?? json['branch_id']?.toString(),
      totalInventoryValue: (json['totalInventoryValue'] ??
              json['total_inventory_value'] as num?)
          ?.toDouble() ??
          64280.0,
      categoryBreakdown: rawCats is List
          ? rawCats
              .whereType<Map<String, dynamic>>()
              .map(InventoryCategoryValuationData.fromJson)
              .toList()
          : const [],
      stockItems: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(InventoryStockItemData.fromJson)
              .toList()
          : const [],
      totalItemsCount: (json['totalItemsCount'] ??
              json['total_items_count'] as num?)
          ?.toInt() ??
          0,
      criticalItemsCount: (json['criticalItemsCount'] ??
              json['critical_items_count'] as num?)
          ?.toInt() ??
          0,
      lowStockItemsCount: (json['lowStockItemsCount'] ??
              json['low_stock_items_count'] as num?)
          ?.toInt() ??
          0,
    );
  }

  final String? branchId;
  final double totalInventoryValue;
  final List<InventoryCategoryValuationData> categoryBreakdown;
  final List<InventoryStockItemData> stockItems;
  final int totalItemsCount;
  final int criticalItemsCount;
  final int lowStockItemsCount;

  Map<String, dynamic> toJson() => {
        'branchId': branchId,
        'totalInventoryValue': totalInventoryValue,
        'categoryBreakdown': categoryBreakdown.map((e) => e.toJson()).toList(),
        'stockItems': stockItems.map((e) => e.toJson()).toList(),
        'totalItemsCount': totalItemsCount,
        'criticalItemsCount': criticalItemsCount,
        'lowStockItemsCount': lowStockItemsCount,
      };

  @override
  List<Object?> get props => [
        branchId,
        totalInventoryValue,
        categoryBreakdown,
        stockItems,
        totalItemsCount,
        criticalItemsCount,
        lowStockItemsCount,
      ];
}

// ============================================================================
// Cost Repository Contract Interface
// ============================================================================

abstract class CostRepository {
  Future<CogsReportData> getCogsReport({
    String? branchId,
    String? shiftId,
    String? startDate,
    String? endDate,
    double? targetCogsPct,
  });

  Future<ConsumptionVarianceData> getConsumptionVarianceReport({
    String? branchId,
    String? startDate,
    String? endDate,
  });

  Future<RecipeCostData> getRecipeCost({
    String itemId = 'item_1',
    double? targetFoodCostPct,
  });

  Future<GrossProfitReportData> getGrossProfitReport({
    String? branchId,
    String? shiftId,
    String? startDate,
    String? endDate,
  });

  Future<LaborCostReportData> getLaborCostReport({
    String? branchId,
    String? date,
    String? shiftId,
  });

  Future<ContributionReportData> getContributionReport({
    String? branchId,
    String? shiftId,
    String? startDate,
    String? endDate,
  });

  Future<InventoryValuationData> getInventoryValuationReport({
    String? branchId,
  });
}
