import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:re_highlight/styles/monokai-sublime.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/text_decode_utils.dart';
import '../../../data/models/file_model.dart';
import '../../../data/models/upload_task_model.dart';
import '../../../services/file_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/upload_service.dart';
import '../../providers/upload_manager_provider.dart';
import '../../widgets/toast_helper.dart';

/// 文本编辑器页面，基于 re_editor。
class DocumentEditorPage extends StatefulWidget {
  final FileModel file;
  final String? initialContent;

  const DocumentEditorPage({
    super.key,
    required this.file,
    this.initialContent,
  });

  @override
  State<DocumentEditorPage> createState() => _DocumentEditorPageState();
}

/// 编辑器主题配置项。
class _EditorThemeChoice {
  final String key;
  final String label;
  final Map<String, TextStyle> theme;
  final bool dark;

  const _EditorThemeChoice({
    required this.key,
    required this.label,
    required this.theme,
    required this.dark,
  });
}

/// 文件扩展名 -> re_highlight 语言 id 的小映射表。
///
/// 命中 builtinAllLanguages 时启用语法高亮，否则按纯文本处理。
const Map<String, String> _kExtensionToLanguage = {
  'dart': 'dart',
  'js': 'javascript',
  'mjs': 'javascript',
  'cjs': 'javascript',
  'jsx': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'json': 'json',
  'json5': 'json',
  'yaml': 'yaml',
  'yml': 'yaml',
  'xml': 'xml',
  'html': 'xml',
  'htm': 'xml',
  'svg': 'xml',
  'css': 'css',
  'scss': 'scss',
  'less': 'less',
  'md': 'markdown',
  'markdown': 'markdown',
  'py': 'python',
  'rs': 'rust',
  'go': 'go',
  'java': 'java',
  'kt': 'kotlin',
  'kts': 'kotlin',
  'swift': 'swift',
  'c': 'c',
  'h': 'c',
  'cpp': 'cpp',
  'cc': 'cpp',
  'cxx': 'cpp',
  'hpp': 'cpp',
  'hxx': 'cpp',
  'cs': 'csharp',
  'rb': 'ruby',
  'php': 'php',
  'sh': 'bash',
  'bash': 'bash',
  'zsh': 'bash',
  'fish': 'bash',
  'sql': 'sql',
  'ini': 'ini',
  'toml': 'ini',
  'lua': 'lua',
  'mk': 'makefile',
  'makefile': 'makefile',
  'dockerfile': 'dockerfile',
  'r': 'r',
  'pl': 'perl',
  'scala': 'scala',
  'groovy': 'groovy',
  'vim': 'vim',
  'tex': 'latex',
  'env': 'bash',
  'gradle': 'groovy',
  'properties': 'properties',
  'log': 'accesslog',
  'diff': 'diff',
  'patch': 'diff',
};

/// 编辑器默认字号；Ctrl + 0 会恢复到这个值。
const double _kDefaultFontSize = 14;

class _DocumentEditorPageState extends State<DocumentEditorPage> {
  late final CodeLineEditingController _controller;
  late final CodeFindController _findController;

  // 用于 _pageJump 通过 RenderBox 拿到 CodeEditor 的实际视口高度
  final GlobalKey _editorKey = GlobalKey();

  bool _isLoading = true;
  String? _error;
  String _savedSnapshot = '';
  bool _saving = false;

  // 视图相关状态
  bool _showLineNumbers = true;
  bool _wordWrap = true;
  bool _foldEnabled = true;
  double _fontSize = _kDefaultFontSize;
  late _EditorThemeChoice _theme;
  late String _languageKey;

  // 状态栏：当前光标行/列
  int _line = 1;
  int _col = 1;

  // 视图开关（F12 控制 AppBar 显隐；F11 全屏由 GlobalShortcutsService 处理）
  bool _hideAppBar = false;

  // F9 守卫：防止重复按 F9 叠出多个快捷键对话框
  bool _shortcutsDialogOpen = false;

  static const List<_EditorThemeChoice> _themes = [
    _EditorThemeChoice(
      key: 'atom-one-light',
      label: 'Atom One Light',
      theme: atomOneLightTheme,
      dark: false,
    ),
    _EditorThemeChoice(
      key: 'atom-one-dark',
      label: 'Atom One Dark',
      theme: atomOneDarkTheme,
      dark: true,
    ),
    _EditorThemeChoice(
      key: 'monokai-sublime',
      label: 'Monokai Sublime',
      theme: monokaiSublimeTheme,
      dark: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText('');
    _findController = CodeFindController(_controller);
    _controller.addListener(_onControllerChanged);
    _theme = _themes.first;
    _languageKey = _detectLanguageKey(widget.file.name);
    _restoreEditorTheme();
    // F9 / F12 用 HardwareKeyboard 在最早期拦截，避免与编辑器内 Focus 抢占
    // 导致首次按键被消耗。F10 因为是 Windows 系统快捷键（激活 menu bar），
    // 即使 Flutter 拦截了 WM_KEYDOWN 也会被 WM_SYSCOMMAND/SC_KEYMENU 副作用打断
    // 后续按键，所以避开 F10 改用 F12。
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _bootstrap();
  }

  Future<void> _restoreEditorTheme() async {
    final saved = await StorageService.instance.getEditorTheme();
    if (!mounted || saved == null || saved.isEmpty) return;
    for (final t in _themes) {
      if (t.key == saved && t.key != _theme.key) {
        setState(() => _theme = t);
        break;
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _controller.removeListener(_onControllerChanged);
    _findController.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.f9) {
      // 延迟到 microtask，让键盘事件链先派发结束，避免在 handler 内同步 setState
      // 引发的 widget tree rebuild 抢占下一次按键
      Future.microtask(() {
        if (mounted) _showAllShortcuts();
      });
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f12) {
      Future.microtask(() {
        if (mounted) _toggleHideAppBar();
      });
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      // re_editor 0.9.0 内部 moveCursorToPageUp/Down 是空 TODO，自己接管。
      // 走 HardwareKeyboard 而非 Shortcuts/CallbackShortcuts 是为了避开
      // re_editor 内部 Focus/Shortcuts 树对该键的潜在拦截。
      Future.microtask(() {
        if (mounted) _pageJump(false);
      });
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      Future.microtask(() {
        if (mounted) _pageJump(true);
      });
      return true;
    }
    return false;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // CodeEditor.initState 把 delegate 注入 controller 时会同步 notifyListeners，
    // 此时父 widget 还在 build 阶段，直接 setState 会抛错。延后到下一帧再处理。
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onControllerChanged();
      });
      return;
    }
    final selection = _controller.selection;
    final newLine = selection.extentIndex + 1;
    final newCol = selection.extentOffset + 1;
    if (newLine != _line || newCol != _col) {
      setState(() {
        _line = newLine;
        _col = newCol;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _bootstrap() async {
    if (widget.initialContent != null) {
      _setContent(widget.initialContent!);
      setState(() => _isLoading = false);
      return;
    }
    await _loadRemote();
  }

  Future<void> _loadRemote() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await FileService().getDownloadUrls(
        uris: [widget.file.relativePath],
        download: true,
      );
      final urls = response['urls'] as List<dynamic>? ?? [];
      if (urls.isEmpty) throw Exception('获取下载 URL 为空');
      final url = (urls.first as Map<String, dynamic>)['url'] as String;
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) {
        throw Exception('下载失败: ${r.statusCode}');
      }
      _setContent(TextDecodeUtils.decodeBytes(r.bodyBytes));
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      AppLogger.d('[DocumentEditor] load failed: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _setContent(String text) {
    _controller.text = text;
    _savedSnapshot = text;
  }

  bool get _dirty => _controller.text != _savedSnapshot;

  String _detectLanguageKey(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower == 'dockerfile') return 'dockerfile';
    if (lower == 'makefile') return 'makefile';
    final dot = lower.lastIndexOf('.');
    if (dot < 0 || dot == lower.length - 1) return 'plaintext';
    final ext = lower.substring(dot + 1);
    return _kExtensionToLanguage[ext] ?? 'plaintext';
  }

  CodeHighlightTheme? _buildHighlightTheme() {
    final mode = builtinAllLanguages[_languageKey];
    if (mode == null) return null;
    return CodeHighlightTheme(
      languages: {_languageKey: CodeHighlightThemeMode(mode: mode)},
      theme: _theme.theme,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final content = _controller.text;
    final fileName = widget.file.name;
    final relative = widget.file.relativePath;
    final parent = p.posix.dirname(relative);
    final targetDir = parent.isEmpty || parent == '.' ? '/' : parent;

    File? tempFile;
    try {
      final tmpDir = await getTemporaryDirectory();
      final stamped =
          'editor_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      tempFile = File(p.join(tmpDir.path, stamped));
      await tempFile.writeAsString(content, flush: true);

      final renamed = File(p.join(tmpDir.path, fileName));
      if (await renamed.exists()) {
        try {
          await renamed.delete();
        } catch (_) {}
      }
      await tempFile.rename(renamed.path);
      tempFile = renamed;

      if (!mounted) return;
      final uploadManager = context.read<UploadManagerProvider>();

      final ids = await uploadManager.startUpload(
        [tempFile],
        targetDir,
        overwrite: true,
        hidden: true,
      );
      if (ids.isEmpty) throw Exception('无法创建上传任务');
      final taskId = ids.first;

      // 通过监听 UploadService 的 notifyListeners 检查任务终态：
      // - completed → 成功
      // - failed / cancelled → 拿 errorMessage 作为失败原因
      final completer = Completer<String?>();
      void listener() {
        final t = UploadService.instance.getTask(taskId);
        if (t == null) return;
        if (t.status == UploadStatus.completed) {
          if (!completer.isCompleted) completer.complete(null);
        } else if (t.status == UploadStatus.failed ||
            t.status == UploadStatus.cancelled) {
          if (!completer.isCompleted) {
            completer.complete(t.errorMessage ?? '上传失败');
          }
        }
      }

      UploadService.instance.addListener(listener);
      String? error;
      try {
        error = await completer.future.timeout(
          const Duration(minutes: 10),
          onTimeout: () => '保存超时',
        );
      } finally {
        UploadService.instance.removeListener(listener);
      }

      if (error != null) {
        if (mounted) _showSaveError(error);
      } else {
        _savedSnapshot = content;
        if (mounted) ToastHelper.success('保存成功');
      }
    } catch (e) {
      AppLogger.d('[DocumentEditor] save failed: $e');
      if (mounted) _showSaveError(e.toString());
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSaveError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('保存失败：$message'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: '重试',
            onPressed: _save,
          ),
        ),
      );
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_dirty) return true;
    final keep = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('当前修改尚未保存，离开将丢失内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return keep ?? false;
  }

  void _changeFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(8, 32);
    });
  }

  void _resetFontSize() {
    if (_fontSize == _kDefaultFontSize) return;
    setState(() => _fontSize = _kDefaultFontSize);
  }

  void _cycleTheme() {
    final idx = _themes.indexWhere((t) => t.key == _theme.key);
    final next = _themes[(idx + 1) % _themes.length];
    _setTheme(next);
  }

  /// 按视口估算的"一页"行数跳转光标。
  ///
  /// re_editor 0.9.0 内部 `moveCursorToPageUp/Down` 是空 TODO，绑定 Intent 也
  /// 不会有效果，所以这里直接接管：拿当前 widget 的渲染高度估算一页能放多少行
  /// （行高近似为 fontSize * 1.4），再把 collapsed selection 推到新行。
  void _pageJump(bool forward) {
    final codeLines = _controller.codeLines;
    if (codeLines.isEmpty) return;

    final box = _editorKey.currentContext?.findRenderObject() as RenderBox?;
    final viewportHeight = box?.hasSize == true
        ? box!.size.height
        : MediaQuery.of(context).size.height - 100;
    final lineHeight = _fontSize * 1.4;
    final pageLines = (viewportHeight / lineHeight).floor().clamp(3, 200);

    final selection = _controller.selection;
    final base = selection.extentIndex;
    final newIndex = forward
        ? (base + pageLines).clamp(0, codeLines.length - 1)
        : (base - pageLines).clamp(0, codeLines.length - 1);
    final newOffset = selection.extentOffset.clamp(0, codeLines[newIndex].length);
    _controller.selection = CodeLineSelection.collapsed(
      index: newIndex,
      offset: newOffset,
    );
    _controller.makeCursorVisible();
  }

  void _setTheme(_EditorThemeChoice choice) {
    setState(() => _theme = choice);
    StorageService.instance.setEditorTheme(choice.key);
  }

  void _toggleFind() {
    final value = _findController.value;
    if (value == null) {
      _findController.findMode();
    } else if (value.replaceMode) {
      _findController.findMode();
    } else {
      _findController.close();
    }
  }

  void _toggleReplace() {
    final value = _findController.value;
    if (value == null || !value.replaceMode) {
      _findController.replaceMode();
    } else {
      _findController.close();
    }
  }

  void _toggleHideAppBar() {
    setState(() => _hideAppBar = !_hideAppBar);
  }

  void _showAllShortcuts() {
    if (_shortcutsDialogOpen) return;
    _shortcutsDialogOpen = true;
    final isDark = _theme.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    final dim = fg.withValues(alpha: 0.6);
    final bg = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final divider = isDark ? Colors.white12 : Colors.black12;

    const groups = <_ShortcutGroup>[
      _ShortcutGroup('编辑', [
        ('全选', 'Ctrl/⌘ + A'),
        ('剪切', 'Ctrl/⌘ + X'),
        ('复制', 'Ctrl/⌘ + C'),
        ('粘贴', 'Ctrl/⌘ + V'),
        ('撤销', 'Ctrl/⌘ + Z'),
        ('重做', 'Shift + Ctrl/⌘ + Z'),
        ('删除当前行', 'Ctrl/⌘ + D'),
        ('选中当前行', 'Ctrl/⌘ + L'),
        ('字符大小写转换', 'Ctrl/⌘ + T'),
      ]),
      _ShortcutGroup('光标 / 选择', [
        ('移动光标', '↑ ↓ ← →'),
        ('按单词边界移动', 'Alt + ← / →'),
        ('跳到页首 / 页尾', 'Ctrl/⌘ + ↑ / ↓'),
        ('上下翻页', 'PageUp / PageDown'),
        ('连续选择', 'Shift + ↑ / ↓ / ← / →'),
        ('上下移动当前行', 'Alt + ↑ / ↓'),
      ]),
      _ShortcutGroup('缩进 / 注释', [
        ('缩进', 'Tab'),
        ('取消缩进', 'Shift + Tab'),
        ('单行注释 / 取消', 'Ctrl/⌘ + /'),
        ('多行注释 / 取消', 'Shift + Ctrl/⌘ + /'),
      ]),
      _ShortcutGroup('搜索 / 文件', [
        ('查找', 'Ctrl/⌘ + F'),
        ('替换', 'Alt + Ctrl/⌘ + F'),
        ('保存', 'Ctrl/⌘ + S'),
        ('关闭搜索面板', 'Esc'),
      ]),
      _ShortcutGroup('视图', [
        ('全部快捷键', 'F9'),
        ('显示 / 隐藏菜单栏', 'F12'),
        ('全屏（仅桌面端）', 'F11'),
        ('放大字号', 'Ctrl/⌘ + + / ='),
        ('缩小字号', 'Ctrl/⌘ + -'),
        ('恢复默认字号', 'Ctrl/⌘ + 0'),
      ]),
    ];

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            brightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: AlertDialog(
            backgroundColor: bg,
            title: Row(
              children: [
                Icon(Icons.keyboard_outlined, size: 20, color: fg),
                const SizedBox(width: 8),
                Text('全部快捷键',
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      if (i > 0) Divider(color: divider, height: 24),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          groups[i].title,
                          style: TextStyle(
                            color: dim,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      for (final entry in groups[i].entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.$1,
                                  style: TextStyle(color: fg, fontSize: 13),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.$2,
                                  style: TextStyle(
                                    color: fg,
                                    fontFamily: 'SourceCodePro',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(foregroundColor: fg),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _shortcutsDialogOpen = false;
    });
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final highlight = _buildHighlightTheme();
    final isDark = _theme.dark;
    final scaffoldColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final ok = await _confirmDiscardIfDirty();
        if (!ok) return;
        navigator.pop();
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
              if (!_isLoading && !_saving && _dirty) _save();
            },
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
              if (!_isLoading && !_saving && _dirty) _save();
            },
            // 字号缩放：Ctrl/⌘ + = / + 放大，Ctrl/⌘ + - 缩小，Ctrl/⌘ + 0 还原
            const SingleActivator(LogicalKeyboardKey.equal, control: true):
                () => _changeFontSize(1),
            const SingleActivator(LogicalKeyboardKey.equal, meta: true):
                () => _changeFontSize(1),
            const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
                () => _changeFontSize(1),
            const SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true):
                () => _changeFontSize(1),
            const SingleActivator(LogicalKeyboardKey.minus, control: true):
                () => _changeFontSize(-1),
            const SingleActivator(LogicalKeyboardKey.minus, meta: true):
                () => _changeFontSize(-1),
            const SingleActivator(LogicalKeyboardKey.numpadSubtract,
                control: true): () => _changeFontSize(-1),
            const SingleActivator(LogicalKeyboardKey.numpadSubtract,
                meta: true): () => _changeFontSize(-1),
            const SingleActivator(LogicalKeyboardKey.digit0, control: true):
                _resetFontSize,
            const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
                _resetFontSize,
            const SingleActivator(LogicalKeyboardKey.numpad0, control: true):
                _resetFontSize,
            const SingleActivator(LogicalKeyboardKey.numpad0, meta: true):
                _resetFontSize,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: scaffoldColor,
              appBar: _hideAppBar ? null : _buildAppBar(isDark),
              body: _buildBody(highlight, isDark),
              bottomNavigationBar: _isLoading ? null : _buildStatusBar(isDark),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final fg = isDark ? Colors.white : Colors.black87;
    final subFg = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF252526) : Colors.white,
      foregroundColor: fg,
      elevation: 0,
      titleSpacing: wide ? 8 : 4,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _dirty ? Icons.fiber_manual_record : Icons.description_outlined,
            size: 14,
            color: _dirty ? Colors.orange : subFg,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.file.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: fg),
            ),
          ),
        ],
      ),
      actions: [
        if (wide) ..._buildWideActions(fg) else _buildNarrowMenu(fg),
        IconButton(
          tooltip: '保存 (Ctrl+S)',
          color: fg,
          disabledColor: fg.withValues(alpha: 0.3),
          icon: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : const Icon(Icons.save_outlined),
          onPressed: _isLoading || _saving || !_dirty ? null : _save,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 宽屏（>= 800px）：File / Edit / View 三个独立菜单按钮
  List<Widget> _buildWideActions(Color fg) {
    return [
      _buildMenuButton(
        'File',
        icon: Icons.insert_drive_file_outlined,
        items: _fileMenuItems(),
        onSelected: _handleMenuAction,
      ),
      _buildMenuButton(
        'Edit',
        icon: Icons.edit_outlined,
        items: _editMenuItems(),
        onSelected: _handleMenuAction,
      ),
      _buildMenuButton(
        'View',
        icon: Icons.visibility_outlined,
        items: _viewMenuItems(),
        onSelected: _handleMenuAction,
      ),
      const SizedBox(width: 4),
    ];
  }

  /// 窄屏（< 800px）：单个汉堡菜单聚合 File / Edit / View 三组
  Widget _buildNarrowMenu(Color fg) {
    final isDark = _theme.dark;
    final popupBg = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    return PopupMenuButton<String>(
      tooltip: '菜单',
      offset: const Offset(0, 40),
      color: popupBg,
      icon: Icon(Icons.menu, color: fg),
      itemBuilder: (_) => [
        ..._fileMenuItems(),
        const PopupMenuDivider(),
        ..._editMenuItems(),
        const PopupMenuDivider(),
        ..._viewMenuItems(),
      ],
      onSelected: _handleMenuAction,
    );
  }

  List<PopupMenuEntry<String>> _fileMenuItems() => [
        _menuItem(
          'save',
          '保存',
          Icons.save_outlined,
          shortcut: 'Ctrl+S',
          enabled: !_isLoading && !_saving && _dirty,
        ),
        _menuItem(
          'reload',
          '从远端重新加载',
          Icons.cloud_download_outlined,
          enabled: !_isLoading && !_saving,
        ),
        const PopupMenuDivider(),
        _menuItem('close', '关闭', Icons.close),
      ];

  List<PopupMenuEntry<String>> _editMenuItems() => [
        _menuItem(
          'undo',
          '撤销',
          Icons.undo,
          shortcut: 'Ctrl+Z',
          enabled: _controller.canUndo,
        ),
        _menuItem(
          'redo',
          '重做',
          Icons.redo,
          shortcut: 'Ctrl+Shift+Z',
          enabled: _controller.canRedo,
        ),
        const PopupMenuDivider(),
        _menuItem('cut', '剪切', Icons.content_cut, shortcut: 'Ctrl+X'),
        _menuItem('copy', '复制', Icons.content_copy, shortcut: 'Ctrl+C'),
        _menuItem('paste', '粘贴', Icons.content_paste, shortcut: 'Ctrl+V'),
        const PopupMenuDivider(),
        _menuItem('selectAll', '全选', Icons.select_all, shortcut: 'Ctrl+A'),
        _menuItem('find', '查找…', Icons.search, shortcut: 'Ctrl+F'),
        _menuItem('replace', '替换…', Icons.find_replace,
            shortcut: 'Ctrl+Alt+F'),
        const PopupMenuDivider(),
        _menuItem('shortcuts', '全部快捷键…', Icons.keyboard_outlined),
      ];

  List<PopupMenuEntry<String>> _viewMenuItems() => [
        _menuItem(
          'lineNumbers',
          '显示行号',
          _showLineNumbers ? Icons.check_box : Icons.check_box_outline_blank,
        ),
        _menuItem(
          'wordWrap',
          '自动换行',
          _wordWrap ? Icons.check_box : Icons.check_box_outline_blank,
        ),
        _menuItem(
          'fold',
          '代码折叠',
          _foldEnabled ? Icons.check_box : Icons.check_box_outline_blank,
        ),
        const PopupMenuDivider(),
        _menuItem('fontUp', '字号 +', Icons.text_increase),
        _menuItem('fontDown', '字号 -', Icons.text_decrease),
        const PopupMenuDivider(),
        for (final t in _themes)
          PopupMenuItem<String>(
            value: 'theme:${t.key}',
            child: Row(
              children: [
                Icon(
                  t.key == _theme.key
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: _theme.dark ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 10),
                Text(
                  t.label,
                  style: TextStyle(
                    color: _theme.dark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
      ];

  Future<void> _handleMenuAction(String value) async {
    switch (value) {
      case 'save':
        await _save();
        break;
      case 'reload':
        final ok = await _confirmDiscardIfDirty();
        if (ok) await _loadRemote();
        break;
      case 'close':
        if (mounted) Navigator.of(context).maybePop();
        break;
      case 'undo':
        _controller.undo();
        break;
      case 'redo':
        _controller.redo();
        break;
      case 'cut':
        _controller.cut();
        break;
      case 'copy':
        _controller.copy();
        break;
      case 'paste':
        _controller.paste();
        break;
      case 'selectAll':
        _controller.selectAll();
        break;
      case 'find':
        _toggleFind();
        break;
      case 'replace':
        _toggleReplace();
        break;
      case 'shortcuts':
        _showAllShortcuts();
        break;
      case 'lineNumbers':
        setState(() => _showLineNumbers = !_showLineNumbers);
        break;
      case 'wordWrap':
        setState(() => _wordWrap = !_wordWrap);
        break;
      case 'fold':
        setState(() => _foldEnabled = !_foldEnabled);
        break;
      case 'fontUp':
        _changeFontSize(1);
        break;
      case 'fontDown':
        _changeFontSize(-1);
        break;
      default:
        if (value.startsWith('theme:')) {
          final key = value.substring('theme:'.length);
          final choice = _themes.firstWhere((t) => t.key == key);
          _setTheme(choice);
        }
    }
  }

  Widget _buildMenuButton(
    String label, {
    required IconData icon,
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
  }) {
    final isDark = _theme.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    final popupBg = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    return PopupMenuButton<String>(
      tooltip: label,
      offset: const Offset(0, 40),
      color: popupBg,
      itemBuilder: (_) => items,
      onSelected: onSelected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 13, color: fg)),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    String label,
    IconData icon, {
    String? shortcut,
    bool enabled = true,
  }) {
    final isDark = _theme.dark;
    final base = isDark ? Colors.white : Colors.black87;
    final main = enabled ? base : base.withValues(alpha: 0.38);
    final shortcutColor = base.withValues(alpha: 0.5);
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 18, color: main),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: main))),
          if (shortcut != null) ...[
            const SizedBox(width: 16),
            Text(
              shortcut,
              style: TextStyle(fontSize: 11, color: shortcutColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(CodeHighlightTheme? highlight, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
            const SizedBox(height: 12),
            Text('加载失败: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadRemote,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final fg = isDark ? Colors.white : Colors.black87;
    return CodeEditor(
      key: _editorKey,
      controller: _controller,
      findController: _findController,
      wordWrap: _wordWrap,
      shortcutOverrideActions: {
        CodeShortcutSaveIntent: CallbackAction<CodeShortcutSaveIntent>(
          onInvoke: (_) {
            if (!_isLoading && !_saving && _dirty) _save();
            return null;
          },
        ),
      },
      chunkAnalyzer: _foldEnabled
          ? const DefaultCodeChunkAnalyzer()
          : const NonCodeChunkAnalyzer(),
      style: CodeEditorStyle(
        fontFamily: 'SourceCodePro',
        fontSize: _fontSize,
        codeTheme: highlight,
        textColor: fg,
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
        cursorColor: isDark ? Colors.white : Colors.blueAccent,
        selectionColor: isDark
            ? const Color(0x553E5872)
            : const Color(0x553B82F6),
      ),
      indicatorBuilder:
          (context, editingController, chunkController, notifier) {
        return Row(
          children: [
            if (_showLineNumbers)
              DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
              ),
            if (_foldEnabled)
              DefaultCodeChunkIndicator(
                width: 18,
                controller: chunkController,
                notifier: notifier,
              ),
          ],
        );
      },
      findBuilder: (context, controller, readOnly) =>
          _CodeFindPanel(controller: controller, readOnly: readOnly, isDark: isDark),
    );
  }

  Widget _buildStatusBar(bool isDark) {
    final bg = isDark ? const Color(0xFF007ACC) : const Color(0xFF0E639C);
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Container(
      height: 24,
      color: bg,
      padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 8),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 11, color: Colors.white),
        child: wide ? _buildWideStatusBar() : _buildNarrowStatusBar(),
      ),
    );
  }

  /// 宽屏（>= 800px）：完整状态栏（已保存状态 / 行列号 / 行数·字符数 / 语言 / 主题 / 字号）
  Widget _buildWideStatusBar() {
    final length = _controller.text.length;
    final lineCount = _controller.codeLines.length;
    return Row(
      children: [
        Icon(
          _dirty ? Icons.circle : Icons.check_circle,
          size: 11,
          color: Colors.white,
        ),
        const SizedBox(width: 6),
        Text(_dirty ? '未保存' : '已保存'),
        const SizedBox(width: 16),
        Text('行 $_line, 列 $_col'),
        const SizedBox(width: 16),
        Text('$lineCount 行 · $length 字符'),
        const Spacer(),
        Text(_languageKey == 'plaintext' ? 'Plain Text' : _languageKey),
        const SizedBox(width: 16),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _cycleTheme,
            child: Tooltip(
              message: '点击切换主题',
              child: Text(_theme.label),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text('${_fontSize.toInt()}px'),
      ],
    );
  }

  /// 窄屏（< 800px）：精简状态栏（保留：状态、行:列、主题、字号）
  Widget _buildNarrowStatusBar() {
    return Row(
      children: [
        Icon(
          _dirty ? Icons.circle : Icons.check_circle,
          size: 11,
          color: Colors.white,
        ),
        const SizedBox(width: 4),
        Text(_dirty ? '未保存' : '已保存'),
        const SizedBox(width: 8),
        Text('$_line:$_col'),
        const Spacer(),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _cycleTheme,
            child: Tooltip(
              message: '点击切换主题',
              child: Text(_theme.label),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${_fontSize.toInt()}px'),
      ],
    );
  }
}

/// 仿 vscode 顶部查找/替换面板。
class _CodeFindPanel extends StatefulWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final bool readOnly;
  final bool isDark;

  const _CodeFindPanel({
    required this.controller,
    required this.readOnly,
    required this.isDark,
  });

  // re_editor 用 preferredSize.height 作为编辑器顶部 padding，
  // 必须跟着 controller.value 走，否则面板未激活时顶部会空出一大块。
  @override
  Size get preferredSize {
    final value = controller.value;
    if (value == null) return Size.zero;
    return value.replaceMode
        ? const Size.fromHeight(86)
        : const Size.fromHeight(48);
  }

  @override
  State<_CodeFindPanel> createState() => _CodeFindPanelState();
}

class _CodeFindPanelState extends State<_CodeFindPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    if (value == null) return const SizedBox.shrink();

    final isReplace = value.replaceMode;
    final matches = value.result?.matches.length ?? 0;
    final current = (value.result?.index ?? -1) + 1;
    final dark = widget.isDark;
    final bg = dark ? const Color(0xFF252526) : const Color(0xFFF3F3F3);
    final fg = dark ? Colors.white : Colors.black87;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.controller.close,
      },
      child: Material(
        color: bg,
        elevation: 1,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFindRow(value, matches, current, fg, dark),
                if (isReplace) ...[
                  const SizedBox(height: 6),
                  _buildReplaceRow(fg, dark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFindRow(
    CodeFindValue value,
    int matches,
    int current,
    Color fg,
    bool dark,
  ) {
    final disabled = fg.withValues(alpha: 0.3);
    return Row(
      children: [
        IconButton(
          tooltip: value.replaceMode ? '隐藏替换' : '显示替换',
          iconSize: 18,
          color: fg,
          disabledColor: disabled,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: widget.readOnly ? null : widget.controller.toggleMode,
          icon: Icon(value.replaceMode ? Icons.expand_less : Icons.expand_more),
        ),
        Expanded(
          child: TextField(
            controller: widget.controller.findInputController,
            focusNode: widget.controller.findInputFocusNode,
            style: TextStyle(color: fg, fontSize: 13),
            decoration: _inputDecoration(
              hint: '查找',
              dark: dark,
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _toggleIconButton(
                    tooltip: '区分大小写',
                    icon: Icons.text_fields,
                    selected: value.option.caseSensitive,
                    onTap: widget.controller.toggleCaseSensitive,
                    fg: fg,
                  ),
                  _toggleIconButton(
                    tooltip: '正则',
                    icon: Icons.code,
                    selected: value.option.regex,
                    onTap: widget.controller.toggleRegex,
                    fg: fg,
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => widget.controller.nextMatch(),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 70),
          child: Text(
            matches == 0 ? '无结果' : '$current / $matches',
            style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.75)),
            textAlign: TextAlign.right,
          ),
        ),
        IconButton(
          tooltip: '上一个',
          iconSize: 18,
          color: fg,
          disabledColor: disabled,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: matches == 0 ? null : widget.controller.previousMatch,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: '下一个',
          iconSize: 18,
          color: fg,
          disabledColor: disabled,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: matches == 0 ? null : widget.controller.nextMatch,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        IconButton(
          tooltip: '关闭',
          iconSize: 18,
          color: fg,
          disabledColor: disabled,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: widget.controller.close,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildReplaceRow(Color fg, bool dark) {
    final disabled = fg.withValues(alpha: 0.3);
    return Row(
      children: [
        const SizedBox(width: 32),
        Expanded(
          child: TextField(
            controller: widget.controller.replaceInputController,
            focusNode: widget.controller.replaceInputFocusNode,
            style: TextStyle(color: fg, fontSize: 13),
            decoration: _inputDecoration(hint: '替换为', dark: dark),
            onSubmitted: widget.readOnly
                ? null
                : (_) => widget.controller.replaceMatch(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '替换',
          iconSize: 18,
          color: fg,
          disabledColor: disabled,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: widget.readOnly ? null : widget.controller.replaceMatch,
          icon: const Icon(Icons.find_replace),
        ),
        IconButton(
          tooltip: '全部替换',
          iconSize: 18,
          color: fg,
          disabledColor: disabled,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed:
              widget.readOnly ? null : widget.controller.replaceAllMatches,
          icon: const Icon(Icons.swap_horiz),
        ),
        const SizedBox(width: 32),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool dark,
    Widget? suffix,
  }) {
    final fill = dark ? const Color(0xFF3C3C3C) : Colors.white;
    final border = dark ? const Color(0xFF555555) : const Color(0xFFCCCCCC);
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(
        color: dark ? Colors.grey.shade500 : Colors.grey.shade600,
        fontSize: 13,
      ),
      filled: true,
      fillColor: fill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: Color(0xFF007ACC)),
      ),
      suffixIcon: suffix,
      suffixIconConstraints:
          const BoxConstraints(minWidth: 0, minHeight: 0),
    );
  }

  Widget _toggleIconButton({
    required String tooltip,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color fg,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? const Color(0x33007ACC) : Colors.transparent,
            border: Border.all(
              color: selected
                  ? const Color(0xFF007ACC)
                  : Colors.transparent,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(icon, size: 14, color: fg),
        ),
      ),
    );
  }
}

class _ShortcutGroup {
  final String title;
  final List<(String, String)> entries;
  const _ShortcutGroup(this.title, this.entries);
}
