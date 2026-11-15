import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rms_app/core/di/service_locator.dart';
import 'package:rms_app/core/network/authenticated_api.dart';
import 'package:rms_app/features/auth/data/repositories/api_auth_repository.dart';
import 'package:rms_app/features/auth/domain/entities/user_session.dart';
import 'package:rms_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:rms_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rms_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:rms_app/features/menu/data/repositories/api_menu_repository.dart';
import 'package:rms_app/features/menu/domain/repositories/menu_repository.dart';
import 'package:rms_app/features/menu/presentation/screens/create_edit_menu_item_screen.dart';
import 'package:rms_app/features/menu/presentation/screens/menu_item_request_review_screen.dart';

void main() {
  late AuthBloc bloc;
  setUp(() async {
    await sl.reset();
  });
  tearDown(() async {
    await bloc.close();
    await sl.reset();
  });

  Future<void> connect(MockClient client) async {
    const session = UserSession(
      id: 'ceo-id',
      name: 'CEO',
      email: 'ceo@test.local',
      role: StaffRole.ceo,
      token: 'token',
    );
    final auth = ApiAuthRepository(client: client);
    await auth.persistSession(session);
    bloc = AuthBloc(loginUseCase: LoginUseCase(auth));
    final restored = bloc.stream.first;
    bloc.add(const SessionRestored(session));
    await restored;
    sl.registerSingleton<AuthBloc>(bloc);
    sl.registerSingleton<MenuRepository>(
      ApiMenuRepository(
        AuthenticatedApi(auth, client: client, baseUrl: 'http://menu.test'),
      ),
    );
  }

  testWidgets(
    'approval requires SKU, sends one PATCH, and returns to the list',
    (tester) async {
      final writes = <http.Request>[];
      await connect(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'req-id',
                  'branch_id': 'branch-id',
                  'requested_by': 'manager-id',
                  'item_name': 'Coffee',
                  'requested_price': 30,
                  'status': 'PENDING',
                  'created_at': '2026-11-11T10:00:00Z',
                },
              ]),
              200,
            );
          }
          writes.add(request);
          return http.Response('{}', 201);
        }),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Requests')),
          ),
          GoRoute(
            path: '/review',
            builder: (context, state) =>
                const MenuItemRequestReviewScreen(requestId: 'req-id'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/review');
      await tester.pumpAndSettle();
      final approve = find.text('الموافقة وإضافة الصنف');
      await tester.scrollUntilVisible(
        approve,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(find.text('أدخل كود SKU للصنف'), findsOneWidget);
      expect(writes, isEmpty);
      await tester.enterText(find.byType(TextField).first, 'COFFEE-1');
      await tester.scrollUntilVisible(
        approve,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(writes.length, 1);
      expect(writes.single.method, 'PATCH');
      expect(jsonDecode(writes.single.body)['sku'], 'COFFEE-1');
      expect(find.text('Requests'), findsOneWidget);
    },
  );

  testWidgets(
    'empty categories allow creating an uncategorized item and save failures retain input',
    (tester) async {
      var saves = 0;
      await connect(
        MockClient((request) async {
          if (request.method == 'GET') return http.Response('[]', 200);
          saves++;
          expect(jsonDecode(request.body)['category_id'], '');
          return http.Response(
            jsonEncode({
              'error': {'message': 'SKU already exists'},
            }),
            409,
          );
        }),
      );
      await tester.pumpWidget(
        const MaterialApp(home: CreateEditMenuItemScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('بدون تصنيف'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'Coffee');
      await tester.enterText(find.byType(TextFormField).at(2), 'COFFEE-1');
      await tester.enterText(find.byType(TextFormField).at(3), '30');
      final save = find.text('حفظ الصنف');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('SKU already exists'), findsOneWidget);
      expect(saves, 1);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('حفظ الصنف'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
