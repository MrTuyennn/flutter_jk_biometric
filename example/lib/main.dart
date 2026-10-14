import 'package:flutter/material.dart';
import 'package:flutter_jk_biometric/flutter_jk_biometric.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_jk_biometric example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const VaultPage(),
    );
  }
}

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  static const _vault = FlutterJkBiometric();
  static const _key = 'demo_secret';

  final _secretController = TextEditingController();
  BiometricAvailability? _availability;
  bool _hasSecret = false;
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final availability = await _vault.checkAvailability();
    final hasSecret = await _vault.hasSecret(key: _key);
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _hasSecret = hasSecret;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } on FlutterJkBiometricException catch (e) {
      setState(() => _status = 'Lỗi: ${e.code} — ${e.message}');
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    await _vault.saveSecret(
      key: _key,
      secret: _secretController.text,
      reason: 'Xác thực để lưu secret',
      negativeButtonText: 'Hủy',
    );
    setState(() => _status = 'Đã lưu secret.');
  });

  Future<void> _read() => _run(() async {
    final secret = await _vault.readSecret(
      key: _key,
      reason: 'Xác thực để đọc secret',
      negativeButtonText: 'Hủy',
    );
    setState(() => _status = 'Secret đọc được: "$secret"');
  });

  Future<void> _delete() => _run(() async {
    await _vault.deleteSecret(key: _key);
    setState(() => _status = 'Đã xóa secret.');
  });

  @override
  Widget build(BuildContext context) {
    final canUseBiometric = _availability == BiometricAvailability.available;

    return Scaffold(
      appBar: AppBar(title: const Text('flutter_jk_biometric')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ListTile(
              leading: Icon(
                canUseBiometric ? Icons.fingerprint : Icons.fingerprint_outlined,
                color: canUseBiometric ? Colors.green : Colors.grey,
              ),
              title: Text('Availability: ${_availability?.name ?? '...'}'),
              subtitle: Text('Secret saved: $_hasSecret'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secretController,
              decoration: const InputDecoration(
                labelText: 'Secret',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Save'),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : _read,
                  child: const Text('Read'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _delete,
                  child: const Text('Delete'),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_status != null) ...[
              const SizedBox(height: 24),
              Text(_status!, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}
