import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';

/// PDF预览页面
class PdfPreviewPage extends StatefulWidget {
  final FileModel file;

  const PdfPreviewPage({super.key, required this.file});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  String? _pdfUrl;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdfUrl();
  }

  Future<void> _loadPdfUrl() async {
    try {
      final response = await FileService().getDownloadUrls(
        uris: [widget.file.relativePath],
        download: false,
      );

      final urls = response['urls'] as List<dynamic>? ?? [];
      if (urls.isNotEmpty) {
        final urlData = urls[0] as Map<String, dynamic>;
        final url = urlData['url'] as String;

        if (mounted) {
          setState(() {
            _pdfUrl = url;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = '无法获取PDF URL';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.file.name)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadPdfUrl();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_pdfUrl == null) {
      return const Center(child: Text('无法加载PDF'));
    }

    return Container(
      color: Colors.grey.shade200,
      child: PdfViewer.uri(
        Uri.parse(_pdfUrl!),
        params: const PdfViewerParams(
          activeMatchTextColor: Colors.yellow,
          annotationRenderingMode: PdfAnnotationRenderingMode.annotationAndForms,
          maxScale: 4.0,
          minScale: 0.8, // Allow 300% zoom
          scaleEnabled: true,
          textSelectionParams: PdfTextSelectionParams(
            enabled: true,
            showContextMenuAutomatically: true,
          ),
        ),
      ),
    );
  }
}
