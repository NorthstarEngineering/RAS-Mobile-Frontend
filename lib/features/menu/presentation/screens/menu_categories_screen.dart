import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/menu_category.dart';
import '../../domain/repositories/menu_repository.dart';
import '../widgets/menu_load_view.dart';

class MenuCategoriesScreen extends StatefulWidget {
  const MenuCategoriesScreen({super.key});
  @override
  State<MenuCategoriesScreen> createState() => _MenuCategoriesScreenState();
}

class _MenuCategoriesScreenState extends State<MenuCategoriesScreen> {
  final _repository = sl<MenuRepository>();
  final _name = TextEditingController();
  late Future<List<MenuCategory>> _categories;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _categories = _repository.getCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addCategory(List<MenuCategory> categories) async {
    if (_saving || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final order = categories.fold<int>(
        0,
        (highest, category) =>
            category.sortOrder > highest ? category.sortOrder : highest,
      );
      await _repository.addCategory(
        MenuCategory(
          id: '',
          nameAr: _name.text.trim(),
          nameEn: '',
          itemsCount: 0,
          sortOrder: order + 1,
        ),
      );
      if (!mounted) return;
      _name.clear();
      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت إضافة التصنيف')));
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(menuErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تصنيفات القائمة')),
    body: MenuLoadView<List<MenuCategory>>(
      future: _categories,
      onRetry: () => setState(_reload),
      builder: _list,
    ),
  );

  Widget _list(List<MenuCategory> categories) => RefreshIndicator(
    onRefresh: () async {
      setState(_reload);
    },
    child: ListView(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (sl<AuthBloc>().state.session?.role == StaffRole.ceo) ...[
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'اسم التصنيف الجديد'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : () => _addCategory(categories),
            child: Text(_saving ? 'جارٍ الحفظ...' : 'إضافة تصنيف'),
          ),
          const SizedBox(height: 24),
        ],
        if (categories.isEmpty)
          const Center(child: Text('لا توجد تصنيفات بعد')),
        ...categories.map(
          (category) => Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(category.nameAr),
              subtitle: Text(category.isActive ? 'نشط' : 'غير نشط'),
              trailing: Text('${category.sortOrder}'),
            ),
          ),
        ),
      ],
    ),
  );
}
