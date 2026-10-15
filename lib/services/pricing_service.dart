import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/pricing_config.dart';

/// بيجيب الأسعار الحالية من Firestore (settings/pricing) لو موجودة،
/// وبيرجع تلقائيًا للأسعار الافتراضية في pricing_config.dart لو حصل
/// أي خطأ أو المستند لسه مش موجود. النتيجة بتتخزن مؤقتًا (cache) في
/// الذاكرة عشان منكررش القراءة من قاعدة البيانات كل مرة.
class PricingService {
  static Map<String, double>? _cachedPrices;

  static Map<String, double> get _defaults => {
        for (final entry in categoryPricing.entries) entry.key: entry.value.pricePerUnit,
      };

  static Future<Map<String, double>> fetchPrices({bool force = false}) async {
    if (_cachedPrices != null && !force) return _cachedPrices!;
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('pricing').get();
      final defaults = _defaults;
      if (doc.exists) {
        final data = doc.data()!;
        final result = <String, double>{};
        for (final key in defaults.keys) {
          final liveValue = data[key];
          result[key] = liveValue is num ? liveValue.toDouble() : defaults[key]!;
        }
        _cachedPrices = result;
        return result;
      }
      _cachedPrices = defaults;
      return defaults;
    } catch (_) {
      _cachedPrices = _defaults;
      return _cachedPrices!;
    }
  }

  /// بيرجع السعر التقريبي لكمية معيّنة، باستخدام آخر أسعار متاحة
  /// (Firestore لو اتحمّلت، وإلا الأسعار الافتراضية).
  static double? estimatedPrice(String categoryId, double quantity) {
    final prices = _cachedPrices ?? _defaults;
    final price = prices[categoryId];
    if (price == null) return null;
    return quantity * price;
  }

  static void clearCache() {
    _cachedPrices = null;
  }
}
