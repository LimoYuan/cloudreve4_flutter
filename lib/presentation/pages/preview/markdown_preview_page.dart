import 'package:cloudreve4_flutter/presentation/widgets/code_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:http/http.dart' as http;
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/config/toc.dart';
import 'package:markdown_widget/widget/blocks/leaf/code_block.dart';
import 'package:markdown_widget/widget/blocks/leaf/link.dart';
import 'package:markdown_widget/widget/markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';

/// Markdown 预览页面
class MarkdownPreviewPage extends StatefulWidget {
  final FileModel file;

  const MarkdownPreviewPage({super.key, required this.file});

  @override
  State<MarkdownPreviewPage> createState() => _MarkdownPreviewPageState();
}

class _MarkdownPreviewPageState extends State<MarkdownPreviewPage> {
  String _content = '';
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  final tocController = TocController();
  bool _isDarkMode = false;

  Widget buildTocWidget() => TocWidget(controller: tocController);

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    tocController.dispose();
    super.dispose();
  }

  Future<void> _loadFileContent() async {
    try {
      final response = await FileService().getDownloadUrls(
        uris: [widget.file.relativePath],
        download: true,
      );

      final urls = response['urls'] as List<dynamic>? ?? [];
      if (urls.isEmpty) {
        throw Exception('获取URL为空');
      }

      final urlData = urls[0] as Map<String, dynamic>;
      final url = urlData['url'] as String;

      if (url.isEmpty) {
        throw Exception('获取URL下载地址为空');
      }

      final responseContent = await http.get(Uri.parse(url));
      if (responseContent.statusCode != 200) {
        throw Exception('下载文件失败: ${responseContent.statusCode}');
      }

      setState(() {
        _content = responseContent.body;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _copyContent() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制到剪贴板'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              icon: Icon(Icons.copy, color: isDark ? Colors.white : Colors.black87),
              tooltip: '复制内容',
              onPressed: _copyContent,
            ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.name,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (!_isLoading && _error == null)
              Text(
                'Markdown',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadFileContent,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : Scaffold(
              body: Row(
                children: <Widget>[
                  Expanded(child: buildTocWidget()),
                  Expanded(
                    flex: 3,
                    child: _buildMarkdownWidget(
                      _content,
                      tocController,
                      isDark,
                    ),
                  ),
                ],
              ),
            ),
          floatingActionButton: !_isLoading && _error == null
          ? FloatingActionButton(
              heroTag: 'theme_toggle',
              mini: true,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              onPressed: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              },
              child: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: isDark ? Colors.white : Colors.black87,
              ),
            )
          : null,
    );
  }
}

MarkdownWidget _buildMarkdownWidget(
  String content,
  TocController tocController,
  bool isDark,
) {
  final config = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
  CodeWrapperWidget codeWrapper(child, text, language) =>
        CodeWrapperWidget(child, text, language);

  return MarkdownWidget(
    data: content,
    tocController: tocController,
    config: config.copy(configs: [
      isDark ? PreConfig(
        theme: atomOneDarkTheme,
        wrapper: codeWrapper,
      ) : PreConfig(
        theme: a11yLightTheme,
        wrapper: codeWrapper,
      ),
      LinkConfig(
        style: TextStyle(
          color: isDark ? Colors.lightBlue : Colors.red,
          decoration: TextDecoration.underline,
        ),
        onTap: (url) {
          launchUrl(Uri.parse(url));
        },
      ),
    ]),
    selectable: true,
  );
}
