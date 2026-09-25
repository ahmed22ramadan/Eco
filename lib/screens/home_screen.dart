import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_strings.dart';
import '../models/scrap_category.dart';
import 'request_flow_screen.dart';
import 'admin_screen.dart';

/// الشاشة الرئيسية: ترحيب، زرار طلب جديد، وقائمة الطلبات السابقة من Firestore.
/// لو المستخدم أدمن (موجود في collection admins بنفس إيميله)، بيظهرله
/// زرار إضافي فوق يوديه للوحة متابعة كل الطلبات.
class HomeScreen extends StatefulWidget {
  final String lang;
  final VoidCallback onToggleLang;

  const HomeScreen({super.key, required this.lang, required this.onToggleLang});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<bool> _isAdminFuture;

  String t(String key) => AppStrings.t(key, widget.lang);

  @override
  void initState() {
    super.initState();
    _isAdminFuture = _checkIsAdmin();
  }

  Future<bool> _checkIsAdmin() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return false;
    try {
      final doc = await FirebaseFirestore.instance.collection('admins').doc(email).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  String _statusLabel(String status) {
    final key = switch (status) {
      'accepted' => 'status_accepted',
      'completed' => 'status_completed',
      _ => 'status_pending',
    };
    return t(key);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eco-Smart'),
        actions: [
          FutureBuilder<bool>(
            future: _isAdminFuture,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.dashboard_customize_outlined),
                tooltip: t('admin_title'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AdminScreen(lang: widget.lang)),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.language), onPressed: widget.onToggleLang),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RequestFlowScreen(lang: widget.lang)),
        ),
        icon: const Icon(Icons.add),
        label: Text(t('new_request_fab')),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '${t('home_welcome')} ${user?.displayName ?? user?.email ?? ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(t('orders_heading'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: user == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('userId', isEqualTo: user.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '${snapshot.error}',
                                style: TextStyle(color: scheme.error, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                t('orders_empty'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final data = docs[i].data() as Map<String, dynamic>;
                            final categoryId = data['categoryId'] as String?;
                            final matches = scrapCategories.where((c) => c.id == categoryId).toList();
                            final category = matches.isNotEmpty ? matches.first : null;
                            final categoryName =
                                widget.lang == 'ar' ? (data['categoryNameAr'] ?? '') : (data['categoryNameEn'] ?? '');
                            final unit = data['unit'] == 'weight'
                                ? (widget.lang == 'ar' ? 'كيلو' : 'kg')
                                : (widget.lang == 'ar' ? 'عدد' : 'pcs');
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: scheme.outlineVariant, width: 0.5),
                              ),
                              child: ListTile(
                                leading: category != null
                                    ? CircleAvatar(backgroundImage: AssetImage(category.imagePath))
                                    : CircleAvatar(
                                        backgroundColor: scheme.primaryContainer,
                                        child: Icon(Icons.recycling, color: scheme.onPrimaryContainer, size: 20),
                                      ),
                                title: Text('$categoryName · ${data['quantity']} $unit'),
                                subtitle: Text(_statusLabel(data['status'] as String? ?? 'pending')),
                                trailing: data['estimatedPrice'] != null
                                    ? Text(
                                        '${(data['estimatedPrice'] as num).toStringAsFixed(0)} ${t('egp_currency')}',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.primary),
                                      )
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
