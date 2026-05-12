/// 文件工具类
class FileUtils {
  /// 将路径转换为 Cloudreve URI 格式
  /// "/" → "cloudreve://my", "/subfolder" → "cloudreve://my/subfolder"
  static String toCloudreveUri(String path) {
    if (path.startsWith('cloudreve://')) return path;
    if (path == '/' || path.isEmpty) return 'cloudreve://my';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return 'cloudreve://my/$cleanPath';
  }
  /// 获取文件扩展名
  static String getFileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  /// 判断是否为图片文件
  static bool isImageFile(String fileName) {
    const imageExtensions = [
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic'
    ];
    return imageExtensions.contains(getFileExtension(fileName));
  }

  /// 判断是否为视频文件
  static bool isVideoFile(String fileName) {
    const videoExtensions = [
      'mp4', 'webm', 'mkv', 'avi', 'mov', 'flv', 'wmv'
    ];
    return videoExtensions.contains(getFileExtension(fileName));
  }

  /// 判断是否为音频文件
  static bool isAudioFile(String fileName) {
    const audioExtensions = [
      'mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'
    ];
    return audioExtensions.contains(getFileExtension(fileName));
  }

  /// 判断是否为PDF文件
  static bool isPdfFile(String fileName) {
    return getFileExtension(fileName) == 'pdf';
  }

  /// 判断是否为文本文件
  static bool isTextFile(String fileName) {
    const textExtensions = [
      'txt', 'md', 'json', 'xml', 'yaml', 'yml', 'ini', 'conf'
    ];
    return textExtensions.contains(getFileExtension(fileName));
  }

  /// 判断是否为代码文件
  static bool isCodeFile(String fileName) {
    const codeExtensions = [
      'js', 'ts', 'tsx', 'jsx', 'dart', 'java', 'py', 'c', 'cpp',
      'h', 'hpp', 'cs', 'php', 'rb', 'go', 'rs', 'swift', 'kt',
      'html', 'css', 'scss', 'less', 'sql', 'sh', 'bat'
    ];
    return codeExtensions.contains(getFileExtension(fileName));
  }

  /// 判断是否为压缩文件
  static bool isArchiveFile(String fileName) {
    const archiveExtensions = [
      'zip', 'rar', '7z', 'tar', 'gz', 'bz2'
    ];
    return archiveExtensions.contains(getFileExtension(fileName));
  }

  /// 判断是否为文档文件
  static bool isDocumentFile(String fileName) {
    const docExtensions = [
      'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp'
    ];
    return docExtensions.contains(getFileExtension(fileName));
  }

  /// 判断是否可预览
  static bool isPreviewable(String fileName) {
    return isImageFile(fileName) || isVideoFile(fileName) ||
           isPdfFile(fileName) || isTextFile(fileName) || isCodeFile(fileName);
  }

  /// 获取MIME类型
  static String getMimeType(String fileName) {
    final ext = getFileExtension(fileName);
    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
      'mp4': 'video/mp4',
      'webm': 'video/webm',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'json': 'application/json',
      'xml': 'application/xml',
      'html': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  /// 获取文件图标
  static String getFileIcon(String fileName) {
    if (isImageFile(fileName)) return 'assets/icons/image.svg';
    if (isVideoFile(fileName)) return 'assets/icons/video.svg';
    if (isAudioFile(fileName)) return 'assets/icons/audio.svg';
    if (isPdfFile(fileName)) return 'assets/icons/pdf.svg';
    if (isTextFile(fileName)) return 'assets/icons/text.svg';
    if (isCodeFile(fileName)) return 'assets/icons/code.svg';
    if (isArchiveFile(fileName)) return 'assets/icons/archive.svg';
    if (isDocumentFile(fileName)) return 'assets/icons/document.svg';

    return 'assets/icons/file.svg';
  }
}
