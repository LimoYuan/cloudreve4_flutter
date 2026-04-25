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

  // 状态管理
  bool _showLineNumbers = true;
  double _fontSize = 14.0; // 默认字体大小
  bool _hasInitializedLayout = false;

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

  // 加载逻辑保持不变...
  Future<void> _loadFileContent() async {
    try {
      final response = await FileService().getDownloadUrls(
        uris: [widget.file.relativePath],
        download: true,
      );
      final urls = response['urls'] as List<dynamic>? ?? [];
      if (urls.isEmpty) throw Exception('获取URL为空');
      final urlData = urls[0] as Map<String, dynamic>;
      final url = urlData['url'] as String;

      final responseContent = await http.get(Uri.parse(url));
      if (responseContent.statusCode != 200) {
        throw Exception('下载文件失败: ${responseContent.statusCode}');
      }

      if (mounted) {
        setState(() {
          _content = responseContent.body;
          _lineCount = _countLines(_content);
          _languageMode = _detectLanguageMode(widget.file.name);
          _languageName = _getLanguageNameFromExtension(widget.file.name);
          _initCodeController();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          throw Exception('获取文件内容失败: $_error');
        });
      }
    }
  }

  void _initCodeController() {
    _codeController = CodeController(text: _content, language: _languageMode);
  }

  int _countLines(String text) => text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;

  Mode _detectLanguageMode(String fileName) {
    final ext = FileTypeUtils.getExtension(fileName);
    final extLang = LanguagePreview.getExtNameMapping[ext] ?? ext.toUpperCase();
    return allLanguages[extLang.toLowerCase()] ?? allLanguages['plaintext']!;
  }

  String _getLanguageNameFromExtension(String fileName) {
    final ext = FileTypeUtils.getExtension(fileName).toLowerCase();
    return LanguagePreview.getExtNameMapping[ext] ?? ext.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // 自动初始化布局逻辑
    if (!_hasInitializedLayout && !_isLoading) {
      _showLineNumbers = screenWidth >= 600;
      _hasInitializedLayout = true;
    }

    // --- 动态行号宽度计算 (核心修复) ---
    double lineNumberWidth = 0;
    if (_showLineNumbers) {
      // 计算行数的位数，并根据当前字体大小分配宽度
      int digits = _lineCount.toString().length;
      // 这里的 0.7 是字体宽高的约数比例，20 是左右边距预留
      lineNumberWidth = (digits * (_fontSize * 0.7)) + 15; 
      if (lineNumberWidth < 35) lineNumberWidth = 35;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.file.name, style: const TextStyle(color: Colors.white, fontSize: 15)),
            if (!_isLoading) 
              Text('$_languageName · $_lineCount 行 · 字号: ${_fontSize.toInt()}', 
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white),
            onPressed: () => Clipboard.setData(ClipboardData(text: _content)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _buildCodeEditor(lineNumberWidth),
      floatingActionButton: _buildExpandableFab(),
    );
  }

  /// 现在是一次性渲染的, 所以代码行数太多会有性能问题, 渲染会耗时较长, 而且会卡顿
  Widget _buildCodeEditor(double lineNumberWidth) {
      // 核心改进：根据当前字号，动态计算一个更宽松的行号宽度
      // 13号字大概每个数字占 8-9 像素，我们按 10 像素算并加上边距
      int digits = _lineCount.toString().length;
      // 这里的 12.0 是根据 13-15号字体的平均宽度预留，45 是基础间距 (调试火葬场)
      double stableWidth = _showLineNumbers 
          ? (digits * (_fontSize * 0.75)) + 45 
          : 0;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF282C34),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
          ),
          child: CodeTheme(
            data: CodeThemeData(styles: {...atomOneDarkTheme}),
            child: Scrollbar(
              controller: _customCodeScrollController,
              child: SingleChildScrollView(
                controller: _customCodeScrollController,
                child: CodeField(
                  controller: _codeController!,
                  textStyle: TextStyle(
                    fontFamily: 'SourceCodePro',
                    fontSize: _fontSize,
                    height: 1.5,
                  ),
                  enabled: false,
                  readOnly: true,
                  background: Colors.transparent,
                  // 关键点 1：调整行号样式
                  lineNumberStyle: LineNumberStyle(
                    width: stableWidth,
                    textAlign: TextAlign.right, // 回归右对齐，更符合代码习惯
                    margin: _showLineNumbers ? 12 : 0, // 增加间距防止数字贴边触发换行
                    textStyle: TextStyle(
                      color: _showLineNumbers ? Colors.grey.shade600 : Colors.transparent,
                      fontSize: _fontSize * 0.8,
                      height: 1.5, // 必须和正文高度完全一致
                      // 核心修复：通过强制单词不换行来防止数字断裂
                      fontFeatures: const [FontFeature.tabularFigures()], // 使用等宽数字
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

  // 构建功能组合按钮
  Widget _buildExpandableFab() {
    if (_isLoading) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 增加字号
        FloatingActionButton(
          heroTag: 'font_up',
          mini: true,
          backgroundColor: Colors.grey.shade800,
          onPressed: () => setState(() { if(_fontSize < 30) _fontSize++; }),
          child: const Icon(Icons.add, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        // 减小字号
        FloatingActionButton(
          heroTag: 'font_down',
          mini: true,
          backgroundColor: Colors.grey.shade800,
          onPressed: () => setState(() { if(_fontSize > 8) _fontSize--; }),
          child: const Icon(Icons.remove, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        // 行号开关
        FloatingActionButton(
          heroTag: 'line_toggle',
          mini: true,
          backgroundColor: _showLineNumbers ? Colors.blue : Colors.grey.shade800,
          onPressed: () => setState(() => _showLineNumbers = !_showLineNumbers),
          child: Icon(
            _showLineNumbers ? Icons.format_list_numbered : Icons.short_text,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }
}