// Blok kode dengan syntax highlighting (parity web Highlight.js,
// tema atom-one-dark). Tidak pernah throw: gagal parse → teks polos.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight.dart' show highlight;

class CodeBlock extends StatelessWidget {
  final String code;
  final String? language;

  const CodeBlock({super.key, required this.code, this.language});

  /// Bahasa yang didukung paket highlight (subset umum + aman).
  static const _supported = {
    'dart',
    'python',
    'javascript',
    'typescript',
    'java',
    'kotlin',
    'swift',
    'cpp',
    'c',
    'csharp',
    'go',
    'rust',
    'php',
    'ruby',
    'sql',
    'bash',
    'shell',
    'json',
    'yaml',
    'xml',
    'html',
    'css',
    'markdown',
    'plaintext',
  };

  static String? _normalizeLanguage(String? raw) {
    if (raw == null) return null;
    var s = raw.trim().toLowerCase();
    if (s.startsWith('language-')) s = s.substring('language-'.length);
    if (s.startsWith('lang-')) s = s.substring('lang-'.length);
    const aliases = {
      'js': 'javascript',
      'ts': 'typescript',
      'py': 'python',
      'sh': 'bash',
      'yml': 'yaml',
      'c++': 'cpp',
      'c#': 'csharp',
    };
    s = aliases[s] ?? s;
    return _supported.contains(s) ? s : null;
  }

  // Palet atom-one-dark (dipakai web) dengan sedikit adaptasi light mode.
  Color _colorFor(String? className, bool isDark) {
    switch (className) {
      case 'keyword':
      case 'selector-tag':
      case 'literal':
        return const Color(0xFFC678DD);
      case 'string':
      case 'regexp':
      case 'meta-string':
        return const Color(0xFF98C379);
      case 'number':
        return const Color(0xFFD19A66);
      case 'comment':
      case 'quote':
        return const Color(0xFF7F848E);
      case 'title':
      case 'title.function_':
      case 'section':
        return const Color(0xFF61AFEF);
      case 'built_in':
      case 'builtin-name':
        return const Color(0xFFE5C07B);
      case 'attr':
      case 'attribute':
      case 'variable':
      case 'template-variable':
        return const Color(0xFFD19A66);
      case 'name':
      case 'selector-id':
      case 'selector-class':
        return const Color(0xFFE06C75);
      case 'type':
      case 'class':
        return const Color(0xFFE5C07B);
      case 'symbol':
      case 'bullet':
      case 'link':
        return const Color(0xFF56B6C2);
      case 'operator':
      case 'punctuation':
        return isDark ? const Color(0xFFABB2BF) : const Color(0xFF383A42);
      case 'emphasis':
        return isDark ? const Color(0xFFABB2BF) : const Color(0xFF383A42);
      case 'strong':
        return isDark ? const Color(0xFFABB2BF) : const Color(0xFF383A42);
      default:
        return isDark ? const Color(0xFFABB2BF) : const Color(0xFF383A42);
    }
  }

  List<TextSpan> _buildSpans(dynamic nodes, bool isDark, double fontSize) {
    final spans = <TextSpan>[];
    if (nodes is! List) return spans;
    for (final node in nodes) {
      String? cls;
      String? text;
      List<dynamic>? children;
      try {
        cls = (node as dynamic).className as String?;
        text = (node as dynamic).value as String?;
        children = (node as dynamic).children as List<dynamic>?;
      } catch (_) {
        continue;
      }
      final style = TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        color: _colorFor(cls, isDark),
        fontStyle: cls == 'emphasis' ? FontStyle.italic : FontStyle.normal,
        fontWeight: cls == 'strong' ? FontWeight.bold : FontWeight.normal,
        height: 1.5,
      );
      if (children != null && children.isNotEmpty) {
        spans.add(TextSpan(
            style: style, children: _buildSpans(children, isDark, fontSize)));
      } else if (text != null) {
        spans.add(TextSpan(text: text, style: style));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<TextSpan> spans;
    try {
      final lang = _normalizeLanguage(language);
      final result = lang == null
          ? highlight.parse(code, autoDetection: true)
          : highlight.parse(code, language: lang);
      final built =
          _buildSpans(result.nodes, isDark, 12.5);
      spans = built.isEmpty
          ? [
              TextSpan(
                text: code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: isDark
                      ? const Color(0xFFABB2BF)
                      : const Color(0xFF383A42),
                  height: 1.5,
                ),
              ),
            ]
          : built;
    } catch (_) {
      spans = [
        TextSpan(
          text: code,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            color:
                isDark ? const Color(0xFFABB2BF) : const Color(0xFF383A42),
            height: 1.5,
          ),
        ),
      ];
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282C34) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((language ?? '').isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF21252B)
                    : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _normalizeLanguage(language) ?? language!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF7F848E)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kode disalin'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    child: Icon(
                      Icons.copy_outlined,
                      size: 14,
                      color: isDark
                          ? const Color(0xFF7F848E)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: RichText(text: TextSpan(children: spans)),
          ),
        ],
      ),
    );
  }
}
