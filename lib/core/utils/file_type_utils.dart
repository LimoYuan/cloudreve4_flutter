/// 文件类型工具类
class FileTypeUtils {
  /// 图片扩展名
  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'ico',
    'tiff',
    'tif',
  };

  /// PDF扩展名
  static const _pdfExtensions = {'pdf'};

  /// 视频扩展名
  static const _videoExtensions = {
    'mp4',
    'avi',
    'mov',
    'wmv',
    'flv',
    'mkv',
    'webm',
    'm4v',
    '3gp',
    '3g2',
  };

  /// 音频扩展名
  static const _audioExtensions = {
    'mp3',
    'wav',
    'ogg',
    'flac',
    'aac',
    'm4a',
    'wma',
  };

  /// 文档扩展名
  static const _documentExtensions = {
    'txt',
    'md',
    'json',
    'xml',
    'yaml',
    'yml',
    'ini',
    'cfg',
    'conf',
    'log',
    'csv',
  };

  /// 代码文件扩展名
  static const _codeExtensions = {
    'dart',
    'js',
    'ts',
    'html',
    'css',
    'scss',
    'less',
    'python',
    'py',
    'java',
    'kt',
    'kts',
    'swift',
    'cpp',
    'c',
    'h',
    'hpp',
    'cs',
    'go',
    'rs',
    'php',
    'rb',
    'sql',
    'sh',
    'bash',
    'zsh',
    'ps1',
    'bat',
    'cmd',
  };

  /// 检测是否为图片
  static bool isImage(String fileName) {
    final ext = getExtension(fileName);
    return _imageExtensions.contains(ext);
  }

  /// 检测是否为PDF
  static bool isPdf(String fileName) {
    final ext = getExtension(fileName);
    return _pdfExtensions.contains(ext);
  }

  /// 检测是否为视频
  static bool isVideo(String fileName) {
    final ext = getExtension(fileName);
    return _videoExtensions.contains(ext);
  }

  /// 检测是否为音频
  static bool isAudio(String fileName) {
    final ext = getExtension(fileName);
    return _audioExtensions.contains(ext);
  }

  /// 检测是否为文档
  static bool isDocument(String fileName) {
    final ext = getExtension(fileName);
    return _documentExtensions.contains(ext) || _codeExtensions.contains(ext);
  }

  /// 检测是否为Markdown
  static bool isMarkdown(String fileName) {
    final ext = getExtension(fileName);
    return ext == 'md';
  }

  /// 检测是否为文本或代码文件（排除markdown）
  static bool isTextCode(String fileName) {
    final ext = getExtension(fileName);
    return (_documentExtensions.contains(ext) && ext != 'md') ||
           _codeExtensions.contains(ext);
  }

  /// 检测是否支持预览
  static bool isPreviewable(String fileName) {
    return isImage(fileName) ||
        isPdf(fileName) ||
        isVideo(fileName) ||
        isAudio(fileName) ||
        isDocument(fileName);
  }

  /// 获取文件扩展名
  static String getExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) {
      return '';
    }
    return parts.last.toLowerCase();
  }

  /// 获取文件类型描述
  static String getFileTypeDescription(String fileName) {
    if (isImage(fileName)) {
      return '图片';
    } else if (isPdf(fileName)) {
      return 'PDF文档';
    } else if (isVideo(fileName)) {
      return '视频';
    } else if (isAudio(fileName)) {
      return '音频';
    } else if (isMarkdown(fileName)) {
      return 'Markdown文档';
    } else if (isDocument(fileName)) {
      return '文档';
    }
    return '文件';
  }
}
