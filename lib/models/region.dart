class RegionOption {
  final String nameAr;
  final String nameEn;
  const RegionOption({required this.nameAr, required this.nameEn});
}

const List<RegionOption> regionOptions = [
  RegionOption(nameAr: 'القاهرة الجديدة', nameEn: 'New Cairo'),
  RegionOption(nameAr: 'مدينة نصر', nameEn: 'Nasr City'),
  RegionOption(nameAr: 'المعادي', nameEn: 'Maadi'),
  RegionOption(nameAr: 'الجيزة', nameEn: 'Giza'),
  RegionOption(nameAr: 'الدقي', nameEn: 'Dokki'),
  RegionOption(nameAr: 'حلوان', nameEn: 'Helwan'),
  RegionOption(nameAr: 'الإسكندرية', nameEn: 'Alexandria'),
  RegionOption(nameAr: 'أخرى', nameEn: 'Other'),
];
