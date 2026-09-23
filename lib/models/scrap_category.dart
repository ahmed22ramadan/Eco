import 'package:flutter/material.dart';

/// فئة من فئات المخلفات القابلة لإعادة التدوير.
/// unit: 'weight' (بالكيلو) أو 'count' (بالعدد).
/// imagePath: صورة حقيقية للفئة (assets)، وicon بيستخدم كاحتياطي فقط
/// في الأماكن اللي محتاجة أيقونة صغيرة (زي شريط تسجيل الدخول).
class ScrapCategory {
  final String id;
  final String nameAr;
  final String nameEn;
  final String unit;
  final IconData icon;
  final String imagePath;

  const ScrapCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.unit,
    required this.icon,
    required this.imagePath,
  });
}

const List<ScrapCategory> scrapCategories = [
  ScrapCategory(
    id: 'cans',
    nameAr: 'عبوات الكانز',
    nameEn: 'Drink cans',
    unit: 'weight',
    icon: Icons.local_drink,
    imagePath: 'assets/images/cans.jpg',
  ),
  ScrapCategory(
    id: 'aluminum_scrap',
    nameAr: 'ألومنيوم اسكراب',
    nameEn: 'Aluminum scrap',
    unit: 'weight',
    icon: Icons.recycling,
    imagePath: 'assets/images/aluminum_scrap.jpg',
  ),
  ScrapCategory(
    id: 'aluminum_dry',
    nameAr: 'ألومنيوم ناشف',
    nameEn: 'Dry aluminum',
    unit: 'weight',
    icon: Icons.recycling,
    imagePath: 'assets/images/aluminum_dry.jpg',
  ),
  ScrapCategory(
    id: 'foil',
    nameAr: 'ورق فويل',
    nameEn: 'Foil paper',
    unit: 'weight',
    icon: Icons.layers,
    imagePath: 'assets/images/foil.jpg',
  ),
  ScrapCategory(
    id: 'aluminum_trays',
    nameAr: 'أطباق ألومنيوم',
    nameEn: 'Aluminum trays',
    unit: 'count',
    icon: Icons.album,
    imagePath: 'assets/images/aluminum_trays.jpg',
  ),
  ScrapCategory(
    id: 'plastic',
    nameAr: 'بلاستيك',
    nameEn: 'Plastic',
    unit: 'weight',
    icon: Icons.shopping_bag,
    imagePath: 'assets/images/plastic.jpg',
  ),
  ScrapCategory(
    id: 'tires',
    nameAr: 'كاوتش العربية',
    nameEn: 'Car tires',
    unit: 'count',
    icon: Icons.directions_car,
    imagePath: 'assets/images/tires.jpg',
  ),
  ScrapCategory(
    id: 'iron_scrap',
    nameAr: 'خردة حديد',
    nameEn: 'Iron scrap',
    unit: 'weight',
    icon: Icons.build,
    imagePath: 'assets/images/iron_scrap.jpg',
  ),
];
