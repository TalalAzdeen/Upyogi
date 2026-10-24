import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../services/wallet_service.dart';

/// Historical account view only. Payments are made outside Sulh after completion.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _wallet;
  String? _error;
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final data = await WalletService.load();
      if (mounted) setState(() { _wallet = data; _loading = false; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحديث الرصيد. تحقق من الاتصال وحاول مجددًا.'; });
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LText('محفظتي'), actions: [IconButton(onPressed: _load,
      icon: const Icon(Icons.refresh), tooltip: tr(context, 'تحديث الرصيد'))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: _load, child: ListView(padding: const EdgeInsets.all(24), children: [
        if (_error != null) ...[LText(_error!, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: _load, child: const LText('إعادة المحاولة'))],
        if (_wallet != null) ...[
          const LText('الرصيد المتاح', style: TextStyle(fontSize: 18)),
          LText('SAR ${((_wallet!['balanceMinor'] as num) / 100).toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: LText('Pay the technician directly after the work is completed. No payment is collected in the app.'))),
          for (final entry in (_wallet?['topups'] as List? ?? [])) ListTile(
            leading: const Icon(Icons.history), title: LText('SAR ${((entry['amount_minor'] as num) / 100).toStringAsFixed(2)}'),
            subtitle: Text(entry['created_at'].toString().split('T').first)),
        ],
      ])),
  );
}
