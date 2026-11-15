import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rms_app/core/network/authenticated_api.dart';
import 'package:rms_app/features/auth/data/repositories/api_auth_repository.dart';
import 'package:rms_app/features/auth/domain/entities/user_session.dart';
import 'package:rms_app/features/menu/data/repositories/api_menu_repository.dart';
import 'package:rms_app/features/menu/domain/entities/menu_item.dart';
import 'package:rms_app/features/menu/domain/entities/menu_item_request.dart';
import 'package:rms_app/features/menu/domain/repositories/menu_repository.dart';

const session = UserSession(
  id: 'user-id',
  name: 'مدير',
  email: 'ceo@test.local',
  role: StaffRole.ceo,
  token: 'access-token',
  refreshToken: 'refresh-token',
);
const category = {
  'id': 'category-id',
  'name': 'مشروبات',
  'sort_order': 2,
  'is_active': true,
};
const menuItem = {
  'id': 'item-id',
  'sku': 'DRINK-1',
  'name': 'قهوة',
  'name_en': 'Coffee',
  'category_id': 'category-id',
  'selling_price': 35.5,
  'kds_station': 'بار',
  'prep_time_minutes': 7,
  'description': 'قهوة عربية',
  'is_active': false,
};
const requestRow = {
  'id': 'request-id',
  'branch_id': 'branch-id',
  'requested_by': 'user-id',
  'item_name': 'قهوة',
  'requested_price': 35.5,
  'status': 'PENDING',
  'created_at': '2026-11-11T10:00:00Z',
  'justification': 'طلب العملاء',
};

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<ApiMenuRepository> repository(
  MockClient client, {
  UserSession user = session,
}) async {
  final auth = ApiAuthRepository(client: client, baseUrl: 'https://auth.test');
  await auth.persistSession(user);
  return ApiMenuRepository(
    AuthenticatedApi(auth, client: client, baseUrl: 'http://menu.test:9005/'),
  );
}

void main() {
  test(
    'reads Arabic items, nullable fields and category names from Go response arrays',
    () async {
      final repo = await repository(
        MockClient((request) async {
          expect(request.url.host, 'menu.test');
          expect(request.headers['authorization'], 'Bearer access-token');
          if (request.url.path == '/api/v1/menu/categories') {
            return jsonResponse([category]);
          }
          expect(request.url.path, '/api/v1/menu/items');
          return jsonResponse([
            menuItem,
            {
              ...menuItem,
              'id': 'uncategorized',
              'category_id': null,
              'name_en': null,
              'prep_time_minutes': null,
            },
          ]);
        }),
      );
      final items = await repo.getMenuItems();
      expect(items.first.nameAr, 'قهوة');
      expect(items.first.categoryName, 'مشروبات');
      expect(items.first.price, 35.5);
      expect(items.first.prepTimeMinutes, 7);
      expect(items.first.isActive, isFalse);
      expect(items.last.categoryId, isEmpty);
      expect(items.last.nameEn, isEmpty);
      expect(items.last.categoryName, 'بدون تصنيف');
    },
  );

  test(
    'create uses POST and edit uses PATCH preserving preparation and inactive state',
    () async {
      final writes = <http.Request>[];
      final repo = await repository(
        MockClient((request) async {
          writes.add(request);
          return jsonResponse(menuItem, 201);
        }),
      );
      const draft = MenuItem(
        id: '',
        sku: 'DRINK-1',
        barcode: '',
        nameAr: 'قهوة',
        nameEn: 'Coffee',
        categoryId: '',
        categoryName: '',
        price: 35.5,
        cost: 0,
        prepTimeMinutes: 7,
        description: 'قهوة عربية',
      );
      await repo.saveMenuItem(draft);
      await repo.saveMenuItem(draft.copyWith(id: 'item-id', isActive: false));
      expect(writes.map((write) => write.method), ['POST', 'PATCH']);
      expect(writes.last.url.path, '/api/v1/menu/items/item-id');
      final created = jsonDecode(writes.first.body) as Map;
      final updated = jsonDecode(writes.last.body) as Map;
      expect(created['sku'], 'DRINK-1');
      expect(created['selling_price'], 35.5);
      expect(created['actor_role'], 'CEO');
      expect(updated['is_active'], false);
      expect(updated['prep_time_minutes'], 7);
      expect(updated['description'], 'قهوة عربية');
      expect(updated.containsKey('sku'), isFalse);
      expect(created.containsKey('cost'), isFalse);
    },
  );

  test(
    'approval delegates creation to Go once and rejection sends the required reason',
    () async {
      final writes = <http.Request>[];
      final repo = await repository(
        MockClient((request) async {
          writes.add(request);
          return jsonResponse(menuItem, 201);
        }),
      );
      await repo.approveMenuItemRequest('request-id', 'NEW-SKU');
      await repo.rejectMenuItemRequest('other-id', 'غير متاح');
      expect(writes.length, 2);
      expect(writes.every((write) => write.method == 'PATCH'), isTrue);
      expect(writes.first.url.path, '/api/v1/menu/requests/request-id/approve');
      expect(jsonDecode(writes.first.body)['sku'], 'NEW-SKU');
      expect(writes.last.url.path, '/api/v1/menu/requests/other-id/reject');
      expect(jsonDecode(writes.last.body)['reason'], 'غير متاح');
    },
  );

  test(
    'branch requests use the signed-in branch and cannot directly create master items',
    () async {
      final writes = <http.Request>[];
      const manager = UserSession(
        id: 'manager',
        name: 'مدير الفرع',
        email: 'manager@test.local',
        role: StaffRole.branchManager,
        token: 'manager-token',
        branchId: 'assigned-branch',
      );
      final repo = await repository(
        MockClient((request) async {
          writes.add(request);
          return jsonResponse(requestRow, 201);
        }),
        user: manager,
      );
      await repo.createMenuItemRequest(
        const MenuRequestDraft(
          name: 'قهوة',
          price: 35.5,
          justification: 'طلب العملاء',
        ),
      );
      expect(jsonDecode(writes.single.body)['branch_id'], 'assigned-branch');
      expect(jsonDecode(writes.single.body)['item_name'], 'قهوة');
      expect(writes.single.url.path, '/api/v1/menu/requests');
      await expectLater(
        repo.approveMenuItemRequest('request-id', 'SKU'),
        throwsFormatException,
      );
      expect(writes.length, 1);
    },
  );

  test(
    'request details resolve through the list endpoint and preserve rejection status',
    () async {
      final repo = await repository(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/menu/requests');
          return jsonResponse([
            {
              ...requestRow,
              'status': 'REJECTED',
              'rejection_reason': 'السعر مرتفع',
            },
          ]);
        }),
      );
      final request = await repo.getMenuItemRequestById('request-id');
      expect(request!.status, MenuItemRequestStatus.rejected);
      expect(request.notes, 'السعر مرتفع');
      expect(request.requestDate.isUtc, isTrue);
      expect(await repo.getMenuItemRequestById('missing'), isNull);
    },
  );

  for (final status in [404, 403, 500]) {
    test(
      'item lookup distinguishes HTTP $status from an absent item',
      () async {
        final repo = await repository(
          MockClient(
            (request) async => jsonResponse({
              'error': {'code': 'failure', 'message': 'فشل الطلب'},
            }, status),
          ),
        );
        if (status == 404) {
          expect(await repo.getMenuItemById('missing'), isNull);
        } else {
          await expectLater(
            repo.getMenuItemById('missing'),
            throwsA(
              isA<ApiException>().having(
                (error) => error.statusCode,
                'status',
                status,
              ),
            ),
          );
        }
      },
    );
  }

  test(
    '401 refreshes at the auth host then retries the menu request with the new token',
    () async {
      var menuCalls = 0;
      final repo = await repository(
        MockClient((request) async {
          if (request.url.host == 'auth.test') {
            expect(request.url.path, '/api/v1/auth/refresh');
            return jsonResponse({
              'access_token': 'new-token',
              'refresh_token': 'new-refresh',
              'user': {
                'id': 'user-id',
                'name': 'مدير',
                'email': 'ceo@test.local',
                'role': 'CEO',
              },
            });
          }
          menuCalls++;
          if (menuCalls == 1) {
            return jsonResponse({
              'error': {'message': 'expired'},
            }, 401);
          }
          expect(request.headers['authorization'], 'Bearer new-token');
          return jsonResponse([category]);
        }),
      );
      expect((await repo.getCategories()).single.nameAr, 'مشروبات');
      expect(menuCalls, 2);
    },
  );

  test(
    'an invalid list payload is an error instead of an empty menu',
    () async {
      final repo = await repository(
        MockClient((request) async => jsonResponse({'unexpected': []})),
      );
      await expectLater(repo.getMenuItems(), throwsFormatException);
    },
  );
}
