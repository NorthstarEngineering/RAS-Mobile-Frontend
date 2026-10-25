import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/http_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';

class CeoAccountManagementScreen extends StatefulWidget {
  const CeoAccountManagementScreen({super.key, this.authRepository});

  final HttpAuthRepository? authRepository;

  @override
  State<CeoAccountManagementScreen> createState() =>
      _CeoAccountManagementScreenState();
}

class _CeoAccountManagementScreenState
    extends State<CeoAccountManagementScreen> {
  int _selectedTabIndex = 0; // 0 = Active Accounts, 1 = Create New Account

  static const List<String> _availableRoles = [
    'مدير فرع (Branch Manager)',
    'مسؤول وردية (Shift Supervisor)',
    'محاسب مالي للفرع',
    'مدير مطبخ وتشغيل (Head Chef)',
    'أمين صندوق (Cashier)',
  ];

  static const List<String> _availableBranches = [
    'فرع وسط البلد (#01)',
    'فرع المعادي (#02)',
    'فرع التجمع (#03)',
    'فرع الشيخ زايد (#04)',
    'الفرع الرئيسي - الإدارة',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'مدير فرع (Branch Manager)';
  String _selectedBranch = 'فرع وسط البلد (#01)';
  bool _mustChangePassword = true;
  bool _isSubmitting = false;

  late final HttpAuthRepository _authRepository;

  final List<Map<String, dynamic>> _mockAccounts = [];
  bool _isLoadingAccounts = false;
  String? _accountsError;

  @override
  void initState() {
    super.initState();
    if (widget.authRepository != null) {
      _authRepository = widget.authRepository!;
    } else if (sl.isRegistered<HttpAuthRepository>()) {
      _authRepository = sl<HttpAuthRepository>();
    } else if (sl.isRegistered<AuthRepository>() &&
        sl<AuthRepository>() is HttpAuthRepository) {
      _authRepository = sl<AuthRepository>() as HttpAuthRepository;
    } else {
      _authRepository = HttpAuthRepository(
        apiClient: sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null,
      );
    }
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoadingAccounts = true;
      _accountsError = null;
    });
    try {
      final accounts = await _authRepository.getAccounts();
      if (mounted) {
        setState(() {
          _mockAccounts
            ..clear()
            ..addAll(accounts);
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAccounts = false;
          _accountsError = 'تعذر تحميل قائمة الحسابات: $e';
        });
      }
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

    final pwd = _passwordController.text.trim();
    if (pwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور يجب أن لا تقل عن 6 أحرف'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final newAccount = {
      'name': _nameController.text.trim(),
      'fullNameAr': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'identifier': _emailController.text.trim(),
      'password': pwd,
      'role': _selectedRole,
      'branch': _selectedBranch,
      'isActive': true,
      'mustChangePassword': _mustChangePassword,
    };

    try {
      await _authRepository.createAccount(newAccount);
      await _loadAccounts();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _selectedTabIndex = 0;
          _nameController.clear();
          _emailController.clear();
          _phoneController.clear();
          _passwordController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الحساب بنجاح'),
            backgroundColor: Color(0xFF2E8B2E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إنشاء الحساب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                          'الحسابات (${_mockAccounts.length})',
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_accountsError != null) {
      return Container(
        padding: const EdgeInsets.all(AppDimens.paddingLg),
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 36),
            const SizedBox(height: 8),
            Text(
              _accountsError!,
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadAccounts,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_mockAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppDimens.paddingXl),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.people_outline, color: AppColors.secondary, size: 40),
            const SizedBox(height: 8),
            Text(
              'لا توجد حسابات مسجلة حالياً في قاعدة البيانات',
              style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadAccounts,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث القائمة'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mockAccounts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final acc = _mockAccounts[index];
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
                      '${acc['roleArabic'] ?? acc['role']} • ${acc['branch']}',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إجراءات الحساب',
                icon: const Icon(Icons.more_vert, color: AppColors.secondary),
                onSelected: (action) {
                  if (action == 'toggle') {
                    _toggleAccountStatus(index);
                  } else if (action == 'edit') {
                    _showEditAccountDialog(acc, index);
                  } else if (action == 'delete') {
                    _showDeleteAccountDialog(acc, index);
                  } else {
                    _showAccountDetails(context, acc);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(isActive ? 'تعطيل الحساب' : 'تنشيط الحساب'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('تعديل الحساب'),
                  ),
                  const PopupMenuItem(
                    value: 'details',
                    child: Text('عرض بيانات الحساب'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'حذف الحساب',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleAccountStatus(int accountIndex) async {
    final acc = _mockAccounts[accountIndex];
    final targetActive = !(acc['isActive'] as bool);
    try {
      await _authRepository.toggleAccountStatus(
        email: acc['email'] as String,
        isActive: targetActive,
        id: acc['id'] as String?,
      );
      if (mounted) {
        setState(() => _mockAccounts[accountIndex]['isActive'] = targetActive);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              targetActive ? 'تم تنشيط الحساب بنجاح' : 'تم تعطيل الحساب بنجاح',
            ),
            backgroundColor: const Color(0xFF2E8B2E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحديث حالة الحساب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditAccountDialog(
    Map<String, dynamic> account,
    int index,
  ) async {
    final nameCtrl = TextEditingController(text: account['name'] as String? ?? '');
    final pwdCtrl = TextEditingController();
    String currentRole = account['role'] as String? ?? _availableRoles.first;
    String currentBranch = account['branch'] as String? ?? _availableBranches.first;
    if (!_availableRoles.contains(currentRole)) currentRole = _availableRoles.first;
    if (!_availableBranches.contains(currentBranch)) currentBranch = _availableBranches.first;

    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'تعديل بيانات الحساب',
            style: AppTypography.headlineSm.copyWith(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: currentRole,
                  decoration: const InputDecoration(labelText: 'الدور الوظيفي'),
                  items: _availableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setDialogState(() => currentRole = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: currentBranch,
                  decoration: const InputDecoration(labelText: 'فرع العمل'),
                  items: _availableBranches.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setDialogState(() => currentBranch = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pwdCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة مرور جديدة (اختياري)',
                    hintText: 'اتركها فارغة للإبقاء على الحالية',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final updatePayload = <String, dynamic>{
                  'name': nameCtrl.text.trim(),
                  'fullNameAr': nameCtrl.text.trim(),
                  'role': currentRole,
                  'branch': currentBranch,
                };
                if (pwdCtrl.text.trim().isNotEmpty) {
                  updatePayload['password'] = pwdCtrl.text.trim();
                }
                Navigator.of(dialogCtx).pop();
                try {
                  await _authRepository.updateAccount(
                    id: account['id'] as String,
                    updateData: updatePayload,
                  );
                  await _loadAccounts();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث بيانات الحساب بنجاح'),
                        backgroundColor: Color(0xFF2E8B2E),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تعذر تحديث الحساب: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(
    Map<String, dynamic> account,
    int index,
  ) async {
    final currentSession = await _authRepository.getCurrentSession();
    final accountId = account['id'] as String?;
    final accountEmail = (account['email'] as String? ?? '').toLowerCase();

    // Guard: Prevent CEO from deleting self
    if (currentSession != null &&
        (currentSession.id == accountId || currentSession.email.toLowerCase() == accountEmail)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن للمدير التنفيذي حذف حسابه الشخصي الحالي'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تأكيد حذف الحساب'),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف حساب "${account['name']}" نهائياً؟ سيتم إلغاء كافة جلسات العمل المرتبطة بهذا الحساب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await _authRepository.deleteAccount(id: account['id'] as String);
                if (mounted) {
                  setState(() {
                    _mockAccounts.removeAt(index);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الحساب بنجاح'),
                      backgroundColor: Color(0xFF2E8B2E),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تعذر حذف الحساب: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountDetails(
    BuildContext context,
    Map<String, dynamic> account,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(account['name'] as String),
        content: Text(
          '${account['email']}\n${account['role']} • ${account['branch']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
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
                  value: 'مدير فرع (Branch Manager)',
                  child: Text('مدير فرع (Branch Manager)'),
                ),
                DropdownMenuItem(
                  value: 'مسؤول وردية (Shift Supervisor)',
                  child: Text('مسؤول وردية (Shift Supervisor)'),
                ),
                DropdownMenuItem(
                  value: 'محاسب مالي للفرع',
                  child: Text('محاسب مالي للفرع'),
                ),
                DropdownMenuItem(
                  value: 'مدير مطبخ وتشغيل (Head Chef)',
                  child: Text('مدير مطبخ وتشغيل (Head Chef)'),
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
                  value: 'فرع وسط البلد (#01)',
                  child: Text('فرع وسط البلد (#01)'),
                ),
                DropdownMenuItem(
                  value: 'فرع المعادي (#02)',
                  child: Text('فرع المعادي (#02)'),
                ),
                DropdownMenuItem(
                  value: 'فرع التجمع (#03)',
                  child: Text('فرع التجمع (#03)'),
                ),
                DropdownMenuItem(
                  value: 'فرع الشيخ زايد (#04)',
                  child: Text('فرع الشيخ زايد (#04)'),
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
                labelText: 'كلمة المرور الأولية (مطلوبة)',
                hintText: 'أدخل كلمة مرور قوية للموظف الجديد',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().length < 6) {
                  return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                }
                return null;
              },
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
