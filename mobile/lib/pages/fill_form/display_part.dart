// Widget display FillFormPage — bookmark, progress, banner, header, kartu soal.
// Dipindah verbatim dari `lib/pages/fillformpage.dart` (Tahap 3a) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// akses ke state privat tetap sah; call-site tidak berubah.
// Satu-satunya penyesuaian: callback setState "Tutup" filter bookmark
// didelegasikan ke State._clearBookmarkFilter (extension dilarang memanggil
// protected member langsung) — urutan + isi statement identik.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../fillformpage.dart';

extension _FillFormDisplay on _FillFormPageState {
  Widget _buildBookmarkIndicator() {
    final count = _bookmarkedQids.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFEF9C3),
      child: Row(
        children: [
          const Icon(Icons.bookmark, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 0
                  ? 'Belum ada soal yang ditandai'
                  : 'Menampilkan $count soal yang ditandai',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _clearBookmarkFilter(),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Tutup'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBookmarkState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.bookmark_border, size: 48, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          const Text(
            'Belum ada soal yang ditandai',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ketik ikon tanda pada setiap soal untuk mengaturnya.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _formData?.questions.length ?? 0;
    final progress = total > 0 ? _answeredCount / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_answeredCount / $total terjawab',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Halaman ${_currentPage + 1} / $_totalPages',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1E66D0),
              ),
              minHeight: 6,
            ),
          ),
          if (_timeLeft > Duration.zero) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _timeLeft < const Duration(minutes: 1)
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _timeLeft < const Duration(minutes: 1)
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF86EFAC),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: _timeLeft < const Duration(minutes: 1)
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sisa waktu:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const Spacer(),
                  Text(
                    _formatCountdown(_timeLeft),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _timeLeft < const Duration(minutes: 1)
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Banner info mode pratinjau pemilik — menjelaskan mengapa tombol
  /// Submit tidak ada dan mengapa pratinjau tidak masuk Aktivitas Saya.
  Widget _buildOwnerPreviewBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined,
              color: Color(0xFF1E66D0), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pratinjau pemilik',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E40AF),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ini form buatanmu. Kamu melihatnya sebagai pratinjau — '
                  'jawaban tidak dikirim dan tidak tercatat di Aktivitas Saya. '
                  'Untuk menguji pengisian, buka link ini tanpa login atau '
                  'dengan akun lain.',
                  style: TextStyle(
                      color: Color(0xFF1E40AF), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner image
          if (_formData?.bannerUrl != null && _formData!.bannerUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 150,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NgrokImage.provider(_formData!.bannerUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          // static member State → wajib qualified dari extension.
          _FillFormPageState._looksLikeHtml(_formData!.title)
              ? RichTextView(
                  html: _formData!.title,
                  textStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                )
              : Text(
                  _formData!.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
          if (_formData?.description != null &&
              _formData!.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _FillFormPageState._looksLikeHtml(_formData!.description!)
                ? RichTextView(
                    html: _formData!.description!,
                    textStyle: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  )
                : Text(
                    _formData!.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_formData!.questions.length} pertanyaan',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Question question, int index) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question label
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E66D0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: question.label.contains('<')
                    ? RichTextView(
                        html: question.label,
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      )
                    : RichText(
                        text: TextSpan(
                          text: question.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          children: [
                            if (question.isRequired)
                              const TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _toggleBookmark(question.id),
                tooltip: _bookmarkedQids.contains(question.id)
                    ? 'Hapus tanda'
                    : 'Tandai soal ini',
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: Icon(
                  _bookmarkedQids.contains(question.id)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: _bookmarkedQids.contains(question.id)
                      ? const Color(0xFFB45309)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (question.type != 'image' && question.allImageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final url in question.allImageUrls)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NgrokImage(
                    url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),

          // Answer input based on question type
          _buildAnswerInput(question),
        ],
      ),
    );
  }
}
