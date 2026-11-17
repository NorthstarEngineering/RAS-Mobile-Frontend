import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../di/service_locator.dart';
import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../utils/file_saver.dart';

enum ExportFormat {
  pdf('pdf', 'مستند PDF رسمي (PDF)', 'تنسيق قياسي للطباعة والتوثيق والاعتماد الإداري', Icons.picture_as_pdf, 'application/pdf'),
  docx('docx', 'مستند Word قابل للتعديل (DOCX)', 'ملف مايكروسوفت وورد لتعديل النصوص وإعداد التقارير', Icons.description, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
  csv('csv', 'جدول بيانات Excel / CSV', 'ملف بيانات متوافق مع Excel للتحليل والمعادلات الحسابية', Icons.table_chart, 'text/csv; charset=utf-8');

  const ExportFormat(this.extension, this.label, this.description, this.icon, this.mimeType);

  final String extension;
  final String label;
  final String description;
  final IconData icon;
  final String mimeType;
}

Future<void> showReportExportDialog(
  BuildContext context, {
  required String reportType,
  required String reportTitle,
  bool isCostReport = false,
  String? branchId,
  String? period,
}) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => ReportExportDialog(
        reportType: reportType,
        reportTitle: reportTitle,
        isCostReport: isCostReport,
        branchId: branchId,
        period: period,
      ),
    );

class ReportExportDialog extends StatefulWidget {
  const ReportExportDialog({
    super.key,
    required this.reportType,
    required this.reportTitle,
    this.isCostReport = false,
    this.branchId,
    this.period,
  });

  final String reportType;
  final String reportTitle;
  final bool isCostReport;
  final String? branchId;
  final String? period;

  @override
  State<ReportExportDialog> createState() => _ReportExportDialogState();
}

class _ReportExportDialogState extends State<ReportExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  bool _isExporting = false;
  String? _errorMessage;

  Future<void> _performExport() async {
    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      final apiClient = sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient();
      final base = apiClient.baseUrl;
      final endpoint = widget.isCostReport
          ? '$base/cost/export/${widget.reportType}'
          : '$base/reports/export/${widget.reportType}';

      final queryParams = <String, String>{
        'format': _selectedFormat.extension,
      };
      if (widget.branchId != null && widget.branchId!.isNotEmpty) {
        queryParams['branchId'] = widget.branchId!;
      }
      if (widget.period != null && widget.period!.isNotEmpty) {
        queryParams['period'] = widget.period!;
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
      final headers = Map<String, String>.from(apiClient.defaultHeaders);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode != 200) {
        throw Exception(
          'فشل استخراج التقرير من الخادم (رمز الخطأ: ${response.statusCode})',
        );
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw Exception('ملف التقرير المستخرج فارغ');
      }

      // Extract filename from Content-Disposition header if available
      String filename = 'RMS_${widget.reportType}_${DateTime.now().millisecondsSinceEpoch}.${_selectedFormat.extension}';
      final disposition = response.headers['content-disposition'];
      if (disposition != null && disposition.contains('filename=')) {
        final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
        if (match != null && match.group(1) != null) {
          filename = match.group(1)!;
        }
      }

      await saveFile(
        bytes,
        filename,
        _selectedFormat.mimeType,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تصدير التقرير بنجاح: $filename'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.file_download_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تصدير: ${widget.reportTitle}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر الصيغة المناسبة لتصدير التقرير وتحميله مباشرة:',
              style: TextStyle(fontSize: 13, color: AppColors.secondary),
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],
            for (final format in ExportFormat.values)
              InkWell(
                onTap: _isExporting ? null : () => setState(() => _selectedFormat = format),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        _selectedFormat == format
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _selectedFormat == format
                            ? AppColors.primary
                            : AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Icon(format.icon, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              format.label,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              format.description,
                              style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _isExporting ? null : _performExport,
          icon: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download, size: 18),
          label: Text(_isExporting ? 'جارٍ التصدير...' : 'تحميل المستند'),
        ),
      ],
    );
  }
}
