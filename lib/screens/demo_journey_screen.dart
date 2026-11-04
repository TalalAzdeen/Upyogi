import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../models/booking_model.dart';
import '../services/demo_service.dart';

/// Every stage is read from the server; opening this screen never advances it.
class DemoJourneyScreen extends StatefulWidget {
  const DemoJourneyScreen({super.key, required this.bookingId});
  final int bookingId;
  @override
  State<DemoJourneyScreen> createState() => _DemoJourneyScreenState();
}

class _DemoJourneyScreenState extends State<DemoJourneyScreen> {
  BookingModel? _booking;
  bool _busy = true;
  String? _error;
  String _method = 'Card';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _busy = true; _error = null; });
    try {
      final booking = await DemoService.load(widget.bookingId);
      if (mounted) setState(() => _booking = booking);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to update the demo. Reload and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance({bool skip = false}) async {
    if (_busy || _booking == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final booking = await DemoService.advance(_booking!, skipPayment: skip);
      if (mounted) setState(() => _booking = booking);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to update the demo. Reload and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final stages = ['Requested', 'Accepted', 'OnTheWay', 'Completed'];
    final index = b == null ? -1 : stages.indexOf(b.bookingStatus);
    final action = {'Requested':'Simulate technician acceptance', 'Accepted':'Simulate travel', 'OnTheWay':'Simulate service completion'}[b?.bookingStatus];
    return Scaffold(
      appBar: AppBar(title: const LText('Sulh demo journey'), actions: [IconButton(
        onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh), tooltip: tr(context, 'Reload'))]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          LText('Demo only', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 8),
          LText('Fictional technician and journey. No visit, location tracking, email or real payment. Progress is saved to your account.'),
        ]))),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          const SizedBox(height: 12), LText(_error!, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: _busy ? null : _load, child: const LText('Reload')),
        ],
        if (b != null) ...[
          const SizedBox(height: 16),
          Text('#${b.id} • ${b.serviceTitle}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8), Text(b.providerName), Text(b.serviceAddress),
          const SizedBox(height: 8),
          LText('SAR ${b.amount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          for (var i = 0; i < stages.length; i++) ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(i <= index ? Icons.check_circle : Icons.radio_button_unchecked,
              color: i <= index ? Colors.green : Colors.grey),
            title: LText(stages[i]),
            subtitle: i == index ? const LText('Current saved stage') : null,
          ),
          if (action != null) FilledButton.icon(onPressed: _busy ? null : () => _advance(),
            icon: const Icon(Icons.play_arrow), label: LText(action)),
          if (index < 0) LText(b.bookingStatus),
          if (b.bookingStatus == 'Completed') ...[
            const Divider(height: 32),
            if (b.demoPaymentSkipped) ...[
              const Icon(Icons.task_alt, size: 64, color: Colors.green),
              const SizedBox(height: 12),
              const LText('Demo completed — payment skipped', textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 8),
              const LText('No money was charged. This is not a payment receipt.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context), child: const LText('Back to app')),
            ] else Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 12),
              const LText('Payment preview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const LText('Total'), LText('SAR ${b.amount.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(initialValue: _method,
                decoration: InputDecoration(labelText: tr(context, 'Payment method (preview)')),
                items: ['Card','Cash'].map((v) => DropdownMenuItem(value: v, child: LText(v))).toList(),
                onChanged: _busy ? null : (v) => setState(() => _method = v!),
              ),
              const SizedBox(height: 12),
              const LText('Payment is simulated. Do not enter card details.'),
              const SizedBox(height: 20),
              FilledButton.icon(key: const Key('skip-demo-payment'),
                onPressed: _busy ? null : () => _advance(skip: true),
                icon: const Icon(Icons.skip_next), label: const LText('Skip payment and finish demo')),
              TextButton(onPressed: () => Navigator.pop(context), child: const LText('Continue later')),
            ]))),
          ],
        ],
      ]),
    );
  }
}
