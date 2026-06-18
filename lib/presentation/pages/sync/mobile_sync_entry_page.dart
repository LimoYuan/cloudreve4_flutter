import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mobile_sync_wizard_page.dart';
import 'sync_page_android.dart';

class MobileSyncEntryPage extends StatefulWidget {
  const MobileSyncEntryPage({super.key});

  static const String wizardCompletedKey = 'mobile_sync_wizard_completed_v1';

  @override
  State<MobileSyncEntryPage> createState() => _MobileSyncEntryPageState();
}

class _MobileSyncEntryPageState extends State<MobileSyncEntryPage> {
  bool? _completed;
  bool _openingWizard = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(MobileSyncEntryPage.wizardCompletedKey) ?? false;

    if (!mounted) return;

    setState(() {
      _completed = completed;
    });

    if (!completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openWizard();
        }
      });
    }
  }

  Future<void> _openWizard() async {
    if (_openingWizard) return;

    setState(() {
      _openingWizard = true;
    });

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MobileSyncWizardPage()),
    );

    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(MobileSyncEntryPage.wizardCompletedKey) ?? false;

    if (!mounted) return;

    setState(() {
      _completed = completed || result == true;
      _openingWizard = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completed;

    if (completed == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (completed) {
      return const SyncPageAndroid();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('文件同步')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      '需要先完成手机同步向导',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '首次使用文件同步时，需要先选择同步模式和目录。完成一次后，后续进入文件同步将直接打开同步页面。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _openingWizard ? null : _openWizard,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('开始设置'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
