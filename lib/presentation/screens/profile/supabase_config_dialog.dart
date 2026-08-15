import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class SupabaseConfigDialog extends StatefulWidget {
  const SupabaseConfigDialog({super.key});

  @override
  State<SupabaseConfigDialog> createState() => _SupabaseConfigDialogState();
}

class _SupabaseConfigDialogState extends State<SupabaseConfigDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  bool _isConnecting = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _urlController = TextEditingController(text: auth.supabaseService.currentSupabaseUrl ?? '');
    _keyController = TextEditingController(text: auth.supabaseService.currentAnonKey ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _statusText = "Iltimos, Supabase URL va Anon Keyni kiriting";
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusText = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.connectSupabase(url, key);

    setState(() {
      _isConnecting = false;
      _statusText = success
          ? "Supabase loyihasiga muvaffaqiyatli ulandi! 🚀"
          : "Ulanishda xatolik yuz berdi. Kalitlarni tekshiring.";
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cloud_sync_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Supabase Integratsiyasi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (auth.isSupabaseConnected ? AppTheme.tertiary : AppTheme.warning).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    auth.isSupabaseConnected ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: auth.isSupabaseConnected ? AppTheme.tertiary : AppTheme.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.isSupabaseConnected
                          ? "Supabase faol holatda. Realtime va Storage sinxronlanmoqda."
                          : "Hozircha ilova Demo rejimda ishlamoqda. Realtime serveringizni ulashingiz mumkin.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: auth.isSupabaseConnected ? AppTheme.tertiary : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Project URL',
                hintText: 'https://xyzcompany.supabase.co',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Anon Public Key',
                hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            if (_statusText != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusText!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _statusText!.contains('muvaffaqiyatli') ? AppTheme.tertiary : AppTheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              "Eslatma: Loyiha ildizidagi 'supabase_schema.sql' fayli orqali Supabase SQL Editorida jadvallarni va storageni 1 marta yaratib olishingiz mumkin.",
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (auth.isSupabaseConnected)
          TextButton(
            onPressed: () async {
              await auth.disconnectSupabase();
              setState(() {
                _statusText = "Supabase serveridan uzildi.";
              });
            },
            child: const Text('Uzish', style: TextStyle(color: AppTheme.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Yopish'),
        ),
        ElevatedButton(
          onPressed: _isConnecting ? null : _handleConnect,
          child: _isConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Ulash'),
        ),
      ],
    );
  }
}
