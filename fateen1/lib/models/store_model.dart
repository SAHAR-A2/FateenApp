/// نموذج متجر بسيط. الهيكل جاهز لإضافة متاجر حقيقية لاحقًا —
/// فقط أضف عناصر [Store] داخل `lib/data/store_data.dart` وسيظهر
/// المتجر تلقائيًا في صفحة "المتاجر" مع قائمة منتجاته الخاصة.
class Store {
  final String id;
  final String name;
  final String logoUrl;
  final List<StoreProduct> products;

  const Store({
    required this.id,
    required this.name,
    this.logoUrl = '',
    this.products = const [],
  });
}

/// عنصر/منتج تابع لمتجر معيّن.
class StoreProduct {
  final String name;
  final String nameEn;
  final String imageUrl;
  final String? barcode;
  final String? details;
  final String? ingredients;
  final String? sourceUrl;

  const StoreProduct({
    required this.name,
    this.nameEn = '',
    this.imageUrl = '',
    this.barcode,
    this.details,
    this.ingredients,
    this.sourceUrl,
  });
}
