import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/scrap_category.dart';
import 'admin_pricing_screen.dart';

/// لوحة إدارة بسيطة: تعرض كل الطلبات الواردة من كل العملاء (مش بس طلبات
/// المستخدم الحالي)، وتسمح بتغيير حالة كل طلب، والاتصال بالعميل، وفتح
/// موقعه على الخريطة. الوصول للشاشة دي محكوم بقاعدة أمان في Firestore
/// (collection admins) — راجع README لإزاي تضيف نفسك كأدمن.
class AdminScreen extends StatelessWidget {
  final String lang;
  const AdminScreen({super.key, required this.lang});

  String t(String key) => AppStrings.t(key, lang);

  Future<void> _updateStatus(String orderId, String status) {
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': status});
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openLocation(double lat, double lng) async {
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return;
    }
    final webUri = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  String _statusLabel(String status) {
    final key = switch (status) {
      'accepted' => 'status_accepted',
      'completed' => 'status_completed',
      _ => 'status_pending',
    };
    return t(key);
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'accepted':
        return Colors.orange;
      case 'completed':
        return scheme.primary;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('admin_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.price_change_outlined),
            tooltip: t('edit_prices_title'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AdminPricingScreen(lang: lang)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}',
                    style: TextStyle(color: scheme.error, fontSize: 12), textAlign: TextAlign.center),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text(t('orders_empty'), style: TextStyle(color: scheme.onSurfaceVariant)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final categoryId = data['categoryId'] as String?;
              final matches = scrapCategories.where((c) => c.id == categoryId).toList();
              final category = matches.isNotEmpty ? matches.first : null;
              final categoryName = lang == 'ar' ? (data['categoryNameAr'] ?? '') : (data['categoryNameEn'] ?? '');
              final regionName = lang == 'ar' ? (data['regionAr'] ?? '') : (data['regionEn'] ?? '');
              final unit = data['unit'] == 'weight' ? (lang == 'ar' ? 'كيلو' : 'kg') : (lang == 'ar' ? 'عدد' : 'pcs');
              final status = data['status'] as String? ?? 'pending';
              final phone = data['phone'] as String? ?? '';
              final lat = (data['latitude'] as num?)?.toDouble();
              final lng = (data['longitude'] as num?)?.toDouble();
              final notes = data['notes'] as String? ?? '';
              final pickupAt = (data['pickupAt'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: scheme.outlineVariant, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundImage: category != null ? AssetImage(category.imagePath) : null,
                            backgroundColor: scheme.primaryContainer,
                            child: category == null
                                ? Icon(Icons.recycling, color: scheme.onPrimaryContainer, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$categoryName · ${data['quantity']} $unit',
                                    style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(regionName, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                if (data['estimatedPrice'] != null)
                                  Text(
                                    '${t('estimated_price_label')}: ${(data['estimatedPrice'] as num).toStringAsFixed(0)} ${t('egp_currency')}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.primary),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(status, scheme).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_statusLabel(status),
                                style: TextStyle(fontSize: 11, color: _statusColor(status, scheme))),
                          ),
                        ],
                      ),
                      if (pickupAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${pickupAt.year}-${pickupAt.month.toString().padLeft(2, '0')}-${pickupAt.day.toString().padLeft(2, '0')} · '
                          '${pickupAt.hour.toString().padLeft(2, '0')}:${pickupAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(notes, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (phone.isNotEmpty)
                            IconButton(
                              onPressed: () => _callCustomer(phone),
                              icon: const Icon(Icons.call_outlined),
                              tooltip: phone,
                            ),
                          if (lat != null && lng != null)
                            IconButton(
                              onPressed: () => _openLocation(lat, lng),
                              icon: const Icon(Icons.location_on_outlined),
                            ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            onSelected: (value) => _updateStatus(doc.id, value),
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'pending', child: Text(t('status_pending'))),
                              PopupMenuItem(value: 'accepted', child: Text(t('status_accepted'))),
                              PopupMenuItem(value: 'completed', child: Text(t('status_completed'))),
                            ],
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(t('change_status'), style: TextStyle(fontSize: 13, color: scheme.primary)),
                                Icon(Icons.arrow_drop_down, color: scheme.primary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
