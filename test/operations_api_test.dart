import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rms_app/core/network/authenticated_api.dart';
import 'package:rms_app/features/auth/data/repositories/api_auth_repository.dart';
import 'package:rms_app/features/auth/domain/entities/user_session.dart';
import 'package:rms_app/features/menu/data/repositories/api_item_cost_repository.dart';
import 'package:rms_app/features/operations/operations_api.dart';

const branchId = 'e08e42c4-e63a-4498-b481-5ee909e699a0';
const itemId = '9e22d420-be85-4ddb-a1d6-074621dce6fa';
const account = UserSession(
  id: itemId,
  name: 'Manager',
  email: 'manager@test.local',
  role: StaffRole.branchManager,
  token: 'test-access',
  branchId: branchId,
);

Future<AuthenticatedApi> connect(http.Client client) async {
  final auth = ApiAuthRepository();
  await auth.persistSession(account);
  return AuthenticatedApi(auth, client: client, baseUrl: 'https://api.test');
}

void main() {
  test(
    'first-login password rotation persists the new unrestricted session',
    () async {
      Map<String, Object?> profile(bool requiresChange) => {
        'id': itemId,
        'name': account.name,
        'email': account.email,
        'role': 'CEO',
        'must_change_password': requiresChange,
      };
      final auth = ApiAuthRepository(
        client: MockClient((request) async {
          final changing = request.url.path.endsWith('/change-password');
          if (changing) {
            expect(request.headers['authorization'], 'Bearer restricted');
            expect(jsonDecode(request.body), {
              'current_password': 'temporary1',
              'new_password': 'replacement2',
            });
          }
          return http.Response(
            jsonEncode({
              'access_token': changing ? 'new-token' : 'restricted',
              'refresh_token': changing ? 'new-refresh' : 'old-refresh',
              'user': profile(!changing),
            }),
            200,
          );
        }),
        baseUrl: 'https://auth.test',
      );
      final initial = await auth.login(
        identifier: account.email,
        password: 'temporary1',
      );
      expect(initial.mustChangePassword, isTrue);
      expect(
        UserSession.fromStorage(initial.toStorage()).mustChangePassword,
        isTrue,
      );
      final updated = await auth.changePassword(
        currentPassword: 'temporary1',
        newPassword: 'replacement2',
      );
      expect(updated.mustChangePassword, isFalse);
      expect(await auth.getCurrentSession(), updated);
      expect((await auth.authHeaders())['authorization'], 'Bearer new-token');
    },
  );

  test(
    'a zero-count stock adjustment uses the stock gateway and returns the new balance',
    () async {
      final api = await connect(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/stock/movements');
          expect(jsonDecode(request.body), {
            'good_id': itemId,
            'quantity': 0,
            'reason': 'Count',
            'type': 'ADJUSTMENT',
          });
          return http.Response('{"quantity_after":"0"}', 201);
        }),
      );
      final op = OperationsApi(
        api,
        account,
      ).stock.singleWhere((op) => op.title == 'تسوية الرصيد');
      final quantity = op.fields.singleWhere((f) => f.key == 'quantity');
      expect(
        await op.run({
          'good_id': itemId,
          'quantity': quantity.parse('0'),
          'reason': 'Count',
        }),
        {'quantity_after': '0'},
      );
    },
  );

  test(
    'branch manager can filter attendance reports and cannot open CEO audit',
    () async {
      final api = await connect(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/reports/attendance');
          expect(request.url.queryParameters, {'from': '2026-11-01'});
          return http.Response('{"total":2}', 200);
        }),
      );
      final reports = OperationsApi(api, account).reports;
      expect(
        reports.map((entry) => entry.title),
        isNot(contains('سجل التدقيق')),
      );
      final report = reports.singleWhere((op) => op.title == 'تقرير الحضور');
      expect(await report.run({'from': '2026-11-01'}), {'total': 2});
    },
  );

  test(
    'branch manager opens a shift for their own branch and account',
    () async {
      final api = await connect(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/sales/shifts/open');
          expect(jsonDecode(request.body), {
            'opening_float': 10.0,
            'branch_id': branchId,
            'manager_id': account.id,
          });
          return http.Response('{"status":"OPEN"}', 201);
        }),
      );
      final opening = OperationsApi(api, account).sales.first;
      final reply = await opening.run({'opening_float': 10.0});
      expect(reply, {'status': 'OPEN'});
    },
  );

  test(
    'sale item lines preserve quantity and reject a malformed line',
    () async {
      final api = await connect(
        MockClient((_) async => http.Response('{}', 200)),
      );
      final sale = OperationsApi(
        api,
        account,
      ).sales.singleWhere((operation) => operation.title == 'تسجيل بيع');
      final field = sale.fields.singleWhere((field) => field.key == 'items');
      expect(field.parse('$itemId,2.5\n$itemId,1'), [
        {'menu_item_id': itemId, 'quantity': 2.5},
        {'menu_item_id': itemId, 'quantity': 1.0},
      ]);
      expect(() => field.parse('$itemId,-1'), throwsFormatException);
    },
  );

  test(
    'transfer receipt keeps zero quantity and forwards only bearer identity',
    () async {
      final api = await connect(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/transfers/$itemId/receive');
          expect(request.headers['authorization'], 'Bearer test-access');
          expect(request.headers['x-user-role'], isNull);
          expect(jsonDecode(request.body), {
            'received_quantity': 0,
            'note': 'No delivery',
          });
          return http.Response('{"data":{"status":"RECEIVED"}}', 200);
        }),
      );
      final receipt = OperationsApi(api, account).transfers.last;
      expect(
        await receipt.run({
          'id': itemId,
          'received_quantity': 0,
          'note': 'No delivery',
        }),
        {
          'data': {'status': 'RECEIVED'},
        },
      );
    },
  );

  test(
    'branch supply view only renders requests for the signed-in branch',
    () async {
      final api = await connect(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/central-kitchen/supply/requests');
          return http.Response(
            jsonEncode([
              {'id': 'own', 'branch_id': branchId},
              {'id': 'other', 'branch_id': itemId},
            ]),
            200,
          );
        }),
      );
      final list = OperationsApi(api, account).supply.first;
      expect(await list.run({}), [
        {'id': 'own', 'branch_id': branchId},
      ]);
    },
  );

  test(
    'updating cost retains recipe components the API would otherwise delete',
    () async {
      var amount = 10.0;
      final components = [
        {'good_id': itemId, 'quantity': 1.5, 'unit': 'kg'},
      ];
      final api = await connect(
        MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, '/api/v1/cost/items');
            final body = jsonDecode(request.body);
            expect(body['components'], components);
            amount = (body['cost_amount'] as num).toDouble();
            return http.Response('{"status":"saved"}', 200);
          }
          expect(request.url.path, '/api/v1/cost/items/$itemId');
          return http.Response(
            jsonEncode({
              'menu_item_id': itemId,
              'cost_amount': amount,
              'gross_profit': 30 - amount,
              'food_cost_pct': amount / 30 * 100,
              'components': components,
            }),
            200,
          );
        }),
      );
      final updated = await ApiItemCostRepository(api).updateAmount(itemId, 12);
      expect(updated?.amount, 12);
      expect(updated?.grossProfit, 18);
    },
  );
}
