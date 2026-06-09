import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';

class PdfPreviewPage extends StatefulWidget {
  final FileModel file;
  final String? entityId;

  const PdfPreviewPage({super.key, required this.file, this.entityId});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  bool _loading = true;
  String? _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final response = await FileService().getDownloadUrls(
        uris: [widget.file.relativePath],
        download: false,
        entity: widget.entityId,
      );

      final urls = response['urls'] as List<dynamic>? ?? [];
      if (urls.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Unable to get PDF URL';
        });
        return;
      }

      final first = urls.first as Map<String, dynamic>;
      final url = first['url']?.toString();

      if (!mounted) return;
      setState(() {
        _url = url;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openExternal() async {
    final url = _url;
    if (url == null || url.isEmpty) return;

    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open PDF')));
    }
  }

  Future<void> _copyUrl() async {
    final url = _url;
    if (url == null || url.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: url));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PDF URL copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: [
          if (_url != null)
            IconButton(
              tooltip: 'Copy URL',
              onPressed: _copyUrl,
              icon: const Icon(Icons.copy),
            ),
          if (_url != null)
            IconButton(
              tooltip: 'Open externally',
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 72),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadUrl();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 80),
            const SizedBox(height: 20),
            Text(
              widget.file.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'PDF inline preview is temporarily disabled on Android. Open it with an external app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open externally'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _copyUrl,
              icon: const Icon(Icons.copy),
              label: const Text('Copy URL'),
            ),
          ],
        ),
      ),
    );
  }
}
