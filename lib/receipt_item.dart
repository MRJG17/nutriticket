// lib/receipt_item.dart

class ReceiptItem {
  final String item;
  final double price;
  final int qty;

  ReceiptItem({required this.item, required this.price, this.qty = 1});

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      item: json['item'] as String? ?? 'Producto Desconocido',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      qty: (json['qty'] is int) ? json['qty'] as int : (json['qty'] as num?)?.toInt() ?? 1,
    );
  }
}