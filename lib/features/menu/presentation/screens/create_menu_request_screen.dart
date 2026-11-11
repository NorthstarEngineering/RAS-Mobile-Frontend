import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/repositories/menu_repository.dart';
import '../widgets/menu_load_view.dart';

class CreateMenuRequestScreen extends StatefulWidget {
  const CreateMenuRequestScreen({super.key});
  @override
  State<CreateMenuRequestScreen> createState() =>
      _CreateMenuRequestScreenState();
}

class _CreateMenuRequestScreenState extends State<CreateMenuRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _justification = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    for (final controller in [_name, _price, _description, _justification]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await sl<MenuRepository>().createMenuItemRequest(
        MenuRequestDraft(
          name: _name.text.trim(),
          price: double.parse(_price.text.trim()),
          description: _description.text.trim(),
          justification: _justification.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الصنف')));
      context.pop(true);
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
  Widget build(BuildContext context) {
    final session = sl<AuthBloc>().state.session;
    final canRequest =
        session?.role == StaffRole.branchManager &&
        session!.branchId.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('طلب صنف جديد')),
      body: !canRequest
          ? const Center(child: Text('الطلب متاح لمدير فرع مرتبط بفرع فقط'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'الفرع: ${session.branchName.isEmpty ? session.branchId : session.branchName}',
                    ),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'اسم الصنف *',
                      ),
                      validator: (text) => text == null || text.trim().isEmpty
                          ? 'أدخل اسم الصنف'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'السعر المقترح *',
                      ),
                      validator: (text) {
                        final price = double.tryParse(text?.trim() ?? '');
                        return price == null || !price.isFinite || price <= 0
                            ? 'أدخل سعرًا أكبر من صفر'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(labelText: 'وصف الصنف'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _justification,
                      decoration: const InputDecoration(
                        labelText: 'مبرر الطلب',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_saving ? 'جارٍ الإرسال...' : 'إرسال الطلب'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
