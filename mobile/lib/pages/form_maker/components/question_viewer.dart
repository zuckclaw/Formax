import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../models/question_model.dart';
import '../../../widgets/ngrok_image.dart';
import '../../../widgets/rich_text_view.dart';

class QuestionViewer extends StatelessWidget {
  final QuestionData question;

  const QuestionViewer({super.key, required this.question});

  bool _looksLikeHtml(String s) => s.contains('<');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF8FAFC) : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.black54;

    final hasLabel = question.label.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: hasLabel
                  ? (_looksLikeHtml(question.label)
                        ? RichTextView(
                            html: question.label,
                            textStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          )
                        : Text(
                            question.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ))
                  : Text('Pertanyaan', style: TextStyle(color: subTextColor)),
            ),
            if (question.isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
          ],
        ),
        if (question.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: _looksLikeHtml(question.description)
                ? RichTextView(
                    html: question.description,
                    textStyle: TextStyle(fontSize: 13, color: subTextColor),
                  )
                : Text(
                    question.description,
                    style: TextStyle(fontSize: 13, color: subTextColor),
                  ),
          ),
        const SizedBox(height: 16),
        _buildBody(context, isDark),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    // Untuk tipe non-gambar: tampilkan semua gambar yang ditempel, ditumpuk
    // di atas konten pertanyaan (perilaku seperti Google Form).
    if (question.type != QuestionType.image) {
      final urls = question.allImageUrls;
      if (urls.isEmpty) {
        return _buildBodyByType(context, isDark);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final url in urls)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (kIsWeb || url.startsWith('http'))
                    ? NgrokImage(url, width: double.infinity, fit: BoxFit.cover)
                    : Image.file(
                        File(url),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          _buildBodyByType(context, isDark),
        ],
      );
    }

    return _buildBodyByType(context, isDark);
  }

  Widget _buildBodyByType(BuildContext context, bool isDark) {
    final subColor = isDark ? const Color(0xFF94A3B8) : Colors.black38;
    final textColor = isDark ? const Color(0xFFF8FAFC) : Colors.black87;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.black12;

    switch (question.type) {
      case QuestionType.shortAnswer:
        return TextField(
          enabled: false,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Jawaban singkat',
            hintStyle: TextStyle(color: subColor),
            isDense: true,
            border: const UnderlineInputBorder(),
          ),
        );
      case QuestionType.paragraph:
        return TextField(
          enabled: false,
          maxLines: 3,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Jawaban panjang',
            hintStyle: TextStyle(color: subColor),
            isDense: true,
            border: const UnderlineInputBorder(),
          ),
        );
      case QuestionType.multipleChoice:
      case QuestionType.checkboxes:
        return Column(
          children: question.options.asMap().entries.expand((entry) {
            final opt = entry.value;
            final isOther = opt.isOther;
            final optionTile = Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(
                    question.type == QuestionType.multipleChoice
                        ? Icons.radio_button_unchecked
                        : Icons.check_box_outline_blank,
                    size: 20,
                    color: subColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: opt.label.isEmpty
                        ? Text(
                            'Opsi',
                            style: TextStyle(fontSize: 14, color: subColor),
                          )
                        : (_looksLikeHtml(opt.label)
                              ? RichTextView(
                                  html: opt.label,
                                  textStyle: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                )
                              : Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                )),
                  ),
                ],
              ),
            );
            if (isOther) {
              return [
                optionTile,
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    enabled: false,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Jawaban lainnya',
                      hintStyle: TextStyle(color: subColor),
                      isDense: true,
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                ),
              ];
            }
            return [optionTile];
          }).toList(),
        );
      case QuestionType.dropdown:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pilih opsi', style: TextStyle(color: subColor)),
              Icon(Icons.arrow_drop_down, color: subColor),
            ],
          ),
        );
      case QuestionType.fileUpload:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, color: subColor),
              const SizedBox(width: 8),
              Text('Tambahkan File', style: TextStyle(color: subColor)),
            ],
          ),
        );
      case QuestionType.linearScale:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                question.scaleMax - question.scaleMin + 1,
                (index) => Column(
                  children: [
                    Text(
                      '${question.scaleMin + index}',
                      style: TextStyle(color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.radio_button_unchecked, color: subColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  question.minLabel,
                  style: TextStyle(color: subColor, fontSize: 12),
                ),
                Text(
                  question.maxLabel,
                  style: TextStyle(color: subColor, fontSize: 12),
                ),
              ],
            ),
          ],
        );
      case QuestionType.rating:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            question.ratingCount,
            (index) => Icon(
              question.ratingIcon == 'heart'
                  ? Icons.favorite_border
                  : Icons.star_border,
              color: subColor,
              size: 32,
            ),
          ),
        );
      case QuestionType.date:
        return TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'HH/BB/TTTT',
            hintStyle: TextStyle(color: subColor),
            suffixIcon: Icon(Icons.calendar_today, color: subColor),
            isDense: true,
            border: const UnderlineInputBorder(),
          ),
        );
      case QuestionType.time:
        return TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Waktu',
            hintStyle: TextStyle(color: subColor),
            suffixIcon: Icon(Icons.access_time, color: subColor),
            isDense: true,
            border: const UnderlineInputBorder(),
          ),
        );
      case QuestionType.image:
        final urls = question.allImageUrls;
        if (urls.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(child: Icon(Icons.image, color: subColor, size: 40)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            children: [
              for (final url in urls)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: (kIsWeb || url.startsWith('http'))
                      ? NgrokImage(url, fit: BoxFit.cover)
                      : Image.file(File(url), fit: BoxFit.cover),
                ),
            ],
          ),
        );
      case QuestionType.text:
      case QuestionType.pageBreak:
        return const SizedBox.shrink();
      default:
        return Text(
          'Preview untuk tipe ${question.type.label} belum didukung',
          style: TextStyle(color: subColor, fontStyle: FontStyle.italic),
        );
    }
  }
}
