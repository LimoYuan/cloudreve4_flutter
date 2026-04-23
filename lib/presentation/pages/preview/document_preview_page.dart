import 'dart:ui';

import 'package:cloudreve4_flutter/core/utils/language_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/all.dart';
import 'package:http/http.dart' as http;
import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';
import '../../../core/utils/file_type_utils.dart';

/// 文档预览页面
class DocumentPreviewPage extends StatefulWidget {
  final FileModel file;

  const DocumentPreviewPage({super.key, required this.file});

  @override
  State<DocumentPreviewPage> createState() => _DocumentPreviewPageState();
}

class _DocumentPreviewPageState extends State<DocumentPreviewPage> {
  CodeController? _codeController;
  String _content = '';
  bool _isLoading = true;
  String? _error;
  Mode _languageMode = allLanguages['plaintext']!;
  String _languageName = 'Text';
  int _lineCount = 0;
  final ScrollController _customCodeScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  @override
  void dispose() {
    _codeController?.dispose();
    _customCodeScrollController.dispose();
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
        _lineCount = _countLines(_content);
        _languageMode = _detectLanguageMode(widget.file.name);
        _languageName = _getLanguageNameFromExtension(widget.file.name);
        _initCodeController();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _initCodeController() {
    _codeController = CodeController(text: _content, language: _languageMode);
  }

  int _countLines(String text) {
    if (text.isEmpty) return 0;
    return '\n'.allMatches(text).length + 1;
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

  Mode _detectLanguageMode(String fileName) {
    final ext = FileTypeUtils.getExtension(fileName);
    // 从所有支持的语言中查找对应的语言模式
    final extLang = LanguagePreview.getExtNameMapping[ext] ?? ext.toUpperCase();
    return allLanguages[extLang.toLowerCase()] ?? allLanguages['plaintext']!;
  }

  String _getLanguageNameFromExtension(String fileName) {
    final ext = FileTypeUtils.getExtension(fileName).toLowerCase();
    return LanguagePreview.getExtNameMapping[ext] ?? ext.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    double lineNumberWidth = _lineCount > 999
        ? 80.0
        : (_lineCount > 99 ? 80.0 : 60.0);

    return Scaffold(
      backgroundColor: const Color(0xFF23241F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF23241F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white),
              tooltip: '复制内容',
              onPressed: _copyContent,
            ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (!_isLoading && _error == null)
              Text(
                '$_languageName · $_lineCount 行',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
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
          : Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF282C34),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse, // 开启鼠标拖拽滚动
                    },
                  ),
                  child: CodeTheme(
                    data: CodeThemeData(styles: {...atomOneDarkTheme}),
                    child: Scrollbar(
                      controller: _customCodeScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _customCodeScrollController,
                        child: CodeField(
                          controller: _codeController!,
                          textStyle: const TextStyle(
                            fontFamily: 'SourceCodePro',
                            fontSize: 15,
                          ),

                          minLines: null,
                          maxLines: null,
                          expands: false,
                          enabled: false,
                          readOnly: true,
                          background: Colors.transparent,
                          cursorColor: Colors.transparent,
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor: Colors.transparent,
                            cursorColor: Colors.transparent,
                          ),
                          lineNumberStyle: LineNumberStyle(
                            width: lineNumberWidth,
                            textAlign: TextAlign.right,
                            margin: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF282C34), // 强制设为你想要的暗色
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
