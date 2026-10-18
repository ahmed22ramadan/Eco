import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_strings.dart';

class AdminRepsScreen extends StatefulWidget {
  final String lang;
  const AdminRepsScreen({super.key, required this.lang});

  @override
  State<AdminRepsScreen> createState() => _AdminRepsScreenState();
}

class _AdminRepsScreenState extends State<AdminRepsScreen> {
  final _emailCtrl = TextEditingController();
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  String? _error;

  String t(String key) => AppStrings.t(key, widget.lang);

  CollectionReference get _reps => FirebaseFirestore.instance.collection('reps');

  Future<void> _add() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = t('err_email'));
      return;
    }
    try {
      await _reps.doc(email).set({'email': email, 'createdAt': FieldValue.serverTimestamp()});
      _emailCtrl.clear();
      setState(() => _error = null);
    } catch (_) {
      setState(() => _error = t('generic_error'));
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('reps_title'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: t('rep_email_hint')),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              FilledButton(onPressed: _add, child: Text(t('add_rep_button'))),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _reps.snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(t('reps_empty'), style: TextStyle(color: scheme.onSurfaceVariant)),
                      );
                    }
                    return ListView(
                      children: docs
                          .map((d) => ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(d.id),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => d.reference.delete(),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
