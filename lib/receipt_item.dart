// lib/receipt_item.dart

class ReceiptItem {
  final String item;
  final int qty;

  ReceiptItem({required this.item, this.qty = 1});

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      item: json['item'] as String? ?? 'Producto Desconocido',
      qty: (json['qty'] is int) ? json['qty'] as int : (json['qty'] as num?)?.toInt() ?? 1,
    );
  }
}