import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amount = TextEditingController();
  Map<String, dynamic>? _wallet;
  String? _error;
  bool _loading = true;
  bool _paying = false;
  String? _pendingRequest;
  int? _pendingAmount;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _amount.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final data = await WalletService.load();
      if (mounted) setState(() { _wallet = data; _loading = false; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحديث الرصيد. تحقق من الاتصال وحاول مجددًا.'; });
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _topup() async {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || !value.isFinite || value < 10 || value > 10000 || (value * 100 - (value * 100).round()).abs() > 0.0001) {
      _message('أدخل مبلغًا بين 10 و10,000 ريال، بمنزلتين عشريتين كحد أقصى.'); return;
    }
    final amountMinor = (value * 100).round();
    if (_pendingAmount != amountMinor) { _pendingRequest = null; _pendingAmount = amountMinor; }
    _pendingRequest ??= WalletService.requestId();
    setState(() => _paying = true);
    try {
      final payment = await WalletService.topup(amountMinor, _pendingRequest!);
      final key = payment['publishableKey'];
      if (key is! String || !(key.startsWith('pk_test_') || key.startsWith('pk_live_'))) {
        throw Exception('لم يكتمل إعداد بوابة الدفع.');
      }
      Stripe.publishableKey = key;
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: payment['clientSecret'], merchantDisplayName: 'Upyogi',
      ));
      if (!mounted) return;
      await Stripe.instance.presentPaymentSheet();
      _pendingRequest = null;
      // The sheet alone never credits the balance. Wait for the signed server webhook.
      for (var attempt = 0; attempt < 5 && mounted; attempt++) {
        await _load();
        final entries = (_wallet?['topups'] as List?) ?? [];
        if (entries.any((e) => e['status'] == 'succeeded' && e['stripe_payment_intent_id'] == payment['paymentIntentId'])) {
          _message('تم تأكيد الشحن وإضافة الرصيد.'); _amount.clear(); return;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      _message('طلب الدفع أُرسل. سيظهر الرصيد بعد تأكيد بوابة الدفع؛ حدّث الصفحة.');
    } on StripeException catch (e) {
      _message(e.error.code == FailureCode.Canceled ? 'أُلغيت عملية الدفع.' : 'تعذر إتمام الدفع. تحقق من حالة العملية قبل المحاولة مجددًا.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = (_wallet?['topups'] as List?) ?? [];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('محفظتي'), actions: [IconButton(onPressed: _paying ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث الرصيد')]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
          if (_wallet != null) ...[
            const Text('الرصيد المتاح', style: TextStyle(fontSize: 18)),
            Text('${((_wallet!['balanceMinor'] as num) / 100).toStringAsFixed(2)} ر.س', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (_wallet!['paymentsConfigured'] != true) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('الشحن غير مفعّل بعد. يلزم إكمال إعداد بوابة الدفع قبل قبول الأموال.'))),
            TextField(controller: _amount, enabled: !_paying, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'مبلغ الشحن بالريال السعودي', hintText: '10.00', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _paying || _error != null || _wallet!['paymentsConfigured'] != true ? null : _topup,
              icon: _paying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_card), label: Text(_paying ? 'جارٍ معالجة الدفع…' : 'شحن الرصيد')),
            const SizedBox(height: 24), const Text('عمليات الشحن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (entries.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('لا توجد عمليات شحن حتى الآن.')),
            for (final e in entries) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text('${((e['amount_minor'] as num) / 100).toStringAsFixed(2)} ر.س'),
              subtitle: Text(e['created_at'].toString().split('T').first),
              trailing: Text(({'pending':'بانتظار التأكيد','succeeded':'مكتملة','cancelled':'ملغاة','failed':'فشلت'})[e['status']] ?? 'قيد المعالجة')),
          ],
        ]),
      ),
    ));
  }
}
