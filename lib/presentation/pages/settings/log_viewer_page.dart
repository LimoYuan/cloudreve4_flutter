import 'package:flutter/material.dart';
import '../../../core/utils/app_logger.dart';
import '../../widgets/toast_helper.dart';

/// 日志预览页面
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  String _logContent = '';
  bool _isLoading = true;
  final bool _isAutoScroll = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLog() async {
    setState(() => _isLoading = true);
    try {
      final content = await AppLogger.readLog(maxLines: 1000);
      if (mounted) {
        setState(() {
          _logContent = content;
          _isLoading = false;
        });
        if (_isAutoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                  _scrollController.position.maxScrollExtent);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.error('读取日志失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日志预览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLog,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logContent.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 48, color: theme.hintColor.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('暂无日志', style: TextStyle(color: theme.hintColor)),
                    ],
                  ),
                )
              : Container(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _logContent,
                        style: TextStyle(
                          fontFamily: 'SourceCodePro',
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? Colors.grey[300] : Colors.grey[900],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
