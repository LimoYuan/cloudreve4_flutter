import 'dart:convert';

import 'package:enough_convert/enough_convert.dart';

/// 文本字节解码工具：兼容非 UTF-8 编码的文本文件。
///
/// 解码优先级：
/// 1. BOM 探测（UTF-8 / UTF-16 LE / UTF-16 BE），命中即按对应编码解码并剥离 BOM
/// 2. 严格 UTF-8 解码（无 BOM 的标准文本）
/// 3. GB18030 严格解码（ASCII + 2 字节 GBK/GB2312 + 4 字节序列，覆盖简体中文 ANSI）
/// 4. latin1 兜底（保证不抛异常）
class TextDecodeUtils {
  TextDecodeUtils._();

  /// 将原始字节按最可能的编码解码为字符串。
  static String decodeBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';

    // 1. BOM 探测
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      // UTF-8 BOM
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // UTF-16 LE BOM
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // UTF-16 BE BOM
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }

    // 2. 严格 UTF-8
    try {
      return const Utf8Decoder(allowMalformed: false).convert(bytes);
    } catch (_) {}

    // 3. GB18030（含 GBK/GB2312）严格解码
    try {
      return _decodeGb18030Strict(bytes);
    } catch (_) {}

    // 4. latin1 兜底
    return latin1.decode(bytes);
  }

  /// 严格 GB18030 解码：结构非法时抛异常（让上层落到 latin1），
  /// 从而避免把 latin1 文本误判成 GBK。
  ///
  /// - ASCII（<0x80）与 2 字节 GBK/GB2312：交给 enough_convert 的 GbkCodec 校验解码
  /// - 4 字节序列：补充平面（U+10000+）按算法直接解码；BMP 四字节因无映射表
  ///   降级为替换符 `�`，但严格消费 4 字节保证后续不串位
  static String _decodeGb18030Strict(List<int> bytes) {
    final buf = StringBuffer();
    final gbkRun = <int>[];

    void flush() {
      if (gbkRun.isNotEmpty) {
        // allowInvalid:false：遇到非法 GBK 字节会抛 FormatException
        buf.write(const GbkCodec(allowInvalid: false).decode(gbkRun));
        gbkRun.clear();
      }
    }

    var i = 0;
    while (i < bytes.length) {
      final b = bytes[i];
      // GB18030 4 字节序列：lead(0x81-0xFE) + (0x30-0x39) + (0x81-0xFE) + (0x30-0x39)
      if (b >= 0x81 && b <= 0xFE && i + 3 < bytes.length) {
        final b2 = bytes[i + 1];
        if (b2 >= 0x30 && b2 <= 0x39) {
          final b3 = bytes[i + 2];
          final b4 = bytes[i + 3];
          if (!(b3 >= 0x81 && b3 <= 0xFE && b4 >= 0x30 && b4 <= 0x39)) {
            throw const FormatException('invalid GB18030 four-byte sequence');
          }
          flush();
          final cp = _gb18030FourByteToCodePoint(b, b2, b3, b4);
          buf.writeCharCode(cp ?? 0xFFFD);
          i += 4;
          continue;
        }
      }
      // 其余字节交给 GBK 解码器累积校验（ASCII 直通、2 字节成对校验）
      gbkRun.add(b);
      i++;
    }
    flush();
    return buf.toString();
  }

  /// GB18030 4 字节 → Unicode 码点。
  /// 仅算法可解的补充平面（U+10000-U+10FFFF）返回真实码点；
  /// BMP 区间需查表，此处返回 null 由调用方降级为替换符。
  static int? _gb18030FourByteToCodePoint(int b1, int b2, int b3, int b4) {
    final linear =
        ((b1 - 0x81) * 10 + (b2 - 0x30)) * 1260 +
        (b3 - 0x81) * 10 +
        (b4 - 0x30);
    // 补充平面：pointer 189000 → U+10000
    if (linear >= 189000 && linear <= 1237575) {
      return 0x10000 + (linear - 189000);
    }
    return null;
  }

  static String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }
}
