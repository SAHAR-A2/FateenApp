import '../models/store_model.dart';

/// Retailer showcase seeded only with product data visible on its official page.
final List<Store> stores = [
  const Store(
    id: 'alhatab',
    name: 'أفران الحطب | Al Hatab Foods',
    products: [
      StoreProduct(
        name: 'خبز عربي كيتو 125 جم',
        nameEn: 'Keto Arabic Bread 125 g',
        barcode: '6287001564029',
        imageUrl:
            'https://images.alhatab.com.sa/production/media/catalogue/product/6287001564029/gallery/6287001564029.png?auto=format&dm=1758582481&fit=clip&h=800&q=90&s=1449b7330e49e00be1ce141ed1c34b3c&w=800',
        details:
            'لكل رغيف (32 جم): كربوهيدرات 1.9 جم، سكر 0 جم، صوديوم 91.2 ملجم، بروتين 8.2 جم. يحتوي جلوتين القمح والصويا والترمس؛ غير مناسب لحساسية هذه المكونات أو الداء الزلاقي.',
        ingredients:
            'ماء، جلوتين قمح، دقيق ترمس، بذور يقطين، بذور دوار الشمس، بروتين بازلاء، بذور كتان، ألياف سيليوم، دقيق قمح، بروتين صويا، ألياف تفاح، خميرة، زيت ذرة، ملح.',
        sourceUrl:
            'https://alhatab.com.sa/our-products/bakery/bread/fortified-bread/keto-arabic-bread',
      ),
    ],
  ),
];
