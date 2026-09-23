import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_strings.dart';
import '../models/scrap_category.dart';
import '../models/region.dart';
import '../services/pricing_service.dart';

/// شاشة طلب تحصيل جديد على أربع خطوات:
/// 1) الفئة والكمية  2) العنوان والموبايل والموقع  3) الميعاد  4) الملاحظات
class RequestFlowScreen extends StatefulWidget {
  final String lang;
  const RequestFlowScreen({super.key, required this.lang});

  @override
  State<RequestFlowScreen> createState() => _RequestFlowScreenState();
}

class _RequestFlowScreenState extends State<RequestFlowScreen> {
  int _step = 0;
  bool _submitted = false;
  bool _loading = false;
  String? _error;

  ScrapCategory? _selectedCategory;
  final _qtyCtrl = TextEditingController();

  RegionOption? _selectedRegion;
  final _phoneCtrl = TextEditingController();
  LatLng _selectedLatLng = const LatLng(30.0444, 31.2357);
  final MapController _mapController = MapController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final _notesCtrl = TextEditingController();

  static final _phoneRe = RegExp(r'^01[0-9]{9}$');

  String t(String key) => AppStrings.t(key, widget.lang);

  @override
  void initState() {
    super.initState();
    // نجيب أحدث الأسعار من Firestore أول ما الشاشة تفتح؛ لو اتحمّلت
    // بعد ما العميل بدأ يكتب الكمية، السعر المعروض بيتحدّث لوحده.
    PricingService.fetchPrices().then((_) {
      if (mounted) setState(() {});
    });
  }

  double? get _estimatedPrice {
    if (_selectedCategory == null) return null;
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) return null;
    return PricingService.estimatedPrice(_selectedCategory!.id, qty);
  }

  String _formatPrice(double value) {
    return value < 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_selectedCategory == null) {
        setState(() => _error = t('err_category'));
        return;
      }
      final qty = double.tryParse(_qtyCtrl.text);
      if (qty == null || qty <= 0) {
        setState(() => _error = t('err_quantity'));
        return;
      }
    } else if (_step == 1) {
      if (_selectedRegion == null) {
        setState(() => _error = t('err_region'));
        return;
      }
      if (!_phoneRe.hasMatch(_phoneCtrl.text.trim())) {
        setState(() => _error = t('err_phone'));
        return;
      }
    } else if (_step == 2) {
      if (_selectedDate == null || _selectedTime == null) {
        setState(() => _error = t('err_datetime'));
        return;
      }
    }
    setState(() => _step++);
  }

  void _back() {
    setState(() {
      _error = null;
      _step--;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('not-authenticated');

      final pickupDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final quantityValue = double.parse(_qtyCtrl.text);
      final estimatedPrice = PricingService.estimatedPrice(_selectedCategory!.id, quantityValue);

      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'categoryId': _selectedCategory!.id,
        'categoryNameAr': _selectedCategory!.nameAr,
        'categoryNameEn': _selectedCategory!.nameEn,
        'unit': _selectedCategory!.unit,
        'quantity': quantityValue,
        'estimatedPrice': estimatedPrice,
        'regionAr': _selectedRegion!.nameAr,
        'regionEn': _selectedRegion!.nameEn,
        'phone': _phoneCtrl.text.trim(),
        'latitude': _selectedLatLng.latitude,
        'longitude': _selectedLatLng.longitude,
        'pickupAt': Timestamp.fromDate(pickupDateTime),
        'notes': _notesCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _submitted = true;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = t('generic_error');
        _loading = false;
      });
    }
  }

  void _resetForNewRequest() {
    setState(() {
      _step = 0;
      _submitted = false;
      _selectedCategory = null;
      _qtyCtrl.clear();
      _selectedRegion = null;
      _phoneCtrl.clear();
      _selectedLatLng = const LatLng(30.0444, 31.2357);
      _selectedDate = null;
      _selectedTime = null;
      _notesCtrl.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('new_request_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _submitted ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProgress(scheme),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
          const SizedBox(height: 12),
        ],
        if (_step == 0) _buildStep1(scheme),
        if (_step == 1) _buildStep2(scheme),
        if (_step == 2) _buildStep3(scheme),
        if (_step == 3) _buildStep4(scheme),
      ],
    );
  }

  Widget _buildProgress(ColorScheme scheme) {
    final labels = [t('step_details'), t('step_address'), t('step_datetime'), t('step_photos')];
    return Row(
      children: List.generate(4, (i) {
        final active = i == _step;
        final done = i < _step;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: done || active ? scheme.primary : scheme.surfaceContainerLow,
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text('${i + 1}',
                        style: TextStyle(fontSize: 12, color: active ? Colors.white : scheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 4),
              Text(labels[i],
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStep1(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('category_heading'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.9,
          children: scrapCategories.map((c) {
            final selected = _selectedCategory?.id == c.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = c),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 0.5),
                  borderRadius: BorderRadius.circular(12),
                  color: selected ? scheme.primaryContainer : Theme.of(context).cardColor,
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(c.imagePath, width: 46, height: 46, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.lang == 'ar' ? c.nameAr : c.nameEn,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: selected ? scheme.onPrimaryContainer : null),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedCategory != null) ...[
          const SizedBox(height: 16),
          Text(
            _selectedCategory!.unit == 'weight' ? t('quantity_label_weight') : t('quantity_label_count'),
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: t('quantity_hint')),
            onChanged: (_) => setState(() {}),
          ),
          if (_estimatedPrice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, size: 18, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${t('estimated_price_label')}: ${_formatPrice(_estimatedPrice!)} ${t('egp_currency')}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(t('price_disclaimer'), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ],
        const SizedBox(height: 20),
        _buildNavRow(showBack: false),
      ],
    );
  }

  Widget _buildStep2(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('region_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        DropdownButtonFormField<RegionOption>(
          value: _selectedRegion,
          hint: Text(t('region_placeholder')),
          items: regionOptions
              .map((r) => DropdownMenuItem(value: r, child: Text(widget.lang == 'ar' ? r.nameAr : r.nameEn)))
              .toList(),
          onChanged: (v) => setState(() => _selectedRegion = v),
        ),
        const SizedBox(height: 14),
        Text(t('phone_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(hintText: t('phone_hint')),
        ),
        const SizedBox(height: 14),
        Text(t('map_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 180,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLatLng,
                initialZoom: 12,
                onTap: (tapPosition, point) => setState(() => _selectedLatLng = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.robabikya.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: _selectedLatLng,
                    width: 36,
                    height: 36,
                    child: Icon(Icons.location_pin, color: scheme.error, size: 36),
                  ),
                ]),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${t('map_selected_prefix')}${_selectedLatLng.latitude.toStringAsFixed(4)}, ${_selectedLatLng.longitude.toStringAsFixed(4)}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _buildNavRow(),
      ],
    );
  }

  Widget _buildStep3(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('date_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: _pickDate,
          child: Text(_selectedDate == null
              ? t('date_placeholder')
              : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'),
        ),
        const SizedBox(height: 14),
        Text(t('time_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: _pickTime,
          child: Text(_selectedTime == null ? t('time_placeholder') : _selectedTime!.format(context)),
        ),
        const SizedBox(height: 20),
        _buildNavRow(),
      ],
    );
  }

  Widget _buildStep4(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('notes_label_optional'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: t('notes_hint')),
        ),
        const SizedBox(height: 20),
        _buildNavRow(isLast: true),
      ],
    );
  }

  Widget _buildNavRow({bool showBack = true, bool isLast = false}) {
    return Row(
      children: [
        if (showBack)
          Expanded(
            child: OutlinedButton(onPressed: _loading ? null : _back, child: Text(t('back_button'))),
          ),
        if (showBack) const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _loading ? null : (isLast ? _submit : _next),
            child: _loading
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isLast ? t('submit_request') : t('next_button')),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final scheme = Theme.of(context).colorScheme;
    final price = _estimatedPrice;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Icon(Icons.check_circle, size: 56, color: scheme.primary),
        const SizedBox(height: 12),
        Text(t('success_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(t('success_body'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        if (price != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${t('estimated_price_label')}: ${_formatPrice(price)} ${t('egp_currency')}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onPrimaryContainer),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: _resetForNewRequest, child: Text(t('new_request_button'))),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(t('back_home_button'))),
      ],
    );
  }
}
