import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/repositories/auth_repository.dart';

class CeoAccountManagementScreen extends StatefulWidget {
  const CeoAccountManagementScreen({super.key});

  @override
  State<CeoAccountManagementScreen> createState() =>
      _CeoAccountManagementScreenState();
}

class _CeoAccountManagementScreenState
    extends State<CeoAccountManagementScreen> {
  int _selectedTabIndex = 0; // 0 = Active Accounts, 1 = Create New Account

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController(text: 'RMS@2024Ops');

  String _selectedRole = 'BRANCH_MANAGER';
  String _selectedBranch = '';
  bool _mustChangePassword = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _accounts = [];
  bool _isLoadingAccounts = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await sl<AuthRepository>().listAccounts();
      if (mounted) setState(() => _accounts = accounts);
    } catch (error) {
      if (mounted) {
        final message = '$error';
        if (message.contains('انتهت الجلسة')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى'),
            ),
          );
          context.go('/login');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingAccounts = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await sl<AuthRepository>().createAccount(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        branchId: _selectedBranch.isEmpty ? null : _selectedBranch,
      );
      await _loadAccounts();
      if (mounted) {
        setState(() => _selectedTabIndex = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الحساب في قاعدة البيانات')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = '$error';
        if (message.contains('انتهت الجلسة')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى'),
            ),
          );
          context.go('/login');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('إدارة حسابات المدير التنفيذي'),
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            ),
            child: Text(
              'خاص بالـ CEO',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onErrorContainer,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Context Banner
            Container(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: AppDimens.paddingSm),
                  Expanded(
                    child: Text(
                      'إدارة مستخدمي النظام الداخلي • إنشاء وتعيين صلاحيات الموظفين عبر كافة الفروع.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Segmented Tab Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 0
                              ? AppColors.surfaceContainerLowest
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusLg,
                          ),
                          boxShadow: _selectedTabIndex == 0
                              ? const [
                                  BoxShadow(
                                    color: Color(0x06000000),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'الحسابات النشطة (${_accounts.length})',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _selectedTabIndex == 0
                                ? AppColors.onSurface
                                : AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 1
                              ? AppColors.surfaceContainerLowest
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusLg,
                          ),
                          boxShadow: _selectedTabIndex == 1
                              ? const [
                                  BoxShadow(
                                    color: Color(0x06000000),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+ إنشاء حساب جديد',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _selectedTabIndex == 1
                                ? AppColors.primary
                                : AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Tab View Content
            if (_selectedTabIndex == 0)
              _buildAccountsListView()
            else
              _buildCreateAccountForm(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsListView() {
    if (_isLoadingAccounts) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _accounts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final acc = _accounts[index];
        final isActive = acc['isActive'] as bool;
        return Container(
          padding: const EdgeInsets.all(AppDimens.paddingMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: AppDimens.paddingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          acc['name'] as String,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFEAF5EA)
                                : AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusFull,
                            ),
                          ),
                          child: Text(
                            isActive ? 'نشط' : 'معطل',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 10,
                              color: isActive
                                  ? const Color(0xFF2E8B2E)
                                  : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      acc['email'] as String,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${acc['role']} • ${acc['branch']}',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppColors.secondary),
                onPressed: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateAccountForm() {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إصدار بيانات اعتماد داخلية',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'للحسابات الإدارية والتشغيلية المعتمدة فقط',
              style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل للموظف *',
                hintText: 'مثال: محمود فهمي',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني المهني *',
                hintText: 'm.fahmy@rms-ops.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Role dropdown
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'الدور التشغيلي والصلاحية *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.admin_panel_settings_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'BRANCH_MANAGER',
                  child: Text('مدير فرع (Branch Manager)'),
                ),
                DropdownMenuItem(
                  value: 'SUPPLY_MANAGER',
                  child: Text('مدير الإمداد والتشغيل (Supply Manager)'),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _selectedRole = val ?? _selectedRole),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Branch dropdown
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedBranch,
              decoration: const InputDecoration(
                labelText: 'الفرع المخصص *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: '',
                  child: Text('بدون فرع - يمكن التعيين من النظام'),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _selectedBranch = val ?? _selectedBranch),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Temporary Password
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور المؤقتة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: AppDimens.paddingSm),

            // Must change password checkbox
            CheckboxListTile(
              value: _mustChangePassword,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'إلزام الموظف بتغيير كلمة المرور عند أول تسجيل دخول',
              ),
              activeColor: AppColors.primary,
              onChanged: (val) =>
                  setState(() => _mustChangePassword = val ?? true),
            ),
            const SizedBox(height: AppDimens.paddingLg),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _handleCreateAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('إصدار الحساب وبيانات الاعتماد'),
            ),
          ],
        ),
      ),
    );
  }
}
