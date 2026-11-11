import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';
import '../widgets/menu_load_view.dart';

class MenuItemDetailsScreen extends StatefulWidget {
  const MenuItemDetailsScreen({super.key, required this.itemId});
  final String itemId;
  @override
  State<MenuItemDetailsScreen> createState() => _MenuItemDetailsScreenState();
}

class _MenuItemDetailsScreenState extends State<MenuItemDetailsScreen> {
  late Future<MenuItem?> _item;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _item = sl<MenuRepository>().getMenuItemById(widget.itemId);
  }

  Future<void> _edit() async {
    await context.push('/menu/edit/${widget.itemId}');
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تفاصيل الصنف')),
    body: MenuLoadView<MenuItem?>(
      future: _item,
      onRetry: () => setState(_reload),
      builder: (item) => item == null
          ? const Center(child: Text('الصنف غير موجود'))
          : _details(item),
    ),
  );

  Widget _details(MenuItem item) => ListView(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    children: [
      const Icon(Icons.restaurant_menu, size: 64),
      Text(item.nameAr, style: Theme.of(context).textTheme.headlineSmall),
      if (item.nameEn.isNotEmpty) Text(item.nameEn),
      ListTile(title: const Text('كود الصنف'), subtitle: Text(item.sku)),
      ListTile(title: const Text('التصنيف'), subtitle: Text(item.categoryName)),
      ListTile(
        title: const Text('سعر البيع'),
        subtitle: Text('${item.price.toStringAsFixed(2)} ج.م'),
      ),
      ListTile(
        title: const Text('الحالة'),
        subtitle: Text(item.isActive ? 'نشط' : 'معطل'),
      ),
      ListTile(
        title: const Text('محطة التحضير'),
        subtitle: Text(
          item.kitchenStation.isEmpty ? 'غير محددة' : item.kitchenStation,
        ),
      ),
      ListTile(
        title: const Text('وقت التحضير'),
        subtitle: Text('${item.prepTimeMinutes} دقيقة'),
      ),
      if (item.description.isNotEmpty)
        ListTile(title: const Text('الوصف'), subtitle: Text(item.description)),
      if (sl<AuthBloc>().state.session?.role == StaffRole.ceo)
        FilledButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.edit),
          label: const Text('تعديل الصنف'),
        ),
    ],
  );
}
