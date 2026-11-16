import '../../core/network/authenticated_api.dart';
import '../auth/domain/entities/user_session.dart';

typedef Fields = Map<String, Object?>;
typedef OperationCall = Future<Object?> Function(Fields fields);

enum InputKind { text, id, positive, nonnegative, number, lines, date }

class OperationField {
  const OperationField(
    this.key,
    this.label, {
    this.kind = InputKind.text,
    this.optional = false,
    this.choices = const [],
    this.initial = '',
    this.columns = const [],
  });
  final String key;
  final String label;
  final InputKind kind;
  final bool optional;
  final List<String> choices;
  final String initial;
  final List<OperationField> columns;

  Object? parse(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      if (optional) return null;
      throw FormatException('أدخل $label');
    }
    if (choices.isNotEmpty && !choices.contains(input)) {
      throw FormatException('اختر $label');
    }
    return switch (kind) {
      InputKind.id => _parseId(input),
      InputKind.positive ||
      InputKind.nonnegative ||
      InputKind.number => _parseNumber(input),
      InputKind.lines => _parseRows(input),
      InputKind.date => _parseDate(input),
      InputKind.text => input,
    };
  }

  String _parseDate(String input) {
    final date = DateTime.tryParse(input);
    if (date == null || date.toIso8601String().split('T').first != input) {
      throw FormatException('تاريخ $label غير صالح');
    }
    return input;
  }

  String _parseId(String input) {
    final pattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!pattern.hasMatch(input)) {
      throw FormatException('معرّف $label غير صالح');
    }
    return input;
  }

  double _parseNumber(String input) {
    final number = double.tryParse(input);
    if (number == null ||
        !number.isFinite ||
        (kind == InputKind.positive && number <= 0) ||
        (kind == InputKind.nonnegative && number < 0)) {
      throw FormatException('قيمة $label غير صالحة');
    }
    return number;
  }

  List<Fields> _parseRows(String input) =>
      input.split('\n').where((line) => line.trim().isNotEmpty).map((line) {
        final parts = line.split(',');
        if (parts.length != columns.length) {
          throw FormatException('راجع ترتيب خانات $label في كل سطر');
        }
        return {
          for (var i = 0; i < columns.length; i++)
            columns[i].key: columns[i].parse(parts[i]),
        };
      }).toList();
}

class Operation {
  const Operation(
    this.title,
    this.fields,
    this.run, {
    this.changesData = false,
  });
  final String title;
  final List<OperationField> fields;
  final OperationCall run;
  final bool changesData;
}

const _branch = OperationField('branch_id', 'معرّف الفرع', kind: InputKind.id);
const _good = OperationField('good_id', 'معرّف الخامة', kind: InputKind.id);
const _item = OperationField(
  'menu_item_id',
  'معرّف صنف المنيو',
  kind: InputKind.id,
);
const _shift = OperationField('shift_id', 'معرّف الوردية', kind: InputKind.id);
const _request = OperationField('id', 'معرّف الطلب', kind: InputKind.id);
const _reason = OperationField('reason', 'السبب');
const _note = OperationField('note', 'ملاحظات', optional: true);
const _priority = OperationField(
  'priority',
  'الأولوية',
  choices: ['NORMAL', 'URGENT'],
  initial: 'NORMAL',
);
const _quantity = OperationField(
  'quantity',
  'الكمية',
  kind: InputKind.positive,
);
const _amount = OperationField(
  'amount',
  'قيمة الخصم',
  kind: InputKind.positive,
);

const _search = OperationField('q', 'بحث', optional: true);
const _page = OperationField('page', 'رقم الصفحة', initial: '1');
const _dates = [
  OperationField(
    'from',
    'من تاريخ (YYYY-MM-DD)',
    kind: InputKind.date,
    optional: true,
  ),
  OperationField(
    'to',
    'إلى تاريخ (YYYY-MM-DD)',
    kind: InputKind.date,
    optional: true,
  ),
];

class OperationsApi {
  const OperationsApi(this._api, this._session);
  final AuthenticatedApi _api;
  final UserSession _session;

  bool get _ceo => _session.role == StaffRole.ceo;
  bool get _manager => _session.role == StaffRole.branchManager;
  String get _role => _session.role.code.toUpperCase();
  List<OperationField> get _branchFields => _ceo ? [_branch] : [];
  Object? _branchId(Fields fields) =>
      _ceo ? fields['branch_id'] : _session.branchId;

  String _id(Fields fields, String key) =>
      Uri.encodeComponent(fields[key] as String);

  List<Operation> get sales => [
    Operation(
      'فتح وردية',
      [
        ..._branchFields,
        if (_ceo)
          const OperationField(
            'manager_id',
            'معرّف مدير الوردية',
            kind: InputKind.id,
          ),
        const OperationField(
          'opening_float',
          'عهدة بداية الوردية',
          kind: InputKind.nonnegative,
          initial: '0',
        ),
      ],
      (f) => _api.post('/api/v1/sales/shifts/open', {
        ...f,
        'branch_id': _branchId(f),
        'manager_id': _ceo ? f['manager_id'] : _session.id,
      }),
      changesData: true,
    ),
    Operation(
      'تسجيل بيع',
      [
        _shift,
        const OperationField(
          'channel',
          'قناة البيع',
          choices: ['RESTAURANT', 'DELIVERY'],
          initial: 'RESTAURANT',
        ),
        const OperationField(
          'items',
          'الأصناف',
          kind: InputKind.lines,
          columns: [_item, _quantity],
        ),
      ],
      (f) => _api.post('/api/v1/sales/', f),
      changesData: true,
    ),
    Operation(
      'إضافة خصم',
      [_shift, _amount, _reason],
      (f) => _api.post('/api/v1/sales/discounts', f),
      changesData: true,
    ),
    Operation(
      'إلغاء خصم',
      [const OperationField('id', 'معرّف الخصم', kind: InputKind.id), _reason],
      (f) => _api.patch('/api/v1/sales/discounts/${_id(f, 'id')}/cancel', {
        'reason': f['reason'],
      }),
      changesData: true,
    ),
    Operation(
      'إغلاق وردية',
      [_shift],
      (f) => _api.patch('/api/v1/sales/shifts/${_id(f, 'shift_id')}/close', {}),
      changesData: true,
    ),
    Operation(
      'ملخص وردية',
      [_shift],
      (f) => _api.get('/api/v1/sales/shifts/${_id(f, 'shift_id')}/summary'),
    ),
  ];

  List<Operation> get inventory => [
    Operation(
      'الخامات',
      [],
      (_) async =>
          await _api.get('/api/v1/central-kitchen/inventory/goods') ?? const [],
    ),
    Operation(
      'تفاصيل خامة',
      [_good],
      (f) => _api.get(
        '/api/v1/central-kitchen/inventory/goods/${_id(f, 'good_id')}',
      ),
    ),
    if (_ceo)
      Operation(
        'إضافة خامة',
        const [
          OperationField('sku', 'كود الخامة'),
          OperationField('name', 'اسم الخامة'),
          OperationField('unit', 'وحدة القياس'),
          OperationField('unit_cost', 'تكلفة الوحدة', kind: InputKind.positive),
          OperationField('category', 'التصنيف', optional: true),
          OperationField('description', 'الوصف', optional: true),
          OperationField(
            'initial_qty',
            'الكمية الابتدائية',
            kind: InputKind.nonnegative,
            optional: true,
          ),
          OperationField(
            'reorder_level',
            'حد إعادة الطلب',
            kind: InputKind.nonnegative,
            optional: true,
          ),
          OperationField(
            'max_capacity',
            'السعة القصوى',
            kind: InputKind.nonnegative,
            optional: true,
          ),
        ],
        (f) => _api.post('/api/v1/central-kitchen/inventory/goods', f),
        changesData: true,
      ),
  ];

  static const _stock = '/api/v1/stock';
  static const _reports = '/api/v1/reports';

  List<Operation> get stock => [
    Operation('أرصدة الخامات', [
      ..._branchFields,
      _search,
      const OperationField('category', 'التصنيف', optional: true),
      const OperationField(
        'status',
        'حالة الرصيد',
        optional: true,
        choices: ['', 'AVAILABLE', 'LOW', 'CRITICAL'],
      ),
      _page,
    ], (f) => _api.get(_withQuery(_stock, f))),
    Operation(
      'ملخص رصيد الفرع',
      _branchFields,
      (f) => _api.get(_withQuery('$_stock/summary', f)),
    ),
    Operation('تفاصيل رصيد خامة', [
      ..._branchFields,
      _good,
    ], (f) => _api.get(_stockItem(f))),
    Operation(
      'تعديل إعدادات الرصيد',
      [
        ..._branchFields,
        _good,
        const OperationField(
          'min_stock',
          'حد الأمان',
          kind: InputKind.nonnegative,
          optional: true,
        ),
        const OperationField(
          'reorder_level',
          'حد إعادة الطلب',
          kind: InputKind.nonnegative,
          optional: true,
        ),
        const OperationField(
          'max_stock',
          'السعة القصوى',
          kind: InputKind.nonnegative,
          optional: true,
        ),
        const OperationField('location_code', 'مكان التخزين', optional: true),
      ],
      _updateStockSettings,
      changesData: true,
    ),
    _movement('إضافة للمخزون', 'IN'),
    _movement('صرف من المخزون', 'OUT'),
    _movement('تسوية الرصيد', 'ADJUSTMENT'),
    Operation('سجل حركات المخزون', [
      ..._movementFilters,
      _page,
    ], (f) => _api.get(_withQuery('$_stock/movements', f))),
    Operation(
      'ملخص حركات المخزون',
      _movementFilters,
      (f) => _api.get(_withQuery('$_stock/movements/summary', f)),
    ),
    Operation(
      'قيمة مخزون الفرع',
      _branchFields,
      (f) => _api.get(_withQuery('$_stock/value', f)),
    ),
  ];

  List<OperationField> get _movementFilters => [
    ..._branchFields,
    _search,
    ..._dates,
    const OperationField(
      'good_id',
      'معرّف الخامة',
      kind: InputKind.id,
      optional: true,
    ),
    const OperationField(
      'type',
      'نوع الحركة',
      optional: true,
      choices: ['', 'IN', 'OUT', 'ADJUSTMENT'],
    ),
  ];

  Operation _movement(String title, String type) => Operation(
    title,
    [
      ..._branchFields,
      _good,
      if (type == 'ADJUSTMENT')
        const OperationField(
          'quantity',
          'الرصيد الفعلي بعد التسوية',
          kind: InputKind.nonnegative,
        )
      else
        _quantity,
      if (type == 'IN')
        const OperationField(
          'unit_cost',
          'تكلفة الوحدة',
          kind: InputKind.nonnegative,
          optional: true,
        )
      else
        _reason,
      const OperationField(
        'expected_quantity_before',
        'الرصيد المتوقع قبل الحركة',
        kind: InputKind.nonnegative,
        optional: true,
      ),
    ],
    (f) => _api.post('$_stock/movements', {...f, 'type': type}),
    changesData: true,
  );

  String _stockItem(Fields fields, {String suffix = ''}) => _withQuery(
    '$_stock/items/${_id(fields, 'good_id')}$suffix',
    {if (fields.containsKey('branch_id')) 'branch_id': fields['branch_id']},
  );

  Future<Object?> _updateStockSettings(Fields fields) {
    final body = Map<String, Object?>.of(fields)
      ..remove('branch_id')
      ..remove('good_id');
    if (body.isEmpty) {
      throw const FormatException('أدخل إعدادًا واحدًا على الأقل');
    }
    return _api.patch(_stockItem(fields, suffix: '/settings'), body);
  }

  String _withQuery(String path, Fields fields) {
    if (fields.isEmpty) return path;
    return Uri(
      path: path,
      queryParameters: fields.map(
        (key, value) => MapEntry(
          key,
          key == 'page' ? _positivePage(value).toString() : value.toString(),
        ),
      ),
    ).toString();
  }

  List<OperationField> get _reportBranchFields => [
    if (_ceo)
      const OperationField(
        'branch_id',
        'معرّف الفرع (اختياري)',
        kind: InputKind.id,
        optional: true,
      ),
  ];

  List<Operation> get reports => [
    _report('تقرير المبيعات', 'sales', [..._reportBranchFields, ..._dates]),
    _report('تقرير المخزون', 'inventory', _reportBranchFields),
    _report('تقرير الحضور', 'attendance', [..._reportBranchFields, ..._dates]),
    if (_ceo) ...[
      _report('الطلبات المنتظرة للموافقة', 'approvals', _reportBranchFields),
      _report('سجل التدقيق', 'audit', const [
        OperationField('action', 'العملية', optional: true),
        OperationField('entity_type', 'نوع السجل', optional: true),
      ]),
    ],
  ];

  Operation _report(String title, String route, List<OperationField> fields) =>
      Operation(
        title,
        fields,
        (f) => _api.get(_withQuery('$_reports/$route', f)),
      );

  Future<Object?> _listSupply() async {
    final rows = await _api.get('/api/v1/central-kitchen/supply/requests');
    if (rows is! List) {
      throw const FormatException('استجابة طلبات التوريد غير صالحة');
    }
    return _ceo
        ? rows
        : rows
              .whereType<Map>()
              .where((row) => row['branch_id'] == _session.branchId)
              .toList();
  }

  Future<Object?> _supplyAction(String action, Fields fields) {
    final body = Map<String, Object?>.of(fields)..remove('id');
    return _api.patch(
      '/api/v1/central-kitchen/supply/requests/${_id(fields, 'id')}/$action',
      {...body, 'actor_role': _role},
    );
  }

  List<Operation> get supply => [
    Operation('طلبات التوريد', [], (_) => _listSupply()),
    Operation(
      'طلب توريد جديد',
      [
        ..._branchFields,
        _priority,
        const OperationField('notes', 'ملاحظات', optional: true),
        const OperationField(
          'items',
          'الخامات المطلوبة',
          kind: InputKind.lines,
          columns: [
            _good,
            OperationField(
              'requested_qty',
              'الكمية المطلوبة',
              kind: InputKind.positive,
            ),
          ],
        ),
      ],
      (f) => _api.post('/api/v1/central-kitchen/supply/requests', {
        ...f,
        'branch_id': _branchId(f),
      }),
      changesData: true,
    ),
    if (_ceo) ...[
      Operation(
        'الموافقة على طلب توريد',
        const [
          _request,
          OperationField(
            'items',
            'بنود الموافقة',
            kind: InputKind.lines,
            columns: [
              OperationField('item_id', 'معرّف بند الطلب', kind: InputKind.id),
              OperationField(
                'approved_qty',
                'الكمية المعتمدة',
                kind: InputKind.positive,
              ),
            ],
          ),
        ],
        (f) => _supplyAction('approve', f),
        changesData: true,
      ),
      Operation(
        'رفض طلب توريد',
        [_request, _reason],
        (f) => _supplyAction('reject', f),
        changesData: true,
      ),
      Operation(
        'شحن طلب توريد',
        [_request],
        (f) => _supplyAction('ship', f),
        changesData: true,
      ),
    ],
    Operation(
      'استلام طلب توريد بالكميات الفعلية',
      const [
        _request,
        OperationField(
          'items',
          'كل بنود الشحنة وكمياتها المستلمة',
          kind: InputKind.lines,
          columns: [
            OperationField('item_id', 'معرّف بند الطلب', kind: InputKind.id),
            OperationField(
              'received_qty',
              'الكمية المستلمة',
              kind: InputKind.positive,
            ),
          ],
        ),
      ],
      (f) => _supplyAction('receive', f),
      changesData: true,
    ),
  ];

  Future<Object?> _transferAction(String action, Fields fields) {
    final body = Map<String, Object?>.of(fields)..remove('id');
    return _api.post('/api/v1/transfers/${_id(fields, 'id')}/$action', body);
  }

  List<Operation> get transfers => [
    Operation(
      'التحويلات',
      const [OperationField('page', 'رقم الصفحة', initial: '1')],
      (f) => _api.get('/api/v1/transfers?page=${_positivePage(f['page'])}'),
    ),
    Operation(
      'إحصائيات التحويلات',
      [],
      (_) => _api.get('/api/v1/transfers/stats'),
    ),
    Operation('تفاصيل تحويل', [
      _request,
    ], (f) => _api.get('/api/v1/transfers/${_id(f, 'id')}')),
    Operation(
      'طلب تحويل جديد',
      [
        OperationField(
          'source_branch_id',
          'معرّف الفرع المرسل',
          kind: InputKind.id,
          initial: _manager ? _session.branchId : '',
        ),
        const OperationField(
          'dest_branch_id',
          'معرّف الفرع المستلم',
          kind: InputKind.id,
        ),
        _good,
        _quantity,
        _priority,
        _reason,
      ],
      (f) => _api.post('/api/v1/transfers', f),
      changesData: true,
    ),
    Operation(
      'الموافقة على تحويل',
      const [
        _request,
        OperationField(
          'approved_quantity',
          'الكمية المعتمدة',
          kind: InputKind.positive,
          optional: true,
        ),
        _note,
      ],
      (f) => _transferAction('approve', f),
      changesData: true,
    ),
    Operation(
      'رفض تحويل',
      [_request, _reason],
      (f) => _transferAction('reject', f),
      changesData: true,
    ),
    Operation(
      'إرسال تحويل',
      const [
        _request,
        OperationField('vehicle_type', 'نوع المركبة', optional: true),
        OperationField('driver_name', 'اسم السائق', optional: true),
        OperationField('driver_phone', 'رقم السائق', optional: true),
        OperationField(
          'expected_departure',
          'وقت المغادرة بصيغة ISO 8601',
          optional: true,
        ),
        OperationField(
          'temperature_c',
          'درجة الحرارة',
          kind: InputKind.number,
          optional: true,
        ),
      ],
      (f) {
        if (f['expected_departure'] case final String value) {
          f['expected_departure'] = DateTime.parse(
            value,
          ).toUtc().toIso8601String();
        }
        return _transferAction('send', f);
      },
      changesData: true,
    ),
    Operation(
      'استلام تحويل',
      const [
        _request,
        OperationField(
          'received_quantity',
          'الكمية المستلمة',
          kind: InputKind.nonnegative,
        ),
        _note,
      ],
      (f) => _transferAction('receive', f),
      changesData: true,
    ),
  ];

  int _positivePage(Object? input) {
    final page = int.tryParse(input as String);
    if (page == null || page < 1) {
      throw const FormatException('رقم الصفحة غير صالح');
    }
    return page;
  }
}
