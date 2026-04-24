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
  final _tocController = TocController();
  bool _isDarkMode = false;
  
  // 控制目录是否显示
  bool _isTocVisible = false;
  // 标记是否已经根据屏幕宽度进行了初始化
  bool _hasInitializedLayout = false;

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tocController.dispose();
    super.dispose();
  }

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 1000;

    // 首次加载时，根据屏幕宽度决定目录默认状态
    if (!_hasInitializedLayout && !_isLoading) {
      _isTocVisible = isWideScreen;
      _hasInitializedLayout = true;
    }

    final isDark = _isDarkMode;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
              Text('Markdown 预览', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              icon: Icon(Icons.copy, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Clipboard.setData(ClipboardData(text: _content)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildResponsiveBody(isWideScreen, screenWidth),
      floatingActionButton: _buildFAB(isDark),
    );
  }

  // 构建响应式主体
  Widget _buildResponsiveBody(bool isWideScreen, double screenWidth) {
    final double tocWidth = isWideScreen ? 300 : screenWidth * 0.7;
    
    // 预定义暗色/亮色下的文字颜色
    final Color textColor = _isDarkMode ? Colors.white : Colors.black87;
    final Color subTextColor = _isDarkMode ? Colors.white70 : Colors.black54;

    return Row(
      children: [
        // 1. 侧边目录区
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: _isTocVisible ? tocWidth : 0,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: _isDarkMode ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)
                ),
              ),
              color: _isDarkMode ? const Color(0xFF252525) : Colors.grey.shade50,
            ),
            child: ClipRect(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      "目录",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor, // 适配标题颜色
                      ),
                    ),
                  ),
                  Divider(height: 1, color: _isDarkMode ? Colors.white10 : Colors.grey.shade300),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!isWideScreen) {
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (mounted) setState(() => _isTocVisible = false);
                          });
                        }
                      },
                      behavior: HitTestBehavior.translucent,
                      // 使用 Theme 局部包裹，强制改变 TOC 内部的 TextTheme
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          textTheme: TextTheme(
                            // 某些版本的 markdown_widget 会引用 bodyMedium 或 bodySmall
                            bodyMedium: TextStyle(color: subTextColor),
                            bodySmall: TextStyle(color: subTextColor),
                          ),
                        ),
                        child: TocWidget(
                          controller: _tocController,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 2. 正文内容区
        Expanded(
          child: Container(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: SafeArea(
              left: false,
              right: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0), // 增加一点边距
                child: _buildMarkdownWidget(_content),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkdownWidget(String content) {
    final config = _isDarkMode ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
    CodeWrapperWidget codeWrapper(child, text, language) => CodeWrapperWidget(child, text, language);

    return MarkdownWidget(
      data: content,
      tocController: _tocController,
      config: config.copy(
        configs: [
          _isDarkMode
              ? PreConfig.darkConfig.copy(theme: a11yLightTheme, wrapper: codeWrapper)
              : PreConfig(theme: atomOneDarkTheme).copy(wrapper: codeWrapper),
          LinkConfig(
            style: TextStyle(
              color: _isDarkMode ? Colors.lightBlue : Colors.blue,
              decoration: TextDecoration.underline,
            ),
            onTap: (url) => launchUrl(Uri.parse(url)),
          ),
        ],
      ),
      selectable: true,
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!),
          ElevatedButton(onPressed: _loadFileContent, child: const Text('重试')),
        ],
      ),
    );
  }

Widget _buildFAB(bool isDark) {
    if (_isLoading || _error != null) return const SizedBox.shrink();
    
    // 定义统一的按钮背景颜色，增加视觉一致性
    final Color activeColor = isDark ? Colors.blue.shade700 : Colors.blue;
    final Color inactiveColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final Color iconColor = isDark ? Colors.white : Colors.black87;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 1. 暗色模式切换按钮
        FloatingActionButton(
          heroTag: 'theme_toggle',
          mini: true, // 保持 mini
          backgroundColor: inactiveColor,
          elevation: 2, // 稍微降低阴影，看起来更精致
          onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          child: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode, 
            color: iconColor,
            size: 20, // 微调图标大小
          ),
        ),
        const SizedBox(height: 12),
        // 2. 目录切换按钮
        FloatingActionButton(
          heroTag: 'toc_toggle',
          mini: true, // 这里修改为 true，使其与上面的按钮大小一致
          // 如果目录开启，使用蓝色背景，否则使用普通背景
          backgroundColor: _isTocVisible ? activeColor : inactiveColor,
          elevation: 2,
          onPressed: () => setState(() => _isTocVisible = !_isTocVisible),
          child: Icon(
            Icons.format_list_bulleted, 
            color: _isTocVisible ? Colors.white : iconColor,
            size: 20,
          ),
        ),
      ],
    );
  }
}