class TransferPreviewOrder {
  const TransferPreviewOrder(
    this.id,
    this.source,
    this.destination,
    this.item,
    this.quantity,
    this.status,
  );

  final String id;
  final String source;
  final String destination;
  final String item;
  final String quantity;
  final String status;
}

const transferPreviewOrders = [
  TransferPreviewOrder(
    'TR-5540',
    'وسط البلد (#01)',
    'المعادي (#03)',
    'صدور دجاج فيليه متبلة',
    '25 كجم',
    'قيد المراجعة',
  ),
  TransferPreviewOrder(
    'TR-5538',
    'الشيخ زايد (#04)',
    'التجمع الخامس (#02)',
    'صوص شيدر مدخن جاهز',
    '15 لتر',
    'طلب وارد',
  ),
  TransferPreviewOrder(
    'TR-5532',
    'التجمع الخامس (#02)',
    'المعادي (#03)',
    'لحم بقري مفروم (خام)',
    '20 كجم',
    'جاهز للاستلام',
  ),
  TransferPreviewOrder(
    'TR-5510',
    'وسط البلد (#01)',
    'الشيخ زايد (#04)',
    'خبز بريوش طازج',
    '80 قطعة',
    'مكتمل',
  ),
];
