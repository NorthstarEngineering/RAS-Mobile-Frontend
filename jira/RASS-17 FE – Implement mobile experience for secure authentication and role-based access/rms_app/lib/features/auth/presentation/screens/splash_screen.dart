import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final List<String> _statuses = const [
    'جاري بدء جلسة المحطة الآمنة...',
    'مزامنة أجهزة ونقاط البيع...',
    'جاري التحقق من صلاحيات نقطة البيع...',
    'جاهز لمصادقة المشغّل',
  ];

  int _currentStep = 0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _startDiagnosticTimer();
  }

  void _startDiagnosticTimer() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) return;
      if (_currentStep < _statuses.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        timer.cancel();
        // Automatically route to login after terminal is ready
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            context.go('/login');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _onContinue() {
    _progressTimer?.cancel();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final progressFraction = (_currentStep + 1) / _statuses.length;
    final isDone = _currentStep == _statuses.length - 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.margin,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Environment Context / System Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.fullAll,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'بيئة التشغيل • الإصدار 2.4.1',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 11,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.wifi,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'متصل',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 11,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Center Operational Branding Block
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo container
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: AppRadius.xlAll,
                      boxShadow: AppShadows.sm,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'R',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 34,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'RMS TERMINAL',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'نظام إدارة المطاعم',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 13,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Diagnostics status & bar
                  SizedBox(
                    width: 280,
                    child: Column(
                      children: [
                        SizedBox.square(
                          dimension: 30,
                          child: isDone
                              ? const Icon(
                                  Symbols.check_circle,
                                  color: AppColors.primary,
                                  size: 28,
                                )
                              : const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary,
                                ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          isDone
                              ? 'المحطة جاهزة للاستخدام'
                              : _statuses[_currentStep],
                          style: AppTypography.bodySm.copyWith(
                            fontSize: 13,
                            color: isDone
                                ? AppColors.primary
                                : AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Linear diagnostic bar
                        ClipRRect(
                          borderRadius: AppRadius.fullAll,
                          child: LinearProgressIndicator(
                            value: progressFraction,
                            minHeight: 4,
                            backgroundColor: AppColors.surfaceContainerHigh,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bottom Terminal Actions & Security Footprint
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.xlAll,
                      boxShadow: AppShadows.sm,
                      border: isDone
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : null,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: AppSizes.controlHeight,
                      child: TextButton(
                        onPressed: _onContinue,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerLowest,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.xlAll,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'المتابعة لتسجيل الدخول',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(
                              Symbols.arrow_back,
                              size: 18,
                              color: AppColors.onSurface,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Symbols.lock,
                        size: 14,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'اتصال مشفّر للمؤسسة • TLS 1.3',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 12,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
