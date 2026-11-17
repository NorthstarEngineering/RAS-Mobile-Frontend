import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/cost_repository.dart';

class HttpCostRepository implements CostRepository {
  HttpCostRepository({ApiClient? apiClient})
      : _apiClient = apiClient ??
            (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient());

  static final HttpCostRepository instance = HttpCostRepository();

  final ApiClient _apiClient;

  // Local caches to guarantee zero-crash offline and offline fallback stability
  CogsReportData? _cachedCogsReport;
  ConsumptionVarianceData? _cachedVarianceReport;
  final Map<String, RecipeCostData> _cachedRecipeCosts = {};
  GrossProfitReportData? _cachedGrossProfit;
  LaborCostReportData? _cachedLaborCost;
  ContributionReportData? _cachedContribution;
  InventoryValuationData? _cachedInventory;

  // ============================================================================
  // Static Default Fallbacks (matching 100% of UI design specifications)
  // ============================================================================

  static const CogsReportData defaultCogsReport = CogsReportData(
    period: 'وردية اليوم • 16 أبريل 2024',
    branchId: 'br_01',
    branchName: 'فرع وسط البلد (#01)',
    netSales: 42300.0,
    totalCogs: 12690.0,
    cogsPercentage: 30.0,
    targetCogsPercentage: 31.5,
    operationalStatus: 'وفق الميزانية',
    isWithinBudget: true,
    categoryBreakdown: [
      CategoryCogsData(
        categoryName: 'اللحوم والدواجن',
        costAmount: 6850.0,
        percentageOfTotalCost: 54.0,
      ),
      CategoryCogsData(
        categoryName: 'الأجبان ومنتجات الألبان',
        costAmount: 2150.0,
        percentageOfTotalCost: 16.9,
      ),
      CategoryCogsData(
        categoryName: 'المخبوزات والخبز',
        costAmount: 1420.0,
        percentageOfTotalCost: 11.2,
      ),
      CategoryCogsData(
        categoryName: 'الصوصات والزيوت والتغليف',
        costAmount: 2270.0,
        percentageOfTotalCost: 17.9,
      ),
    ],
    topContributingItems: [
      TopCogsItemData(
        itemId: 'item_3',
        itemName: 'برجر سموكي تشيز دبل',
        quantitySold: 50,
        unitCost: 76.0,
        totalCost: 3800.0,
      ),
      TopCogsItemData(
        itemId: 'item_1',
        itemName: 'برجر كلاسيك سينجل',
        quantitySold: 60,
        unitCost: 54.0,
        totalCost: 3240.0,
      ),
      TopCogsItemData(
        itemId: 'item_box_01',
        itemName: 'بوكس عائلي برجر مشوي',
        quantitySold: 15,
        unitCost: 145.0,
        totalCost: 2175.0,
      ),
    ],
    theoreticalCogs: 12690.0,
    actualStockConsumption: 12690.0,
  );

  static const ConsumptionVarianceData defaultConsumptionVariance =
      ConsumptionVarianceData(
    period: 'مقارنة الاستهلاك الفعلي والنظري • 16 أبريل 2024',
    branchId: 'br_01',
    totalTheoreticalCost: 15420.0,
    totalActualCost: 16260.0,
    totalVarianceCost: -840.0,
    overallVarianceRate: 2.8,
    monitoredItemsCount: 6,
    criticalItemsCount: 2,
    items: [
      VarianceIngredientData(
        stockItemId: 'stock_ck_01',
        sku: 'RAW-MEAT-102',
        nameAr: 'لحم بقري مفروم',
        theoreticalQty: 16.5,
        actualQty: 17.8,
        varianceQty: 1.3,
        unit: 'كجم',
        unitCost: 320.0,
        varianceCost: 416.0,
        variancePercentage: 7.9,
        isCritical: true,
        status: 'حالة حرجة',
      ),
      VarianceIngredientData(
        stockItemId: 'stock_br1_01',
        sku: 'RAW-POULT-204',
        nameAr: 'صدور دجاج فيليه',
        theoreticalQty: 11.0,
        actualQty: 11.2,
        varianceQty: 0.2,
        unit: 'كجم',
        unitCost: 185.0,
        varianceCost: 37.0,
        variancePercentage: 1.8,
        isCritical: false,
        status: 'طبيعي',
      ),
      VarianceIngredientData(
        stockItemId: 'stock_ck_04',
        sku: 'DAIRY-CHD-08',
        nameAr: 'جبن شيدر أحمر',
        theoreticalQty: 3.8,
        actualQty: 4.5,
        varianceQty: 0.7,
        unit: 'كجم',
        unitCost: 240.0,
        varianceCost: 168.0,
        variancePercentage: 18.4,
        isCritical: true,
        status: 'حالة حرجة',
      ),
      VarianceIngredientData(
        stockItemId: 'stock_ck_03',
        sku: 'SAUCE-CHD-04',
        nameAr: 'صوص شيدر مدخن',
        theoreticalQty: 3.2,
        actualQty: 3.3,
        varianceQty: 0.1,
        unit: 'لتر',
        unitCost: 45.0,
        varianceCost: 4.5,
        variancePercentage: 3.1,
        isCritical: false,
        status: 'طبيعي',
      ),
      VarianceIngredientData(
        stockItemId: 'stock_ck_06',
        sku: 'BAK-BUN-01',
        nameAr: 'خبز بريوش طازج',
        theoreticalQty: 110.0,
        actualQty: 115.0,
        varianceQty: 5.0,
        unit: 'قطعة',
        unitCost: 4.5,
        varianceCost: 22.5,
        variancePercentage: 4.5,
        isCritical: false,
        status: 'طبيعي',
      ),
      VarianceIngredientData(
        stockItemId: 'stock_ck_02',
        sku: 'RAW-OIL-01',
        nameAr: 'زيت تحمير نباتي نقي',
        theoreticalQty: 30.0,
        actualQty: 33.0,
        varianceQty: 3.0,
        unit: 'لتر',
        unitCost: 64.0,
        varianceCost: 192.0,
        variancePercentage: 10.0,
        isCritical: true,
        status: 'حالة حرجة',
      ),
    ],
    sopPolicyNote:
        'الانحراف الموجب الأكبر من 5% يستوجب إعادة معايرة الأوزان وفحص دورة التحضير قبل اعتماد الفاقد.',
  );

  static const RecipeCostData defaultRecipeCost = RecipeCostData(
    itemId: 'item_1',
    sku: 'BURG-1024',
    nameAr: 'وجبة برجر كلاسيك سينجل • MENU-BRG-01',
    nameEn: 'Classic Burger Single Meal',
    categoryName: 'البرجر والسندوتشات',
    portionSize: 'حصة 265 جم صافي',
    prepTime: '6–8 دقائق',
    sellingPrice: 180.0,
    recipeCost: 54.0,
    grossProfit: 126.0,
    foodCostPercentage: 30.0,
    targetFoodCostPercentage: 32.0,
    varianceFromTarget: -2.0,
    targetStatus: 'أداء متميز',
    isWithinTarget: true,
    ingredients: [
      RecipeIngredientData(
        id: 'ing_brg_01',
        stockItemId: 'stock_ck_01',
        nameAr: 'لحم بقري بلدي مفروم',
        nameEn: 'Ground Beef Patty',
        quantity: 0.150,
        unit: 'كجم',
        unitCost: 190.0,
        totalCost: 28.5,
        percentageOfCost: 52.78,
      ),
      RecipeIngredientData(
        id: 'ing_brg_02',
        stockItemId: 'stock_ck_06',
        nameAr: 'خبز بريوش بالسمسم',
        nameEn: 'Brioche Bun',
        quantity: 1.0,
        unit: 'قطعة',
        unitCost: 4.5,
        totalCost: 4.5,
        percentageOfCost: 8.33,
      ),
      RecipeIngredientData(
        id: 'ing_brg_03',
        stockItemId: 'stock_ck_04',
        nameAr: 'جبن شيدر أحمر مستورد',
        nameEn: 'Red Cheddar Cheese',
        quantity: 0.030,
        unit: 'كجم',
        unitCost: 240.0,
        totalCost: 7.2,
        percentageOfCost: 13.33,
      ),
      RecipeIngredientData(
        id: 'ing_brg_04',
        stockItemId: 'stock_ck_03',
        nameAr: 'صوص شيدر وخضروات وتغليف',
        nameEn: 'Sauces, Veggies & Packaging',
        quantity: 1.0,
        unit: 'حصة',
        unitCost: 13.8,
        totalCost: 13.8,
        percentageOfCost: 25.56,
      ),
    ],
  );

  static const GrossProfitReportData defaultGrossProfit = GrossProfitReportData(
    period: 'وردية الصباح • 16 أبريل 2024',
    branchId: 'br_01',
    totalRevenue: 42300.0,
    totalCogs: 12690.0,
    grossProfit: 29610.0,
    grossProfitMargin: 70.0,
    channelBreakdown: [
      ChannelProfitData(
        channel: 'dine_in_takeaway',
        channelLabel: 'مبيعات المطعم (صالة وسفري)',
        revenue: 28400.0,
        cost: 8240.0,
        grossProfit: 20160.0,
        marginPercentage: 71.0,
      ),
      ChannelProfitData(
        channel: 'delivery_apps',
        channelLabel: 'مبيعات التوصيل',
        revenue: 13900.0,
        cost: 4450.0,
        grossProfit: 9450.0,
        marginPercentage: 68.0,
      ),
    ],
    categoryRanking: [
      CategoryProfitData(
        categoryName: 'فئة البرجر',
        revenue: 21111.11,
        cost: 5911.11,
        grossProfit: 15200.0,
        marginPercentage: 72.0,
      ),
      CategoryProfitData(
        categoryName: 'الدجاج والمقبلات',
        revenue: 13382.35,
        cost: 4282.35,
        grossProfit: 9100.0,
        marginPercentage: 68.0,
      ),
      CategoryProfitData(
        categoryName: 'المشروبات والحلويات',
        revenue: 6555.56,
        cost: 1245.56,
        grossProfit: 5310.0,
        marginPercentage: 81.0,
      ),
    ],
    equation:
        '42,300.00 ج.م الإيرادات − 12,690.00 ج.م تكلفة المبيعات = 29,610.00 ج.م إجمالي الربح',
  );

  static const LaborCostReportData defaultLaborCost = LaborCostReportData(
    period: 'وردية اليوم • 16 أبريل 2024',
    branchId: 'br_01',
    totalLaborCost: 4850.0,
    actualWorkingHours: 72.0,
    laborToSalesRatio: 11.5,
    laborToProfitRatio: 16.4,
    wageMix: [
      WageMixData(
        type: 'daily',
        label: 'أجور العمالة اليومية',
        amount: 1400.0,
        percentageOfTotal: 28.9,
      ),
      WageMixData(
        type: 'monthly',
        label: 'حصة الرواتب الشهرية',
        amount: 2800.0,
        percentageOfTotal: 57.7,
      ),
      WageMixData(
        type: 'overtime',
        label: 'الساعات الإضافية المعتمدة (OT-04)',
        amount: 650.0,
        percentageOfTotal: 13.4,
      ),
    ],
    departmentBreakdown: [
      DepartmentLaborData(
        department: 'BOH',
        departmentLabel: 'طهاة ومطبخ ساخن (BOH)',
        amount: 2450.0,
        percentageOfTotal: 50.5,
      ),
      DepartmentLaborData(
        department: 'FOH',
        departmentLabel: 'خدمة صالة وكاشير (FOH)',
        amount: 1600.0,
        percentageOfTotal: 33.0,
      ),
      DepartmentLaborData(
        department: 'Support',
        departmentLabel: 'نظافة ومساعدون وتوصيل',
        amount: 800.0,
        percentageOfTotal: 16.5,
      ),
    ],
  );

  static const ContributionReportData defaultContribution =
      ContributionReportData(
    period: 'وردية اليوم • 16 أبريل 2024',
    branchId: 'br_01',
    totalRevenue: 42300.0,
    cogs: 12690.0,
    grossProfit: 29610.0,
    laborCost: 4850.0,
    contributionMargin: 24760.0,
    contributionMarginPercentage: 58.53,
    waterfall: [
      WaterfallStepData(
        step: 1,
        label: 'إجمالي الإيرادات',
        amount: 42300.0,
        isDeduction: false,
      ),
      WaterfallStepData(
        step: 2,
        label: 'يخصم: تكلفة المبيعات (COGS)',
        amount: -12690.0,
        isDeduction: true,
      ),
      WaterfallStepData(
        step: 3,
        label: 'إجمالي الربح',
        amount: 29610.0,
        isDeduction: false,
      ),
      WaterfallStepData(
        step: 4,
        label: 'يخصم: تكلفة العمالة',
        amount: -4850.0,
        isDeduction: true,
      ),
      WaterfallStepData(
        step: 5,
        label: 'المساهمة التقديرية',
        amount: 24760.0,
        isDeduction: false,
      ),
    ],
    channelBreakdown: [
      ChannelContributionData(
        channel: 'dine_in_takeaway',
        channelLabel: 'مبيعات المطعم',
        revenue: 28400.0,
        contributionAmount: 17210.0,
        contributionMarginPercentage: 60.6,
      ),
      ChannelContributionData(
        channel: 'delivery_apps',
        channelLabel: 'مبيعات التوصيل',
        revenue: 13900.0,
        contributionAmount: 7550.0,
        contributionMarginPercentage: 54.3,
      ),
    ],
  );

  static const InventoryValuationData defaultInventoryValuation =
      InventoryValuationData(
    branchId: 'br_01',
    totalInventoryValue: 64280.0,
    totalItemsCount: 38,
    criticalItemsCount: 4,
    lowStockItemsCount: 7,
    categoryBreakdown: [
      InventoryCategoryValuationData(
        category: 'اللحوم والدواجن',
        totalValue: 32840.0,
        percentageOfTotal: 51.1,
        itemsCount: 8,
      ),
      InventoryCategoryValuationData(
        category: 'الأجبان ومنتجات الألبان',
        totalValue: 14200.0,
        percentageOfTotal: 22.1,
        itemsCount: 6,
      ),
      InventoryCategoryValuationData(
        category: 'الصوصات والزيوت',
        totalValue: 9850.0,
        percentageOfTotal: 15.3,
        itemsCount: 12,
      ),
      InventoryCategoryValuationData(
        category: 'المخبوزات والجاف والتغليف',
        totalValue: 7390.0,
        percentageOfTotal: 11.5,
        itemsCount: 12,
      ),
    ],
    stockItems: [
      InventoryStockItemData(
        id: 'stk_meat_01',
        sku: 'RAW-MEAT-102',
        name: 'لحم بقري مفروم (متبل جاهز)',
        category: 'اللحوم والدواجن',
        quantity: 8.0,
        unit: 'كجم',
        unitCost: 320.0,
        totalValue: 2560.0,
        stockLevel: 'critical',
        location: 'ثلاجة التجهيز الرئيسية BOH-01',
      ),
      InventoryStockItemData(
        id: 'stk_meat_02',
        sku: 'RAW-POULT-204',
        name: 'صدور دجاج فيليه متبلة',
        category: 'اللحوم والدواجن',
        quantity: 28.0,
        unit: 'كجم',
        unitCost: 185.0,
        totalValue: 5180.0,
        stockLevel: 'available',
        location: 'ثلاجة التجهيز الرئيسية BOH-01',
      ),
      InventoryStockItemData(
        id: 'stk_dairy_01',
        sku: 'DAIRY-CHD-08',
        name: 'جبن شيدر أحمر شرائح',
        category: 'الأجبان ومنتجات الألبان',
        quantity: 15.0,
        unit: 'كجم',
        unitCost: 240.0,
        totalValue: 3600.0,
        stockLevel: 'low',
        location: 'ثلاجة الألبان BOH-03',
      ),
      InventoryStockItemData(
        id: 'stk_sauce_01',
        sku: 'RAW-OIL-01',
        name: 'زيت تحمير نباتي نقي',
        category: 'الصوصات والزيوت',
        quantity: 35.0,
        unit: 'لتر',
        unitCost: 65.0,
        totalValue: 2275.0,
        stockLevel: 'available',
        location: 'مخزن الزيوت BOH-05',
      ),
    ],
  );

  // ============================================================================
  // Cost Repository Implementation Methods
  // ============================================================================

  @override
  Future<CogsReportData> getCogsReport({
    String? branchId,
    String? shiftId,
    String? startDate,
    String? endDate,
    double? targetCogsPct,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (branchId != null) queryParams['branch_id'] = branchId;
      if (shiftId != null) queryParams['shift_id'] = shiftId;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (targetCogsPct != null) {
        queryParams['target_cogs_pct'] = targetCogsPct.toString();
      }

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final response = await _apiClient.get('/cost/cogs$queryString');
      if (response.success && response.data != null) {
        final dataMap = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final result = CogsReportData.fromJson(dataMap);
        _cachedCogsReport = result;
        return result;
      }
      throw Exception(response.message ?? 'فشل في استخراج تقرير تكلفة المبيعات');
    } catch (e) {
      if (_cachedCogsReport != null) return _cachedCogsReport!;
      rethrow;
    }
  }

  @override
  Future<ConsumptionVarianceData> getConsumptionVarianceReport({
    String? branchId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (branchId != null) queryParams['branch_id'] = branchId;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final response = await _apiClient.get('/cost/variance$queryString');
      if (response.success && response.data != null) {
        final dataMap = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final result = ConsumptionVarianceData.fromJson(dataMap);
        _cachedVarianceReport = result;
        return result;
      }
      throw Exception(response.message ?? 'فشل في استخراج تقرير تباين الاستهلاك');
    } catch (e) {
      if (_cachedVarianceReport != null) return _cachedVarianceReport!;
      rethrow;
    }
  }

  @override
  Future<RecipeCostData> getRecipeCost({
    String itemId = 'item_1',
    double? targetFoodCostPct,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (targetFoodCostPct != null) {
        queryParams['target_food_cost_pct'] = targetFoodCostPct.toString();
      }

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final response =
          await _apiClient.get('/cost/recipe/$itemId$queryString');
      if (response.success && response.data != null) {
        final dataMap = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final result = RecipeCostData.fromJson(dataMap);
        _cachedRecipeCosts[itemId] = result;
        return result;
      }
      throw Exception(response.message ?? 'فشل في استخراج بطاقة تكلفة الصنف');
    } catch (e) {
      if (_cachedRecipeCosts.containsKey(itemId)) return _cachedRecipeCosts[itemId]!;
      rethrow;
    }
  }

  @override
  Future<GrossProfitReportData> getGrossProfitReport({
    String? branchId,
    String? shiftId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (branchId != null) queryParams['branch_id'] = branchId;
      if (shiftId != null) queryParams['shift_id'] = shiftId;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final response =
          await _apiClient.get('/cost/gross-profit$queryString');
      if (response.success && response.data != null) {
        final dataMap = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final result = GrossProfitReportData.fromJson(dataMap);
        _cachedGrossProfit = result;
        return result;
      }
      throw Exception(response.message ?? 'فشل في استخراج تقرير إجمالي الربح');
    } catch (e) {
      if (_cachedGrossProfit != null) return _cachedGrossProfit!;
      rethrow;
    }
  }

  @override
  Future<LaborCostReportData> getLaborCostReport({
    String? branchId,
    String? date,
    String? shiftId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (branchId != null) queryParams['branch_id'] = branchId;
      if (date != null) queryParams['date'] = date;
      if (shiftId != null) queryParams['shift_id'] = shiftId;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final response = await _apiClient.get('/cost/labor$queryString');
      if (response.success && response.data != null) {
        final dataMap = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final result = LaborCostReportData.fromJson(dataMap);
        _cachedLaborCost = result;
        return result;
      }
      throw Exception(response.message ?? 'فشل في استخراج تقرير تكلفة العمالة');
    } catch (e) {
      if (_cachedLaborCost != null) return _cachedLaborCost!;
      rethrow;
    }
  }

  @override
  Future<ContributionReportData> getContributionReport({
    String? branchId,
    String? shiftId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (branchId != null) queryParams['branch_id'] = branchId;
      if (shiftId != null) queryParams['shift_id'] = shiftId;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final response =
          await _apiClient.get('/cost/contribution$queryString');
      if (response.success && response.data != null) {
        final dataMap = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final result = ContributionReportData.fromJson(dataMap);
        _cachedContribution = result;
        return result;
      }
      throw Exception(response.message ?? 'فشل في استخراج تقرير المساهمة التقديرية');
    } catch (e) {
      if (_cachedContribution != null) return _cachedContribution!;
      rethrow;
    }
  }

  @override
  Future<InventoryValuationData> getInventoryValuationReport({
    String? branchId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (branchId != null) queryParams['branch_id'] = branchId;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final response = await _apiClient.get('/cost/inventory$queryString');
      if (response.success && response.data != null) {
        final dataMap = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final result = InventoryValuationData.fromJson(dataMap);
        _cachedInventory = result;
        return result;
      }
      throw Exception(response.message ?? 'فشل في استخراج تقرير تقييم المخزون');
    } catch (e) {
      if (_cachedInventory != null) return _cachedInventory!;
      rethrow;
    }
  }
}
