import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_strings.dart';
import '../models/scrap_category.dart';
import '../services/pricing_service.dart';

/// شاشة بسيطة للأدمن يقدر يعدّل بيها سعر كل فئة مباشرة، والتعديل بيتطبّق
/// على كل المستخدمين فورًا من غير أي تحديث للتطبيق (لأن الأسعار متخزنة
/// في Firestore، مش في كود التطبيق).
class AdminPricingScreen extends StatefulWidget {
  final String lang;
  const AdminPricingScreen({super.key, required this.lang});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;
  String? _message;

  String t(String key) => AppStrings.t(key, widget.lang);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prices = await PricingService.fetchPrices(force: true);
    for (final category in scrapCategories) {
      _controllers[category.id] = TextEditingController(text: (prices[category.id] ?? 0).toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final data = <String, dynamic>{};
      for (final category in scrapCategories) {
        final value = double.tryParse(_controllers[category.id]!.text);
        if (value != null) data[category.id] = value;
      }
      data['updatedAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('settings').doc('pricing').set(data, SetOptions(merge: true));
      PricingService.clearCache();
      await PricingService.fetchPrices(force: true);
      if (mounted) setState(() => _message = t('prices_saved'));
    } catch (_) {
      if (mounted) setState(() => _message = t('generic_error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('edit_prices_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(t('edit_prices_hint'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  ...scrapCategories.map((category) {
                    final unitLabel = category.unit == 'weight'
                        ? (widget.lang == 'ar' ? 'ج/كيلو' : 'EGP/kg')
                        : (widget.lang == 'ar' ? 'ج/قطعة' : 'EGP/pc');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(category.imagePath, width: 40, height: 40, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(widget.lang == 'ar' ? category.nameAr : category.nameEn,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: _controllers[category.id],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(suffixText: unitLabel),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_message!, style: TextStyle(color: scheme.primary, fontSize: 13)),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(t('save_prices_button')),
                  ),
                ],
              ),
            ),
    );
  }
}
