import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rms_app/core/di/service_locator.dart';
import 'package:rms_app/features/cost_reports/data/repositories/http_cost_repository.dart';
import 'package:rms_app/features/cost_reports/domain/repositories/cost_repository.dart';
import 'package:rms_app/features/cost_reports/presentation/screens/cogs_report_screen.dart';
import 'package:rms_app/features/cost_reports/presentation/screens/consumption_variance_screen.dart';
import 'package:rms_app/features/cost_reports/presentation/screens/recipe_cost_screen.dart';
import 'package:rms_app/features/cost_reports/presentation/screens/gross_profit_report_screen.dart';
import 'package:rms_app/features/cost_reports/presentation/screens/labor_cost_report_screen.dart';
import 'package:rms_app/features/cost_reports/presentation/screens/contribution_report_screen.dart';
import 'package:rms_app/features/cost_reports/presentation/screens/inventory_value_report_screen.dart';

class MockCostRepository implements CostRepository {
  @override
  Future<CogsReportData> getCogsReport({
    String? branchId,
    String? shiftId,
    String? startDate,
    String? endDate,
    double? targetCogsPct,
  }) async =>
      const CogsReportData(
        period: 'وردية تجريبية حية',
        branchId: 'br_01',
        branchName: 'فرع الاختبار الحي',
        netSales: 50000.0,
        totalCogs: 15000.0,
        cogsPercentage: 30.0,
        targetCogsPercentage: 32.0,
        operationalStatus: 'أداء ممتاز وفق الميزانية',
        isWithinBudget: true,
        categoryBreakdown: [
          CategoryCogsData(
            categoryName: 'اللحوم الفاخرة',
            costAmount: 9000.0,
            percentageOfTotalCost: 60.0,
          ),
        ],
        topContributingItems: [
          TopCogsItemData(
            itemId: 'item_test_01',
            itemName: 'برجر تيست فاخر',
            quantitySold: 40,
            unitCost: 75.0,
            totalCost: 3000.0,
          ),
        ],
      );

  @override
  Future<ConsumptionVarianceData> getConsumptionVarianceReport({
    String? branchId,
    String? startDate,
    String? endDate,
  }) async =>
      const ConsumptionVarianceData(
        period: 'مقارنة استهلاك تجريبية',
        branchId: 'br_01',
        totalTheoreticalCost: 10000.0,
        totalActualCost: 10500.0,
        totalVarianceCost: -500.0,
        overallVarianceRate: 5.0,
        monitoredItemsCount: 5,
        criticalItemsCount: 1,
        items: [
          VarianceIngredientData(
            sku: 'RAW-TEST-01',
            nameAr: 'خام اختباري مفروم',
            theoreticalQty: 10.0,
            actualQty: 11.0,
            varianceQty: 1.0,
            unit: 'كجم',
            unitCost: 200.0,
            varianceCost: 200.0,
            variancePercentage: 10.0,
            isCritical: true,
            status: 'حالة حرجة',
          ),
        ],
        sopPolicyNote: 'توجيه رقابي اختباري صارم',
      );

  @override
  Future<RecipeCostData> getRecipeCost({
    String itemId = 'item_1',
    double? targetFoodCostPct,
  }) async =>
      HttpCostRepository.defaultRecipeCost;

  @override
  Future<GrossProfitReportData> getGrossProfitReport({
    String? branchId,
    String? shiftId,
    String? startDate,
    String? endDate,
  }) async =>
      HttpCostRepository.defaultGrossProfit;

  @override
  Future<LaborCostReportData> getLaborCostReport({
    String? branchId,
    String? date,
    String? shiftId,
  }) async =>
      HttpCostRepository.defaultLaborCost;

  @override
  Future<ContributionReportData> getContributionReport({
    String? branchId,
    String? shiftId,
    String? startDate,
    String? endDate,
  }) async =>
      HttpCostRepository.defaultContribution;

  @override
  Future<InventoryValuationData> getInventoryValuationReport({
    String? branchId,
  }) async =>
      HttpCostRepository.defaultInventoryValuation;
}

void main() {
  setUp(() async {
    await sl.reset();
    await initServiceLocator();
  });

  group('Cost Domain Flutter Tests', () {
    testWidgets('CogsReportScreen renders default and dynamic report data',
        (WidgetTester tester) async {
      final mockRepo = MockCostRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: CogsReportScreen(repository: mockRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & dynamic data from repository
      expect(find.text('تقرير تكلفة المبيعات (COGS)'), findsOneWidget);
      expect(find.text('وردية تجريبية حية'), findsOneWidget);
      expect(find.textContaining('فرع الاختبار الحي'), findsOneWidget);
      expect(find.text('15,000 ج.م'), findsOneWidget);
      expect(find.text('50,000 ج.م'), findsOneWidget);
      expect(find.text('أداء ممتاز وفق الميزانية'), findsOneWidget);
      expect(find.text('اللحوم الفاخرة'), findsOneWidget);
      expect(find.text('برجر تيست فاخر'), findsOneWidget);
    });

    testWidgets(
        'ConsumptionVarianceScreen renders variance data & flags correctly',
        (WidgetTester tester) async {
      final mockRepo = MockCostRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ConsumptionVarianceScreen(repository: mockRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & dynamic data
      expect(find.text('الاستهلاك الفعلي مقابل النظري'), findsOneWidget);
      expect(find.text('مقارنة استهلاك تجريبية'), findsOneWidget);
      expect(find.text('+5.0%'), findsOneWidget);
      expect(find.text('5 أصناف'), findsOneWidget);
      expect(find.text('خامة واحدة'), findsOneWidget);
      expect(find.text('-500.00 ج.م'), findsOneWidget);
      expect(find.text('خام اختباري مفروم • RAW-TEST-01'), findsOneWidget);
      expect(find.text('توجيه رقابي اختباري صارم'), findsOneWidget);
    });

    testWidgets('RecipeCostScreen renders recipe BOM card correctly',
        (WidgetTester tester) async {
      final mockRepo = MockCostRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: RecipeCostScreen(repository: mockRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تكلفة صنف القائمة'), findsOneWidget);
      expect(find.textContaining('برجر كلاسيك'), findsWidgets);
      expect(find.text('180.00 ج.م'), findsWidgets);
      expect(find.text('54.00 ج.م'), findsWidgets);
      expect(find.text('30.0%'), findsWidgets);
    });

    testWidgets('GrossProfitReportScreen renders channel breakdown',
        (WidgetTester tester) async {
      final mockRepo = MockCostRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: GrossProfitReportScreen(repository: mockRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تقرير إجمالي الربح'), findsOneWidget);
      expect(find.text('29,610.00 ج.م'), findsOneWidget);
      expect(find.text('70.0%'), findsOneWidget);
      expect(find.text('مبيعات المطعم (صالة وسفري)'), findsOneWidget);
    });

    testWidgets('LaborCostReportScreen renders labor department distribution',
        (WidgetTester tester) async {
      final mockRepo = MockCostRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: LaborCostReportScreen(repository: mockRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تكلفة العمالة'), findsOneWidget);
      expect(find.text('4,850.00 ج.م'), findsOneWidget);
      expect(find.text('72 ساعة'), findsOneWidget);
      expect(find.text('طهاة ومطبخ ساخن (BOH)'), findsOneWidget);
    });

    testWidgets('ContributionReportScreen renders financial waterfall',
        (WidgetTester tester) async {
      final mockRepo = MockCostRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ContributionReportScreen(repository: mockRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المساهمة التقديرية'), findsWidgets);
      expect(find.text('24,760.00 ج.م'), findsWidgets);
      expect(find.text('إجمالي الإيرادات'), findsOneWidget);
      expect(find.text('يخصم: تكلفة المبيعات (COGS)'), findsOneWidget);
    });

    testWidgets('InventoryValueReportScreen renders capital valuation',
        (WidgetTester tester) async {
      final mockRepo = MockCostRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: InventoryValueReportScreen(repository: mockRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تقرير قيمة المخزون'), findsOneWidget);
      expect(find.text('64,280.00 ج.م'), findsOneWidget);
      expect(find.text('اللحوم والدواجن'), findsOneWidget);
    });
  });
}
